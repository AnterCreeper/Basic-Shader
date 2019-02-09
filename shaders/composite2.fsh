#version 120
#extension GL_EXT_gpu_shader4 : enable
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

//Switch of effects
#define GODRAYS
//#define NO_CLOUDS

#define WAVE_HEIGHT 0.25f //[0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.5]

//Please read the license before change things below this line !!

const bool gcolorMipmapEnabled = true;

const int noiseTextureResolution = 720;

uniform int moonPhase;
uniform int worldTime;
uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;

uniform float far;
uniform float near;
uniform float wetness;
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;
uniform float rainStrength;
uniform float frameTime;
uniform float frameTimeCounter;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform vec3 cameraPosition;

uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D gaux1;
uniform sampler2D gaux2;

uniform sampler2D noisetex;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

varying vec4 texcoord;

varying vec3 sunColor;
varying vec3 moonColor;
varying vec3 ambientColor;
varying vec3 torchColor;
varying vec3 glowColor;
varying vec3 rayColor;

varying vec3 upVec;
varying vec3 sunVec;
varying vec3 moonVec;
varying vec3 lightVector;

varying float sunVisibility;
varying float moonVisibility;

varying float handItemLight;

varying float timeSunrise;
varying float timeNoon;
varying float timeSunset;
varying float timeMidnight;
varying float timeSunriseSunset;

varying float timeSkyDark;
varying float timeFading;

float cdist(vec2 coord) {
	return max(abs(coord.s - 0.5), abs(coord.t - 0.5)) * 2.0;
}

vec3 nvec3(vec4 pos){
    return pos.xyz / pos.w;
}

#include "/lib/Noiselib.frag"
#include "/lib/Envlib.frag"
#include "/lib/Waterlib.frag"

float getLinearDepth(float depth) {
	return (2.0 * near) / (far + near - depth * (far - near));
}

float getLinearDepthOfViewCoord(vec3 viewCoord) {
	vec4 pos = gbufferProjection * vec4(viewCoord, 1.0);
		 pos /= pos.w;
	return getLinearDepth(pos.z * 0.5 + 0.5);
}

vec4 getWaterRayTrace(vec3 fragpos, vec3 normal) {

    vec4 color = vec4(0.0);
    vec3 start = fragpos;
    vec3 direction = normalize(reflect(normalize(fragpos), normalize(normal)));
    vec3 vector = 1.2 * direction;
	vec3 total = vector;
	
	const int maxRefinements = 6;
		  int refinements = 0;
	
	fragpos += vector;
	
    for(int i = 0; i < 24; i++){
	
        vec3 samplePos = nvec3(gbufferProjection * vec4(fragpos, 1.0f)) * 0.5 + 0.5;
        if(samplePos.x < 0 || samplePos.x > 1 || samplePos.y < 0 || samplePos.y > 1 || samplePos.z < 0 || samplePos.z > 1.0) break;
        vec3 realPos = vec3(samplePos.st, texture2D(depthtex1, samplePos.st).r);
			 realPos = nvec3(gbufferProjectionInverse * vec4(realPos * 2.0 - 1.0, 1.0));
        float error = abs(fragpos.z - realPos.z);
		
			if(error < pow(length(vector) * 1.85, 1.15)){
			
                refinements++;
				
                if(refinements >= maxRefinements){
				
					float pixeldepth  = texture2D(gdepthtex, samplePos.st).x;
					float island  = float(pow(pixeldepth, 2.0) < pow(pixeldepth, 1.0));
					
					vec3 hitNormal = texture2D(gnormal, samplePos.st).rgb * 2.0 - 1.0;
					
					if (dot(direction, hitNormal) < 0) {
						color.rgb = texture2D(gcolor, samplePos.st).rgb;
						color.a   = clamp(1.0 - pow(cdist(samplePos.st), 2.0), 0.0, 1.0) * island;
						break;
					}
					
                }
				
				total -= vector;
                vector *= 0.1;
				
			}
			
        vector *= 2.2;
        total += vector;
		fragpos = start + total;
		
    }
	
    return color;
	
}

vec2 getScreenCoordByViewCoord(vec3 viewCoord) {
	vec4 p = vec4(viewCoord, 1.0);
	p = gbufferProjection * p;
	p /= p.w;
	if(p.z < -1 || p.z > 1)
		return vec2(-1.0);
	p = p * 0.5f + 0.5f;
	return p.st;
}

