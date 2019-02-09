#version 120
#extension GL_EXT_gpu_shader4 : enable
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

//Switch of effects
#define HBAO
//#define PCSS
//#define SMAA

#define GODRAYS

#define FOG
#define UNDERWATER_FOG

#define FIX_CUSTOMSTEVE

//Properties of effects
const int noiseTextureResolution = 720;

const int shadowMapResolution    = 2048;  //[1024 2048 4096]
const float shadowDistance       = 160.0; //[80.0 120.0 180.0 240.0]

//Please read the license before change things below this line !!

const bool gcolorMipmapEnabled = true;

uniform int worldTime;
uniform int moonPhase;
uniform int isEyeInWater;

uniform float far;
uniform float near;
uniform float wetness;
uniform float aspectRatio;
uniform float rainStrength;
uniform float frameCounter;
uniform float frameTime;
uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;

uniform vec3 upPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 cameraPosition;
uniform vec3 shadowLightPosition;
uniform ivec2 eyeBrightnessSmooth;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform sampler2D shadow;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;
uniform sampler2D noisetex;

uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D gaux4;

uniform sampler2D gdepthtex;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;

varying vec3 sunVec;
varying vec3 moonVec;
varying vec3 upVec;
varying vec3 lightVector;

varying vec3 sunColor;
varying vec3 moonColor;
varying vec3 ambientColor;
varying vec3 torchColor;
varying vec3 glowColor;

varying float timeSunrise;
varying float timeNoon;
varying float timeSunset;
varying float timeMidnight;
varying float timeSunriseSunset;

varying float timeSkyDark;
varying float timeFading;

varying float SkyBrightness;
varying float SunBrightness;

varying float fogdistance;

varying vec4 texcoord;
varying vec2 pixcoord;

varying vec4 offset[3];

#define SHADOW_MAP_BIAS 0.85

#ifdef SMAA
#define SMAA_Calc
#endif

const float pi = 3.14159265358979328349;

float cdist(vec2 coord) {
	return max(abs(coord.s - 0.5), abs(coord.t - 0.5)) * 2.0;
}

vec4 indices[4] = vec4[4](vec4(5.0f, 3.0f, 1.0f, 3.0f), // S0
						  vec4(4.0f, 6.0f, 2.0f, 3.0f), // S1
						  vec4(3.0f, 5.0f, 1.0f, 4.0f), // S2
						  vec4(6.0f, 4.0f, 2.0f, 4.0f));// S3
					 
//Specularity
float GetMetallic(in vec2 coord) {
	return texture2D(gaux1, texcoord.st).g;
}

float GetEmmisive(in vec2 coord) {
	return texture2D(gaux1, texcoord.st).b;
}

float GetRoughness(in vec2 coord) {
	return texture2D(gaux1, texcoord.st).r;
}

float Luminance(vec3 color) {
	return dot(color.rgb, vec3(0.2125f, 0.7154f, 0.0721f));
}

float GetDepth(in vec2 coord) {
	return texture2D(gdepthtex, coord.st).x;
}

