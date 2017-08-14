#version 120
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

//Switch of effects (Please set the switch at composite1.fsh both.)
#define HBAO
//#define PCSS

#define RENDER_WATER

#define SCALE
//#define WHITE_BLOCK

//Properties of effects
const int shadowMapResolution    = 3072;
const int noiseTextureResolution = 720;
const bool generateShadowMipmap  = true;

const float shadowDistance       = 160.0;

//Please read the license before change things below this line !!

uniform int worldTime;
uniform int isEyeInWater;
uniform int moonPhase;

uniform float far;
uniform float near;
uniform float wetness;
uniform float aspectRatio;
uniform float rainStrength;
uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;

uniform vec3 sunPosition;
uniform vec3 cameraPosition;
uniform vec3 upPosition;
uniform ivec2 eyeBrightnessSmooth;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform sampler2D shadow;
uniform sampler2D gdepth;
uniform sampler2D composite;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D gaux4;
uniform sampler2D gcolor;
uniform sampler2D gnormal;
uniform sampler2D noisetex;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D gdepthtex;

varying float sunVisibility;
varying float ShadowDarkness;
varying float IlluminationBrightness;

varying float timeSunrise;
varying float timeNoon;
varying float timeSunset;
varying float timeMidnight;
varying float timeSkyDark;

varying vec3 lightVector;
varying vec3 lightPosition;
varying vec3 worldSunPosition;

varying vec3 sunlight;
varying vec3 ambientColor;
varying vec3 colorTorchlight;

varying vec3 cloudBase1;
varying vec3 cloudBase2;
varying vec3 cloudLight1;
varying vec3 cloudLight2;

varying vec4 texcoord;

#define SHADOW_MAP_BIAS 0.80

const float pi 			= 3.14159265358979328349;
float timeSunriseSunset = (1 - timeMidnight) * (1 - timeNoon);

vec3 nvec3(vec4 pos) {
    return pos.xyz/pos.w;
}

vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

float cdist(vec2 coord) {
	return max(abs(coord.s-0.5),abs(coord.t-0.5))*2.0;
}

float saturate(float x) {
	return clamp(x, 0.0, 1.0);
}

//Specularity
float GetMetallic(in vec2 coord) {
	return texture2D(gaux2, texcoord.st).g;
}

float GetEmmisive(in vec2 coord) {
	return texture2D(gaux2, texcoord.st).b;
}

float GetGlossiness(in vec2 coord) {
	return 1.0f - texture2D(gaux2, texcoord.st).r;
}

struct Composite {

	vec3 sunLight;
	vec3 skyLight;
	vec3 torchLight;
	vec3 noLight;
	
	vec3 scatteredSunlight;
	vec3 bouncedSunlight;
	vec3 scatteredUpLight;
	
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

struct PhysRender {

    vec3 amblight;
	vec3 torch;
	vec3 reflected;
	vec3 emmisive;
	
} pbr;

struct Material {

	vec3 color;
	vec3 normal;
	vec2 mclight;
	
	float materials;
	float pixeldepth;
	
	float metallic;
	float emmisive;
	float glossiness;
	