float linearizeDepth(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

#define BISEARCH(SEARCHPOINT, DIRVEC, SIGN) DIRVEC *= 0.5; \
					SEARCHPOINT+= DIRVEC * SIGN; \
					uv = getScreenCoordByViewCoord(SEARCHPOINT); \
					sampleDepth = linearizeDepth(texture2DLod(depthtex0, uv, 0.0).x); \
					testDepth = getLinearDepthOfViewCoord(SEARCHPOINT); \
					SIGN = sign(sampleDepth - testDepth);

vec4 RT(vec3 startPoint, vec3 direction, float jitter, float roughness) {

	const float stepBase = 0.025;
	vec3 testPoint = startPoint;
	vec3 lastPoint = testPoint;
	direction *= stepBase;
	bool hit = false;
	vec4 hitColor = vec4(0.0);
	for(int i = 0; i < 40; i++)
	{
		testPoint += direction * pow(float(i + 1 + jitter), 1.46);
		vec2 uv = getScreenCoordByViewCoord(testPoint);
		if(uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
		{
			hit = true;
			break;
		}
		float sampleDepth = texture2DLod(depthtex0, uv, 0.0).x;
		sampleDepth = linearizeDepth(sampleDepth);
		float testDepth = getLinearDepthOfViewCoord(testPoint);
		if(sampleDepth < testDepth && testDepth - sampleDepth < (1.0 / 2048.0) * (1.0 + testDepth * 200.0 + float(i)))
		{
			vec3 finalPoint = lastPoint;
			float _sign = 1.0;
			direction = testPoint - lastPoint;
			BISEARCH(finalPoint, direction, _sign);
			BISEARCH(finalPoint, direction, _sign);
			BISEARCH(finalPoint, direction, _sign);
			BISEARCH(finalPoint, direction, _sign);
			uv = getScreenCoordByViewCoord(finalPoint);
			vec3 hitNormal = texture2D(gnormal, uv).rgb * 2.0 - 1.0;
			
			if (dot(direction, hitNormal) < 0) {
			
				hitColor.rgb = texture2DLod(gcolor, uv, int(roughness * 3.0)).rgb;
				hitColor.a = clamp(1.0 - pow(distance(uv, vec2(0.5)) * 2.0, 2.0), 0.0, 1.0);
			
				hit = true;
				break;

			}
		}
		lastPoint = testPoint;
	}
	if(!hit)
	{
		vec2 uv = getScreenCoordByViewCoord(lastPoint);
		float testDepth = getLinearDepthOfViewCoord(lastPoint);
		float sampleDepth = texture2DLod(depthtex0, uv, 0.0).x;
		sampleDepth = linearizeDepth(sampleDepth);
		if(testDepth - sampleDepth < 0.5)
		{
			vec3 hitNormal = texture2D(gnormal, uv).rgb * 2.0 - 1.0;
			
			if (dot(direction, hitNormal) < 0) {
			
				hitColor.rgb = texture2DLod(gcolor, uv, int(roughness * 3.0)).rgb;
				hitColor.a = clamp(1.0 - pow(distance(uv, vec2(0.5)) * 2.0, 2.0), 0.0, 1.0);

			}
		}
	}
	return hitColor;
}

float radicalInverse_VdC(int bits) {
    
    bits = (bits << 16) | (bits >> 16);
    bits = ((bits & 0x55555555) << 1) | ((bits & 0xAAAAAAAA) >> 1);
    bits = ((bits & 0x33333333) << 2) | ((bits & 0xCCCCCCCC) >> 2);
    bits = ((bits & 0x0F0F0F0F) << 4) | ((bits & 0xF0F0F0F0) >> 4);
    bits = ((bits & 0x00FF00FF) << 8) | ((bits & 0xFF00FF00) >> 8);

    return float(bits) * 2.3283064365386963e-10;
	
}
 
vec4 getLandRayTrace(vec3 fragpos, vec3 normal, float roughness) {

	vec3 direction = normalize(reflect(normalize(fragpos), normalize(normal)));

	vec2 uv2 = texcoord.st * vec2(viewWidth, viewHeight);
	float c = (uv2.x + uv2.y) * 0.25;
	float jitter = mod(c, 1.0);
	
	return RT(fragpos+normal*(-fragpos.z/far*0.2+0.05),direction,jitter,roughness);

}

float GetEmmisive(in vec2 coord) {
	return texture2D(gaux1, texcoord.st).b;
}

float GetMetallic(in vec2 coord) {
	return texture2D(gaux1, texcoord.st).g;
}

float GetRoughness(in vec2 coord) {
	return texture2D(gaux1, texcoord.st).r;
}

#define Positive(input) max(0.0000001, input)

vec3 FresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness) {
	return F0 + (max(vec3(1.0 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
}

vec3 getPBRIBL(in vec3 viewPosition, in float roughness, in float metallic, in vec3 color) {

	vec3 halfVector = normalize(lightVector - normalize(viewPosition));
	vec3 F0 = vec3(0.04);
	F0 = mix(F0, color, metallic);
	
	vec3 F = FresnelSchlickRoughness(Positive(dot(halfVector, -normalize(viewPosition))), F0, roughness);

	return (1.0 - roughness) * F;
	
}

void GodRays(inout vec3 finalComposite) {

	const int gr_samples = 12;
	const float gr_density  = 0.4;
	float gr_exposure = 0.02f;
	
	const float blurScale = 0.01;
	const float sigma = 0.25;
	
	vec4 sunP = vec4(sunPosition * (timeNoon - timeMidnight), 1.0) * gbufferProjection;
	     sunP = vec4(sunP.xyz / sunP.w, 1.0);
	vec2 lightPos = sunP.xy / sunP.z * 0.5 + 0.5;

	vec2 deltaTextCoord = vec2(texcoord.st - lightPos.xy);
		 deltaTextCoord *= 1.0 / float(gr_samples) * gr_density;
       	 deltaTextCoord = normalize(deltaTextCoord);	
	
	vec2 coord = texcoord.st;
	
	int center  = (gr_samples - 1) / 2;
	vec3 blur   = vec3(0.0);
	
	float gr = 0.0;
	float tw = 0.0;

	coord -= deltaTextCoord * center * blurScale;

    for(int i = 0; i < gr_samples; i++) {
    
		coord -= deltaTextCoord * blurScale;
		float dist = (i - float(center)) / center;
		float sample = 0.0;	
              sample = texture2D(gcolor, coord).a;
	    float weight = 1.0 / sqrt(2.0 * pi * sigma) * exp(-(dist * dist) / (2.0 * sigma));
		tw += weight;
		gr += sample;

    }

	float truepos = 0.0f;
	if ((worldTime < 13000 || worldTime > 23000) &&  sunPosition.z < 0) truepos = 1.0 * (timeSunrise + timeNoon + timeSunset); 
	if ((worldTime < 23000 || worldTime > 13000) && -sunPosition.z < 0) truepos = 3.0 * timeMidnight; 			

	finalComposite = mix(finalComposite, rayColor, ((gr/tw) * gr_exposure * truepos * length(rayColor)) / sqrt(3.0) * sunColor * timeFading);

}

float GetDepthLinear(in vec2 coord) {
	return 2.0f * near * far / (far + near - (2.0f * texture2D(gdepthtex, coord).x - 1.0f) * (far - near));
}

float GetDepthLinear1(in vec2 coord) {
	return 2.0f * near * far / (far + near - (2.0f * texture2D(depthtex1, coord).x - 1.0f) * (far - near));
}

void main() {

	vec3 color = texture2D(gcolor, texcoord.st).rgb;
	vec3 normal = texture2D(gnormal ,texcoord.st).rgb * 2.0 - 1.0;
	vec2 mclight = texture2D(gaux2, texcoord.st).xy;
	
	float stage     = texture2D(gaux2, texcoord.st).b;
	float pixeldepth  = texture2D(gdepthtex, texcoord.st).x;
	float pixeldepth1 = texture2D(depthtex1, texcoord.st).x;
	
	float roughness = GetRoughness(texcoord.st);
	float metallic  = GetMetallic (texcoord.st);
	float emmisive  = GetEmmisive (texcoord.st);
	
	float iswater  = float(stage > 0.15f && stage < 0.25f);
	float isice    = float(stage > 0.35f && stage < 0.45f);
	
	float island  = float(pow(pixeldepth,  2.0) < pow(pixeldepth,  1.0));
	float island1 = float(pow(pixeldepth1, 2.0) < pow(pixeldepth1, 1.0));
	
	float rainmask = texture2D(gaux1, texcoord.st).a;
	
	//Calculate Positions
	vec4 fragpos  = gbufferProjectionInverse * vec4(vec3(texcoord.st, pixeldepth) * 2.0 - 1.0, 1.0);
	     fragpos /= fragpos.w;
	
	vec4 worldpos = gbufferModelViewInverse * fragpos;
	
	//Add Sky
	vec3 ambLight = mix(ambientColor, vec3(0.2) * (1.0 - timeMidnight * 0.98), rainStrength);
	
	float iswet = wetness * pow(mclight.y, 10.0f) * sqrt(0.5 + max(dot(normal, normalize(upPosition)), 0.0));
	
	vec3 reflectVec = reflect(fragpos.xyz,  normal);
	vec3 reflectPos = reflect(worldpos.xyz, normal);
	
	float hasSun  = (isice * 0.2f + iswater) * (1.0f - rainStrength);
		  hasSun *= texture2D(gaux2, texcoord.st).a;
	
	//Add Atmospheric.
	vec3 skyLight = getAtmospheric(reflectVec, ambLight, hasSun);
	//Add Clouds.
	vec4 cloud    = getClouds(reflectVec, ambLight);
	
	//Add up all elements.
	vec3 fakesky = mix(skyLight, cloud.rgb, cloud.a) * (eyeBrightnessSmooth.y / 240.0f * 0.98f + 0.02f);
	
	if (bool(iswater) || bool(isEyeInWater)) {
		
		const float	refractstrength = 0.0035;
	
		float deltaPos = 0.01;
		float h0 = doWave(worldpos.xyz + cameraPosition.xyz, WAVE_HEIGHT * 2.0f);
		float h1 = doWave(worldpos.xyz + cameraPosition.xyz - vec3(deltaPos, 0.0, 0.0), WAVE_HEIGHT * 2.0f);
		float h2 = doWave(worldpos.xyz + cameraPosition.xyz - vec3(0.0, 0.0, deltaPos), WAVE_HEIGHT * 2.0f);

		float dX = ((h0 - h1)) / deltaPos;
		float dY = ((h0 - h2)) / deltaPos;

		float nX = sin(atan(dX));
		float nY = sin(atan(dY));

		vec3 refract  = normalize(vec3(nX, nY, 1.0));
		float depth1 = GetDepthLinear1(texcoord.st);
		float depth0 = GetDepthLinear(texcoord.st);
		
		float refMult = depth1 - depth0;
		vec2 coordref = texcoord.st + refract.xy * sqrt(refMult) * refractstrength / pow(depth1, 0.25f);
		
		vec3 fakecolor  = texture2DLod(gcolor, coordref.st, 0.0).rgb * 0.25;
		     fakecolor += texture2DLod(gcolor, coordref.st, 1.0).rgb * 0.50;
			 fakecolor += texture2DLod(gcolor, coordref.st, 2.0).rgb * 0.15;
			 fakecolor += texture2DLod(gcolor, coordref.st, 3.0).rgb * 0.10;
		
		color.rgb = mix(color.rgb, fakecolor, min(iswater + isEyeInWater, 1.0f));
		
		vec4 reflection = getWaterRayTrace(fragpos.xyz, normal);
			 reflection.rgb = mix(fakesky * mclight.y * (1.0f - isEyeInWater) + color.rgb * isEyeInWater, reflection.rgb, reflection.a) * 1.5f;
			 
		float fresnel = pow(max(dot(normalize(fragpos.xyz), normal) + 1.0, 0.0f), 5.0) * 0.98 + 0.02;
		color.rgb = mix(color.rgb, reflection.rgb, fresnel * iswater);
	
	} else {
	
		vec3 F = getPBRIBL(fragpos.xyz, roughness, metallic, color.rgb);
		
		vec4 landibl     = getLandRayTrace(fragpos.xyz, normal, roughness * (1.0f - 0.25f * wetness * metallic));		
			 landibl.rgb = mix(fakesky * 1.5f * pow(mclight.t, 4.0f), landibl.rgb / (landibl.rgb + vec3(1.0f)) * 2.0f * 0.8f, landibl.a) * F * (1.0f - roughness);
			 
		float fresnel = pow(dot(normalize(fragpos.xyz), normal) + 1.0, 3.0) * 0.9 + 0.1;
		
		color.rgb += landibl.rgb * (1.0f - isEyeInWater * (1.0f - iswater)) * fresnel * mix(8.0f, 1.0f, 2 * roughness - roughness * roughness) * mix(1.0f, 4.0f, rainmask * iswet);

	}

	#ifdef GODRAYS
		GodRays(color.rgb);
	#endif
	
	color.rgb += getSun(fragpos.xyz, 2E4) * pow(sunColor, vec3(2.2f)) * (1.0f - island1) * (1.0f - isice * 0.5f);
	
/* DRAWBUFFERS:0 */

	//0:gcolor    = albedo(r.g.b), cloudmask(a) RGBA16
	//1:gdepth    = materials(r), luminance(g) RG16F
	//2:gnormal   = normals(r.g.b) RGB16
	//3:composite = bloomdata/aaEdgeTex(r.g.b) RGB16
	//4:gaux1     = specular(r.g.b) RGB16
	//5:gaux2     = lmcoord(r.g), state(b), godrays(a) RGBA16
	//6:gaux3     = aaAreaTex
	//7:gaux4     = aaSearchTex
	
	// state 
	// 0.0 : none 
	// 0.1 : ishand
	// 0.2 : iswater
	// 0.3 : isentity
	// 0.4 : isice
	
    gl_FragData[0] = vec4(color.rgb, 1.0);

}