vec4 GetViewSpacePosition(in vec2 coord) {
	float depth = GetDepth(coord);
	vec4 fragposition = gbufferProjectionInverse * vec4(coord.s * 2.0 - 1.0, coord.t * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
		 fragposition /= fragposition.w;

	return fragposition;
}

vec4 GetScreenSpacePosition(in vec2 coord, in float depth) {
	vec4 fragposition = gbufferProjectionInverse * vec4(coord.s * 2.0f - 1.0f, coord.t * 2.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);
		 fragposition /= fragposition.w;

	return fragposition;
}

struct Composite {

	vec3 sunLight;
	vec3 skyLight;
	vec3 torchLight;
	vec3 noLight;
	
	float ao;
	float shade;
	
	vec3 final;
	
} composited;

struct Position {

	vec4 viewPosition;
	vec4 worldPosition;
	
	vec3 sun;
	vec3 moon;
	vec3 up;
	
	float NdotL;
	
} position;

struct Material {

	vec3 color;
	vec3 normal;
	vec3 pixeldepth;
	vec2 mclight;
	
	float materials;
	
	float metallic;
	float emmisive;
	float roughness;
	
	Position position;
	
} landmat;

vec2 GetLightmap(in vec2 mclight) {

	const float A = 1.0f + 1.0f / 16.0f;
	const float B = 1.0f / A;
	
	const float blockLightIntensity = 0.2;
	
	float dist = (A - mclight.s) * B;
	float inverseSquare = 1.0f / (dist * dist);
	
	float torch = inverseSquare * blockLightIntensity - blockLightIntensity;
	float sky   = pow(clamp((mclight.t * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f), 4.3f);
	
	return vec2(torch, sky);
	
}

float getSky_Simulated_GI(in float direction, in vec3 lightVec, in vec3 normal) {

	float simulatedGI = 0.4 * (-1.333 / (3.0 * pow(direction, 4.0) + 1.0) + 1.333);
	
	vec3 sunRef = reflect(lightVec, upVec);
	simulatedGI *= 1.5 + 0.5 * max(0.0, dot(sunRef, normal));

	return simulatedGI;
	
}

vec3 Glowmap(in vec3 albedo, in float mask, in float curve, in vec3 emissiveColor) {

	vec3 color = albedo * (mask);
		 color = pow(color, vec3(curve));
		 color = vec3(Luminance(color));
		 color *= emissiveColor;

	return color * 4.0f;
	
}

float CalculateDitherPattern() {

	const int[4] ditherPattern = int[4] (0, 2, 1, 4);

	vec2 count = vec2(0.0f);
	     count.x = floor(mod(texcoord.s * viewWidth, 2.0f));
		 count.y = floor(mod(texcoord.t * viewHeight, 2.0f));

	int dither = ditherPattern[int(count.x) + int(count.y) * 2];

	return float(dither) / 4.0f;
	
}

void DoNightEye(inout vec3 color) {

	float amount = 0.8f;
	vec3 rodColor = vec3(0.2f, 0.5f, 1.25f);
	float colorDesat = dot(color, vec3(1.0f));

	color = mix(color, vec3(colorDesat) * rodColor, timeSkyDark * amount);

}

void DoLowlightEye(inout vec3 color) {

	float amount = 0.38f;
	vec3 rodColor = vec3(0.2f, 0.5f, 1.0f);
	float colorDesat = dot(color, vec3(1.0f));

	color = mix(color, vec3(colorDesat) * rodColor, amount);
	
}

#include "/lib/Noiselib.frag"
#include "/lib/Shadowlib.frag"
#include "/lib/Waterlib.frag"

float weather = ambient_noise();

float GetDepthLinear(in vec2 coord) {
	return 2.0f * near * far / (far + near - (2.0f * texture2D(gdepthtex, coord).x - 1.0f) * (far - near));
}

void doUnderwaterFog(in vec3 fogclr, inout vec3 finalComposite, in float iswater) {

	vec3 fogColor = sqrt(fogclr * ambientColor) * 8.0f;

	float fogFactor = GetDepthLinear(texcoord.st) / 200.0f;
		  fogFactor = min(fogFactor, 0.7f);
		  fogFactor = sin(fogFactor * 3.1415 * 0.5f);
		  fogFactor = pow(fogFactor, 0.5f) * (0.6f + pow(eyeBrightnessSmooth.y / 240.0f, 0.5f) * 0.2f);

	finalComposite.rgb  = mix(finalComposite.rgb, fogColor * 0.35f, fogFactor);
	finalComposite.rgb *= mix(vec3(1.0f), pow(fogclr * (1.0f - eyeBrightnessSmooth.y / 240.0f) * 2.5f, vec3(4.0f)),  fogFactor);

}

vec3 getWaterPosition(sampler2D sample, vec2 coord, vec3 pos){
	vec3 underwaterpos = vec3(coord.st, texture2D(sample, coord.st).x);
	vec4 tpos = gbufferProjectionInverse * vec4(underwaterpos * 2.0 - 1.0, 1.0f);
		 underwaterpos = tpos.xyz / tpos.w;
	vec4 worldpositionuw = gbufferModelViewInverse * vec4(underwaterpos, 1.0);
	vec3 wpos = worldpositionuw.xyz + pos.xyz;
	vec4 sun = gbufferModelViewInverse * vec4(vec3(sunPosition), 1.0f);
		 wpos.xz -= sun.xz * wpos.y / sun.y;
	return wpos;
}

void doWaterCaustics(inout vec3 finalComposite, in float torch) {
	vec3 underWaterPosition = getWaterPosition(depthtex1, texcoord.st, cameraPosition);
    float underWaterRay = sqrt(clamp(pow(doWave(underWaterPosition.xyz, 1.0f), 12.0f) * 35.0f, 0.0, 1.0)) * 10.0f;
	finalComposite.rgb *= vec3(1.0f) + underWaterRay * sunColor * (timeSunriseSunset + timeNoon * 1.6) * 1.2f
									 + underWaterRay * torchColor * torch * (1.0f + timeMidnight * 20.0f) * 0.25f;	
}

float getSkyMask(vec2 coord) {
	float pixeldepth = texture2D(depthtex0, coord).x;
	return float(pow(pixeldepth, 2.0) < pow(pixeldepth, 1.0));
}

float getGodRays(vec2 lightPos) {

	const int gr_samples   = 12;
	const float gr_density = 0.6;
	const float gr_noise   = 0.4;
	
	float gr = 0.0;
	
	vec2 deltaTextCoord = vec2(texcoord.st - lightPos.xy);
	vec2 textCoord = texcoord.st;
	     deltaTextCoord *= 1.0 / float(gr_samples) * gr_density;
	vec2 noise = vec2(hash_gr(textCoord), hash_gr(-textCoord.yx + 0.05));
			
	for(int i=0; i < gr_samples ; i++) {			
		textCoord -= deltaTextCoord;
		float sample = step(getSkyMask(textCoord + deltaTextCoord * noise * gr_noise), 0.001);
		gr += sample;
	}
	
	vec2 delta = (texcoord.st - lightPos) * gr_density / 2.0;
		 delta *= -sunPosition.z * 0.01f;
		 			
	float bubble = length(vec2(delta.x * aspectRatio, delta.y)) * 6.0f;
		  bubble = clamp(bubble, 0.0f, 1.0f);
		  bubble = 1.0f - bubble;
	
	return gr / gr_samples * pow(bubble, 2.0f);
       
}

#include "/lib/Lightlib.frag"
#include "/lib/AAlib.glsl"
#include "/lib/Filter.frag"

vec4 GetBlurAO(in sampler2D tex, in vec2 coord) {
	vec2 res = vec2(viewWidth, viewHeight);
	coord = coord * res + 0.5f;
	vec2 i = floor(coord);
	vec2 f = fract(coord);
	f = f * f * (3.0f - 2.0f * f);
	coord = i + f;
	coord = (coord - 0.5f) / res;
	return texture_Bicubic(tex, coord);
}

void main() {
	
	//Initializing Materials
	landmat.color   = texture2D(gcolor, texcoord.st).rgb;
	landmat.normal  = texture2D(gnormal ,texcoord.st).rgb * 2.0 - 1.0;
	landmat.mclight = texture2D(gaux2, texcoord.st).xy;
	
	landmat.metallic  = GetMetallic(texcoord.st);
	landmat.emmisive  = GetEmmisive(texcoord.st);
	landmat.roughness = GetRoughness(texcoord.st);
	
	landmat.materials = texture2D(gdepth, texcoord.st).r;
	
	landmat.pixeldepth.x = texture2D(depthtex0, texcoord.st).x;
	landmat.pixeldepth.y = texture2D(depthtex1, texcoord.st).x;
	landmat.pixeldepth.z = texture2D(depthtex2, texcoord.st).x;
	
	float stage    = texture2D(gaux2, texcoord.st).b;
	
	#ifdef FIX_CUSTOMSTEVE
		if (stage > 0.9f) landmat.materials = 0.0f; 
	#endif
	
	float iswater  = float(stage > 0.15f && stage < 0.25f);
	float isice    = float(stage > 0.35f && stage < 0.45f);

	float island   = float(pow(landmat.pixeldepth.y, 2.0) < pow(landmat.pixeldepth.y, 1.0));

	float islava   = float(landmat.materials > 9.9  && landmat.materials < 11.1);
	float isglow   = float(landmat.materials > 88.9 && landmat.materials < 89.1);
	float isfire   = float(landmat.materials > 50.9 && landmat.materials < 51.1);
	float isglass  = float(landmat.materials > 94.9 && landmat.materials < 95.1);
	
	vec2 lightmap  = GetLightmap(landmat.mclight);
	
	//Calculate Position
	landmat.position.viewPosition  = GetScreenSpacePosition(texcoord.st, landmat.pixeldepth.x);
	landmat.position.worldPosition = gbufferModelViewInverse * landmat.position.viewPosition;
	
	landmat.position.sun   = sunVec;
	landmat.position.moon  = moonVec;
	landmat.position.up	   = upVec;
	
	landmat.position.NdotL = max(dot(landmat.normal, lightVector), 0.0) * 0.9 + 0.1;
	
	float distance = length(landmat.position.viewPosition.xyz);
	
	//Calculate Shadow
	float fademult        = 0.15f;
	float shadowMult      = clamp((shadowDistance * 0.85f * fademult) - (distance * fademult), 0.0f, 1.0f);

	composited.shade 	  = max(0.0f, landmat.position.NdotL * 0.99f + 0.01f);
	composited.shade 	 *= mix(1.0f, 0.0f, rainStrength);
	composited.shade	 *= pow(lightmap.t, 0.1f) * getShadowing(landmat.position.worldPosition, normalize(landmat.normal));
	composited.shade      = mix(0.50f, composited.shade, shadowMult);
	
	//Add AO
	#ifdef HBAO
		composited.ao     = GetBlurAO(gaux2, texcoord.st).a;
	#else
		composited.ao     = 1.0f;
	#endif
	
	//Compositing Color	
	composited.sunLight   = mix(max(1.0f - weather, 0.0f) * sunColor * SunBrightness, moonColor, timeMidnight) * composited.shade;
	composited.sunLight  *= getPBRLighting(landmat.position.viewPosition.xyz, landmat.normal, landmat.metallic, landmat.roughness, landmat.color);
	
	composited.skyLight   = vec3(dot(landmat.normal, landmat.position.up) * 0.5f + 0.5f) * (lightmap.t * 0.5f + 0.5f);
	composited.skyLight  += mix(ambientColor, sunColor, 0.2f) * lightmap.t * 0.15f;
	composited.skyLight  *= mix(1.0f, 0.4f, rainStrength);
	composited.skyLight  += getSky_Simulated_GI(lightmap.t, normalize(shadowLightPosition), landmat.normal) * 0.5f;
	composited.skyLight  *= SkyBrightness * pow(ambientColor, vec3(1.0f / 2.2f)) * composited.ao * (1.0f + weather);
	composited.skyLight   = composited.skyLight * landmat.color;
	
	composited.torchLight = lightmap.s * torchColor * landmat.color;
	
	composited.noLight    = vec3(0.05f) * landmat.color;
	
	//Calculate Glow
	vec3 lava 		= Glowmap(landmat.color, islava, 12.0f,  vec3(1.8f, 0.30f, 0.001f));
	vec3 glowstone 	= Glowmap(landmat.color, isglow, 0.75f, landmat.color * torchColor);
	vec3 fire 		= pow(landmat.color, vec3(2.0f)) * float(isfire);
	
	//Do Night Eyes effect on outdoor lighting and sky
	DoLowlightEye (composited.noLight);
	
	if (bool(iswater) && bool(island) && !bool(isEyeInWater)) doWaterCaustics(composited.sunLight, lightmap.s);
	
	//Gather ALL color together to composited.final
	composited.final  = composited.sunLight      * 2.80f  * (max(eyeBrightnessSmooth.y / 240.0f, iswater) * 0.70f + 0.30f)
					  + composited.skyLight      * 0.85f  * (eyeBrightnessSmooth.y / 240.0f * 0.80f + 0.20f)
					  + composited.noLight       * 0.10f
					  + (composited.torchLight   * 0.05f
					  +  glowstone      		 * 0.30f
					  +  lava					 * 0.35f
					  +  fire					 * 0.20f) * (eyeBrightnessSmooth.y / 240.0f * 0.60f + 0.40f)
					  ;
	
	//Do Water Absorb
	const vec3 primaryWavelengths = vec3(700, 546.1, 435.8);
	vec3 watercolor = vec3(normalize(vec3(1.0f) / normalize(pow(primaryWavelengths, vec3(2.2f)))) / 4.0f) * Luminance(sunColor);
	
	vec4 upos = GetScreenSpacePosition(texcoord.st, texture2D(depthtex1, texcoord.st).x);
	vec3 uvec = landmat.position.viewPosition.xyz - upos.xyz;
		 uvec = mix(uvec, upos.xyz, isEyeInWater);
		 
	float UdotN = abs(dot(uvec, landmat.normal));
	float depth = length(uvec) * UdotN;
		  
	if (bool(iswater)) {
		if (!bool(isEyeInWater)) composited.final = mix(sqrt(watercolor * ambientColor) * 0.6f, composited.final * 0.2f, max(exp(-depth / 50), 0.0));
	}

	#ifdef FOG
		float dist = length(upos.xyz);
		float fogDensity = 0.08;
			  fogDensity *= mix(0.0f, 1.0f, pow(eyeBrightnessSmooth.y / 240.0f, 6.0f));
		float fogFactor = clamp(1.0f - exp(-pow(dist * fogDensity / fogdistance * 20.0, 6.0)), 0.0, 1.0);
		composited.final += max(vec3(0.0), vec3(1.0) - exp(-fogFactor * sqrt(ambientColor))) * dot(sunColor, vec3(0.2125f, 0.7154f, 0.0721f)) * mix(sunColor, vec3(0.8f), mix(weather, 1.0f, 0.75f));
		#ifdef UNDERWATER_FOG
			if (bool(isEyeInWater)) doUnderwaterFog(pow(watercolor, vec3(2.2f)), composited.final, iswater);
		#endif
	#endif
	
	//Do Color Process
	vec3 finalclr = mix(landmat.color * 1.5f, composited.final * (1.0f - isice * 0.5f), island);
	
	float gr = 0.0f;
	#ifdef GODRAYS
		vec4 tpos = vec4(sunPosition, 1.0) * gbufferProjection;
			 tpos = vec4(tpos.xyz / tpos.w, 1.0);
		vec2 lightPos = tpos.xy / tpos.z;
			 lightPos = (lightPos + 1.0f) / 2.0f;
		gr = getGodRays(lightPos);
	#endif
	
	vec4 aa = vec4(0.0f);
	#ifdef SMAA
		float frame = mod(frameCounter, 4);
		vec4 temporal = indices[int(frame)];
		aa = getAABlendingTex(texcoord.st, pixcoord.st, temporal);
	#endif
	
/* DRAWBUFFERS:035 */

	gl_FragData[0] = vec4(finalclr, gr);
	gl_FragData[1] = aa;
	gl_FragData[2] = vec4(texture2D(gaux2, texcoord.st).rgb, composited.shade);
	
}