	PhysRender pbr;
	Position position;
	
} landmat;

float CalculateBouncedSunlight(in Material landmat) {

	float NdotL = landmat.position.NdotL;
	float bounced = clamp(-NdotL + 0.95f, 0.0f, 1.95f) / 1.95f;
		  bounced = bounced * bounced * bounced;

	return bounced;
}

float CalculateScatteredSunlight(in Material landmat) {

	float NdotL = landmat.position.NdotL;
	float scattered = clamp(NdotL * 0.75f + 0.25f, 0.0f, 1.0f);

	return scattered;
}

float CalculateScatteredUpLight(in Material landmat) {

	float scattered = dot(landmat.normal, landmat.position.up);
		  scattered = scattered * 0.5f + 0.5f;
		  scattered = 1.0f - scattered;

	return scattered;

}

float GetLightmapTorch(in vec2 mclight) {

	float lightmap  = clamp((mclight.s * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);

	lightmap 		= clamp(lightmap * 1.10f, 0.0f, 1.0f);
	lightmap 		= 1.0f - lightmap;
	lightmap 		*= 5.6f;
	lightmap 		= 1.0f / pow((lightmap + 0.8f), 2.0f);
	lightmap 		-= 0.02435f;
	lightmap 		= max(0.0f, lightmap);
	lightmap 		*= 0.008f;
	lightmap 		= clamp(lightmap, 0.0f, 1.0f);
	lightmap 		= pow(lightmap, 0.9f);
	
	return lightmap;

}

float GetLightmapSky(in vec2 mclight) {

	float light = clamp((mclight.t * 33.05f / 32.0f) - 1.05f / 32.0f, 0.0f, 1.0f);
	return pow(light, 4.3f);
	
}

float calcluma(in vec3 color) {
	return (color.r * 0.2126f + color.g * 0.7152f + color.b * 0.0722f);
}

vec3 Glowmap(in vec3 albedo, in float mask, in float curve, in vec3 emissiveColor) {
	vec3 color = albedo * (mask);
		 color = pow(color, vec3(curve));
		 color = vec3(calcluma(color));
		 color *= emissiveColor;

	return color;
}

vec4 GetScreenSpacePosition(in vec2 coord, in float depth) {
	vec4 fragposition = gbufferProjectionInverse * vec4(coord.s * 2.0f - 1.0f, coord.t * 2.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);
		 fragposition /= fragposition.w;

	return fragposition;
}

float CalculateDitherPattern() {

	const int[4] ditherPattern = int[4] (0, 2, 1, 4);

	vec2 count = vec2(0.0f);
	     count.x = floor(mod(texcoord.s * viewWidth, 2.0f));
		 count.y = floor(mod(texcoord.t * viewHeight, 2.0f));

	int dither = ditherPattern[int(count.x) + int(count.y) * 2];

	return float(dither) / 4.0f;
	
}

vec4 cubic(float x) {

    float x2 = x * x;
    float x3 = x2 * x;
    vec4 w;
    w.x =   -x3 + 3*x2 - 3*x + 1;
    w.y =  3*x3 - 6*x2       + 4;
    w.z = -3*x3 + 3*x2 + 3*x + 1;
    w.w =    x3;
    return w / 6.f;
}

vec4 BicubicTexture(in sampler2D tex, in vec2 coord) {

	vec2 resolution = vec2(viewWidth, viewHeight);

	coord *= resolution;

	float fx = fract(coord.x);
    float fy = fract(coord.y);
    coord.x -= fx;
    coord.y -= fy;

    fx -= 0.5;
    fy -= 0.5;

    vec4 xcubic = cubic(fx);
    vec4 ycubic = cubic(fy);

    vec4 c = vec4(coord.x - 0.5, coord.x + 1.5, coord.y - 0.5, coord.y + 1.5);
    vec4 s = vec4(xcubic.x + xcubic.y, xcubic.z + xcubic.w, ycubic.x + ycubic.y, ycubic.z + ycubic.w);
    vec4 offset = c + vec4(xcubic.y, xcubic.w, ycubic.y, ycubic.w) / s;

    vec4 sample0 = texture2D(tex, vec2(offset.x, offset.z) / resolution);
    vec4 sample1 = texture2D(tex, vec2(offset.y, offset.z) / resolution);
    vec4 sample2 = texture2D(tex, vec2(offset.x, offset.w) / resolution);
    vec4 sample3 = texture2D(tex, vec2(offset.y, offset.w) / resolution);

    float sx = s.x / (s.x + s.y);
    float sy = s.z / (s.z + s.w);

    return mix(mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);

}

void DoNightEye(inout vec3 color) {

	float amount = 0.8f;
	vec3 rodColor = vec3(0.2f, 0.5f, 1.25f);
	float colorDesat = dot(color, vec3(1.0f));

	color = mix(color, vec3(colorDesat) * rodColor, timeSkyDark * amount);

}

void DoLowlightEye(inout vec3 color) {

	float amount = 0.8f;
	vec3 rodColor = vec3(0.2f, 0.5f, 1.0f);
	float colorDesat = dot(color, vec3(1.0f));

	color = mix(color, vec3(colorDesat) * rodColor, amount);
	
}

void DoLowlightFuzziness(inout vec3 color) {

	float lum = calcluma(color.rgb);
	float factor = 1.0f - clamp(lum, 0.0f, 1.0f);

	float time = frameTimeCounter * 4.0f;
	vec2 coord = texture2D(noisetex, vec2(time, time / 64.0f)).xy;
	vec3 snow  = BicubicTexture(noisetex, (texcoord.st + coord) / (512.0f / vec2(viewWidth, viewHeight))).rgb;	//visual snow
	vec3 snow2 = BicubicTexture(noisetex, (texcoord.st + coord) / (128.0f / vec2(viewWidth, viewHeight))).rgb;	//visual snow

	vec3 rodColor = vec3(0.2f, 0.4f, 1.0f) * 2.5;
	vec3 rodLight = dot(color.rgb + snow.r * 0.005f, vec3(0.0f, 0.6f, 0.4f)) * rodColor;
	color.rgb = mix(color.rgb, rodLight, vec3(factor));

	color.rgb += calcluma(snow.rgb * snow.rgb * snow2.rgb * 0.02f);

}

#include "/lib/Noiselib.frag"
#include "/lib/Shadowlib.frag"

#define CLOUD_MIN  800.0
#define CLOUD_MAX 1530.0
	
float getCloudNoise(vec3 worldPos) {
	float noise  = getRAWNoise(worldPos * 0.001);
	return smoothstep(0.0, 1.0, pow(max(noise - 0.5 + rainStrength * 0.2 + 0.2f * frasenoise() - 0.2f * AmbientDynamic(), 0.0) * (1.0 / (1.0 - 0.5)), 0.5));
}

vec4 cloudLighting(vec4 sum, float density, float diff) {  
	vec4 color = vec4(mix(cloudBase1, cloudBase2, density ), density );
	vec3 lighting = mix(cloudLight1, cloudLight2, diff);
	color.xyz *= lighting;
	color.a *= 0.4;
	color.rgb *= color.a;
	return sum + color*(1.0-sum.a);
}

vec3 cloudRayMarching(vec3 startPoint, vec3 bgColor, vec3 worldPosition) {

	float maxDis = length(worldPosition.xyz) / far;
	if (maxDis > 0.9999) maxDis = 100.0;
	
	vec3 direction = normalize(worldPosition.xyz);
	
	if(direction.y <= 0.1)
		return bgColor;
	vec3 testPoint = startPoint;
	float cloudMin = startPoint.y + CLOUD_MIN * (exp(-startPoint.y / CLOUD_MIN) + 0.001);
	float d = (cloudMin - startPoint.y) / direction.y;
	testPoint += direction * (d + 0.01);
	if(distance(testPoint, startPoint) > maxDis * far)
		return bgColor;
	float cloudMax = cloudMin + (CLOUD_MAX - CLOUD_MIN);
	direction *= 1.0 / direction.y;
	vec4 final = vec4(0.0);
	float fadeout = (1.0 - clamp(length(testPoint) / (far * 100.0) * 6.0, 0.0, 1.0));
	for(int i = 0; i < 32; i++)
	{
		if(final.a > 0.99 || testPoint.y > cloudMax)
			continue;
		testPoint += direction;
		vec3 samplePoint = vec3(testPoint.x, testPoint.y - cloudMin + CLOUD_MIN, testPoint.z);
		float density = getCloudNoise(samplePoint) * fadeout;
		if(density > 0.0)
		{
			float diff = clamp((density - getCloudNoise(samplePoint + worldSunPosition * 10.0)) * 10.0, 0.0, 1.0 );
			final = cloudLighting(final, density, diff);
		}
	}
	final = clamp(final, 0.0, 1.0);
	return bgColor * (1.0 - final.a) + final.rgb * (1 - timeMidnight * 0.92);
	
}

//Water
float waterH(in vec3 posxz) {

	float wave = 0.0;
	float factor = 2.0;
	float amplitude = 0.02;
	float speed = 8.0;
	float size = 0.2;

	float px = posxz.x/50.0 + 250.0;
	float py = posxz.z/50.0  + 250.0;
	
	float fpx = abs(fract(px*20.0)-0.5)*2.0;
	float fpy = abs(fract(py*20.0)-0.5)*2.0;
	
	float d = length(vec2(fpx,fpy));
	for (int i = 1; i < 4; i++) {
		wave -= d*factor*cos((1/factor)*px*py*size + 1.0*frameTimeCounter*speed);
		factor /= 2;
	}

	factor = 1.0;
	px = -posxz.x/50.0 + 250.0;
	py = -posxz.z/150.0 - 250.0;
	
	fpx = abs(fract(px*20.0)-0.5)*2.0;
	fpy = abs(fract(py*20.0)-0.5)*2.0;

	d = length(vec2(fpx,fpy));
	float wave2 = 0.0;
	for (int i = 1; i < 4; i++) {
		wave2 -= d*factor*cos((1/factor)*px*py*size + 1.0*frameTimeCounter*speed);
		factor /= 2;
	}
	
	return amplitude*wave2+amplitude*wave;
	
}

vec3 WaterPosition(sampler2D sample, vec2 co, vec3 pos){

	vec3 underwaterpos = vec3(co.st, texture2D(sample, co.st).x);
		 underwaterpos = nvec3(gbufferProjectionInverse * nvec4(underwaterpos * 2.0 - 1.0));
	vec4 worldpositionuw = gbufferModelViewInverse * vec4(underwaterpos, 1.0);	
	vec3 wpos = worldpositionuw.xyz + pos.xyz;
	
	return wpos;

}

void WaterCaustics(inout vec3 finalComposite) {

	vec3 underWaterPosition = WaterPosition(depthtex1, texcoord.st, cameraPosition);
    float underWaterRay = waterH(underWaterPosition.xyz);
	finalComposite.rgb *= vec3(1.0f) + underWaterRay * sunlight * (timeMidnight * 0.1 + timeSunriseSunset * 0.2 + timeNoon * 0.32) * (1 - isEyeInWater) * (1.0f - timeMidnight);	

}

void WaterFog(inout vec3 color, in float iswater, in vec3 normal, in vec3 fogclr)
{

	float depth = texture2D(depthtex1, texcoord.st).x;
	float depthSolid = texture2D(gdepthtex, texcoord.st).x;

	vec4 viewSpacePosition = GetScreenSpacePosition(texcoord.st, depth);
	vec4 viewSpacePositionSolid = GetScreenSpacePosition(texcoord.st, depthSolid);

	vec3 viewVector = normalize(viewSpacePosition.xyz);

	float waterDepth = distance(viewSpacePosition.xyz, viewSpacePositionSolid.xyz);
	if (isEyeInWater > 0)
	{
		waterDepth = length(viewSpacePosition.xyz) * 0.5;		
		if (iswater > 0.9)
		{
			waterDepth = length(viewSpacePositionSolid.xyz) * 0.5;		
		}	
	}

	float fogDensity = 10.80;
	float visibility = 1.0f / (pow(exp(waterDepth * fogDensity), 1.0f));
	float visibility2 = 1.0f / (pow(exp(waterDepth * fogDensity), 1.0f));

	vec3 waterNormal = normalize(normal);

	vec3 waterFogColor = vec3(0.2, 0.85, 1.0) * 0.75; //clear water
		 waterFogColor *= 0.01 * dot(vec3(0.33333), sunlight);
		 waterFogColor *= (1.0 - rainStrength * 0.95);
		 waterFogColor *= isEyeInWater * 2.0 + 1.0;

	vec3 viewVectorRefracted = refract(viewVector, waterNormal, 1.0 / 1.3333);
	float scatter = 1.0 / (pow(saturate(dot(-lightVector, viewVectorRefracted) * 0.5 + 0.5) * 20.0, 2.0) + 0.1);
		
	if (isEyeInWater < 1)
	{
		waterFogColor = mix(fogclr, sunlight * 21.0 * fogclr, vec3(scatter * (1.0 - rainStrength)));
	}

	vec3 fogcolor = pow(vec3(0.4, 0.82, 1.0) * 0.99, vec3(pow(waterDepth / 2.0f, 3.0f) * 0.25 + 0.25));
	color = mix(color, waterFogColor * fogcolor, saturate(pow(visibility / 2.0f, 3.0f) * 1.2f));

}

vec3 convertHDR(vec3 color){

	float mult = 1.0;
	float max = 0.5;
	float min = 1.0;

	vec3 MaxExp = color * (2.0 * mult * max);
	vec3 MinExp = color / (1.5 * mult * min);

	vec3 getHDR = mix(MinExp,MaxExp,color.rgb);

	return getHDR;
}

//float getcloud_shadow (in Material landmat) {
//	return calcluma(cloudRayMarching(landmat.position.worldPosition.xyz + cameraPosition, vec3(0.0f), sunPosition - landmat.position.worldPosition.xyz));
//}

#define PBRFACTOR 4.0f
#define MATFACTOR 1000

#ifdef SCALE
 #define SCALEFACTOR 100
#else
 #define SCALEFACTOR 1
#endif
	  
void main() {
	
	//Initializing Materials
	landmat.color    = pow(texture2D(gcolor, texcoord.st).rgb * SCALEFACTOR, vec3(2.2f));
	landmat.normal   = texture2D(gaux1, texcoord.st).rgb * 2.0 - 1.0;
	landmat.mclight  = texture2D(gaux3,texcoord.st).st;
	
	landmat.metallic   = GetMetallic(texcoord.st);
	landmat.emmisive   = GetEmmisive(texcoord.st);
	landmat.glossiness = GetGlossiness(texcoord.st);

	landmat.pbr.amblight  = pow(texture2D(gdepth,    texcoord.st).rgb * PBRFACTOR, vec3(2.2f));
	landmat.pbr.torch     = pow(texture2D(gaux4,     texcoord.st).rgb * PBRFACTOR, vec3(2.2f));
	landmat.pbr.reflected = pow(texture2D(composite, texcoord.st).rgb * PBRFACTOR, vec3(2.2f));
	landmat.pbr.emmisive  = landmat.emmisive * landmat.color;
	
	landmat.materials  = texture2D(gnormal,texcoord.st).x * MATFACTOR;
	landmat.pixeldepth = texture2D(depthtex0, texcoord.st).x;
	
	float ishand   = texture2D(gaux3,texcoord.st).b;
	float iswater  = texture2D(gnormal,texcoord.st).g;
	float isentity = texture2D(gnormal,texcoord.st).b;
	float island   = float(pow(landmat.pixeldepth, 2.0) < pow(landmat.pixeldepth, 1.0));
	float islava   = float(landmat.materials > 9.9  && landmat.materials < 11.1);
	float isglow   = float(landmat.materials > 88.9 && landmat.materials < 89.1);
	float isfire   = float(landmat.materials > 50.9 && landmat.materials < 51.1);
	
	float sky      = GetLightmapSky(landmat.mclight);
	float torch    = GetLightmapTorch(landmat.mclight);
	
	//Calculate Position
	landmat.position.viewPosition  = GetScreenSpacePosition(texcoord.st, landmat.pixeldepth);
	landmat.position.worldPosition = gbufferModelViewInverse * landmat.position.viewPosition;
	
	landmat.position.sun   = normalize(sunPosition);
	landmat.position.moon  = normalize(-sunPosition);
	landmat.position.up	   = normalize(upPosition);
	
	landmat.position.NdotL = max(dot(landmat.normal, lightVector), 0.0) * 0.9 + 0.1;
	
	float distance = sqrt(  landmat.position.viewPosition.x * landmat.position.viewPosition.x
						  + landmat.position.viewPosition.y * landmat.position.viewPosition.y
						  + landmat.position.viewPosition.z * landmat.position.viewPosition.z);
	
	//Calculate Shadow
	float fademult        = 0.15f;
	float shadowMult      = clamp((shadowDistance * 0.85f * fademult) - (distance * fademult), 0.0f, 1.0f);
	
	composited.shade 	  = max(0.0f, landmat.position.NdotL * 0.99f + 0.01f);
	composited.shade 	 *= mix(1.0f, 0.0f, rainStrength);
	composited.shade	 *= pow(sky, 0.1f);
	composited.shade      = composited.shade * 0.5f + 0.5f;
	composited.shade     *= calcShadowing(landmat.position.worldPosition, landmat.normal);
	composited.shade      = mix(1.0f, composited.shade, shadowMult);
	
	//Calculate AO
	#ifdef HBAO
	 composited.ao         = calc_ao(texcoord.st,landmat.normal);
	#else
	 composited.ao         = 1.0f;
	#endif
	
	//Compositing Color	
	composited.sunLight   = vec3(ShadowDarkness / 4.0f + composited.shade * 0.12f * (1.2 - timeMidnight) * IlluminationBrightness);
	composited.sunLight   = mix(composited.sunLight, composited.sunLight * sunlight * 1.5f, composited.shade * timeSunriseSunset * island);
	composited.sunLight  *= 1.0f - timeSunriseSunset * 0.3f;
	composited.sunLight  *= (1 - timeMidnight * 0.12f) * (1 + timeNoon * 0.12f);
	composited.sunLight  *= 1 + (1 - composited.shade) / (2 - composited.shade) * 0.50f;
	
	composited.skyLight   = vec3(dot(landmat.normal, landmat.position.up) * 0.4f + 0.6f) * sky;
	composited.skyLight  *= mix(ambientColor, landmat.pbr.amblight, vec3(max(0.2f, 1.13f - sky))) + landmat.pbr.amblight * 0.3f * (1.0f - rainStrength);
	composited.skyLight  += mix(ambientColor, sunlight, vec3(0.2f)) * sky * 0.05f;
	composited.skyLight  *= mix(1.0f, 0.4f, rainStrength);
	composited.skyLight  *= 1.0f - timeSunriseSunset * 0.15f;
	
	composited.torchLight = torch * colorTorchlight;
	composited.noLight    = vec3(0.05f);
	
	//composited.scatteredSunlight  = vec3(CalculateScatteredSunlight(landmat));
	//composited.scatteredUpLight   = vec3(CalculateScatteredUpLight (landmat));
	//composited.bouncedSunlight    = vec3(CalculateBouncedSunlight  (landmat));
	
    //composited.scatteredSunlight *= landmat.pbr.amblight * (1.0f - rainStrength) * sky;
	//composited.scatteredUpLight  *= pow(sky, 0.5f) * sunlight;
	//composited.scatteredUpLight  *= mix(1.0f, 0.1f, rainStrength);
	//composited.bouncedSunlight   *= pow(vec3(sky), vec3(1.75f)) * ambientColor;
	//composited.bouncedSunlight   *= mix(1.0f, 0.25f, (1.0f - timeMidnight) * (1.0f - timeNoon));
	//composited.bouncedSunlight   *= mix(1.0f, 0.0f, rainStrength);
	
	landmat.color = mix(landmat.color, pow(landmat.color, vec3(2.0f)), vec3((isfire)));
	
	composited.sunLight 		 *= pow(landmat.color ,vec3(1 / 2.2f));
	composited.skyLight 		 *=     landmat.color;
	composited.torchLight 		 *=     landmat.color;
	composited.noLight 			 *=     landmat.color;
	//composited.scatteredSunlight *= 	landmat.color;
	//composited.scatteredUpLight  *= 	landmat.color;
	//composited.bouncedSunlight   *= 	landmat.color;
	
	//Calculate Glow
	vec3 lava 		= Glowmap(landmat.color, islava, 3.0f, vec3(1.0f, 0.28f, 0.10f));
	vec3 glowstone 	= Glowmap(landmat.color, isglow, 1.9f, landmat.color * colorTorchlight);
	vec3 fire 		= landmat.color * float(isfire);
	
	//Do Night Eyes effect on outdoor lighting and sky
	//DoNightEye			(composited.bouncedSunlight);
	//DoNightEye			(composited.scatteredSunlight);
	//DoNightEye			(composited.scatteredUpLight);
	DoLowlightEye		(composited.noLight);
	//DoLowlightFuzziness	(composited.noLight);
	
	float sunlightMult = 1.0f;// - getcloud_shadow(landmat) * 0.5f;
	
	//Gather ALL color together to composited.final
	composited.final = pow(composited.sunLight, vec3(2.2f))     * sunlightMult * (1.70f - island * 0.70f)
					 + composited.skyLight  		* sunlightMult * (0.2f + timeMidnight * 0.6f)
					 + composited.noLight   		* 0.15f     * sunlightMult
					 //+ composited.bouncedSunlight 	* 0.03f     * sunlightMult
					 //+ composited.scatteredSunlight	* 0.03f     * sunlightMult
					 //+ composited.scatteredUpLight 	* 0.03f 	* sunlightMult
					 + composited.torchLight 		* 256.0f    * (eyeBrightnessSmooth.y / 240.0f * 0.8f + 0.2f)
					 + glowstone					* 3.92f
					 + lava							* 1.92f
					 + fire							* 0.37f
					 + landmat.pbr.emmisive         * 4.00f
					 + landmat.pbr.amblight         * 0.35f     * island * (1.0f - isentity)
					 + landmat.pbr.torch            * 0.02f     * (eyeBrightnessSmooth.y / 240.0f * 0.8f + 0.2f)
					 + landmat.pbr.reflected        * 64.00f    * island * composited.shade * (1.0f - 0.8f * timeMidnight)
					 ;
	
	#define EXPOSURE 1.2f
	
	#ifdef RENDER_WATER
	
	 composited.final *= 1.0 - abs(isEyeInWater - timeMidnight) * 0.26f;  //scale down when under the water
	
	 if (iswater > 0.9) {
		composited.final  = composited.final * EXPOSURE / (composited.final + vec3(1.0f));
		//WaterCaustics(composited.final);
	 }
	 
	#endif
	
	//Do Color Process
	float land = float(island > 0.9);
	vec3 finalclr  = pow(composited.final, vec3(1.0f / 2.2f));
		 //finalclr  = cloudRayMarching(cameraPosition, finalclr / 1.5f, landmat.position.worldPosition.xyz) * EXPOSURE * 1.5f;
		 finalclr *= (1.0f - timeSunriseSunset * 0.2f) * (1.0f + timeMidnight * 0.2f);
		 finalclr *= 1.0f - isentity * (1.0f - composited.shade * 0.5f) * 0.4f * (eyeBrightnessSmooth.y / 240.0f * 0.8f + 0.2f) + 0.12f;
		 finalclr *= 1.0f - (1 - land) * (0.2f - 0.6f * timeMidnight);
		 finalclr  = pow(finalclr, vec3(1.0f + (1 - land) * 0.2f * timeSunriseSunset));
		 
	vec3 colordark = convertHDR (finalclr * 1.24f);
		 finalclr  = mix(finalclr, colordark, min(0.12f / dot(finalclr, vec3(0.24f)), 1.0f));
	
	//if (calcluma(finalclr) > 8.0f) finalclr = normalize(sunlight);
	
	#ifdef WHITE_BLOCK
	 finalclr = vec3(calcluma(finalclr));
	#endif
	#ifdef SCALE
	 finalclr *= 0.01;
	#endif
	
/* DRAWBUFFERS:0 */

	//0:gcolor  = albedo
	//2:gnormal = materials,iswater,isentity
	//4:gaux1   = normals
	//5:gaux2   = specular
	//6:gaux3   = lmcoord,ishand
	
	gl_FragData[0] = vec4(finalclr, composited.ao);
	
}