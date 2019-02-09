#version 120
// Basic Shader Version v4.0
// Kernel Version v3.0

// This file is part of Basic Shader.

// (C) Copyright 2019 AnterCreeper <wangzhihao9@hotmail.com>
// This Shader is Written by AnterCreeper. Some rights reserved.
//
// Basic Shader is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Basic Shader is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Basic Shader at /LICENSE.
// If not, see <http://www.gnu.org/licenses/>.
//

//Switch of effects
//#define SMAA
#define HBAO

#define WET_EFFECT

#define FOG

//#define NO_CLOUDS

//Properties of effects
const int noiseTextureResolution  = 720;

const float sunPathRotation       = -25.0;
const float eyeBrightnessHalflife = 6.0f;
const float ambientOcclusionLevel = 0.6f;

const float wetnessHalflife = 500.0f;
const float drynessHalflife = 80.0f;

const float shadowDistanceRenderMul = 1.0;
const float shadowIntervalSize      = 2.0;

//Please read the license before change things below this line !!

const bool gcolorMipmapEnabled = true;

const int RGB8    = 0;
const int RGBA8   = 1;
const int RG16F	  = 2;
const int RGB16   = 3;
const int RGBA16  = 4;
const int RGBA16F = 5;

const int gcolorFormat    = RGBA16F;
const int gdepthFormat    = RG16F;
const int gnormalFormat   = RGB16;
const int compositeFormat = RGBA16;
const int gaux1Format     = RGB16;
const int gaux2Format     = RGBA16;

uniform int moonPhase;
uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;

uniform float far;
uniform float near;
uniform float wetness;
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;
uniform float rainStrength;
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

varying vec4 offset[3];

#include "/lib/Noiselib.frag"
#include "/lib/Envlib.frag"
#include "/lib/AOlib.frag"
#include "/lib/AAlib.glsl"

float GetMetallic(in vec2 coord) {
	return clamp(texture2D(gaux1, texcoord.st).g, 1E-5, 1.0f - 1E-5);
}

float GetEmmisive(in vec2 coord) {
	return clamp(texture2D(gaux1, texcoord.st).b, 0.0f, 1.0f);
}

float GetRoughness(in vec2 coord) {
	return clamp(1.0f - texture2D(gaux1, texcoord.st).r, 1E-5, 1.0f - 1E-5);
}

float GetDepthLinear(in vec2 coord) {
	return 2.0f * near * far / (far + near - (2.0f * texture2D(gdepthtex, coord).x - 1.0f) * (far - near));
}

float GetDepthLinear1(in vec2 coord) {
	return 2.0f * near * far / (far + near - (2.0f * texture2D(depthtex1, coord).x - 1.0f) * (far - near));
}

float Luminance(vec3 color) {
	return dot(color.rgb, vec3(0.2125f, 0.7154f, 0.0721f));
}

void main() {
	
	vec3 color   = pow(texture2D(gcolor,texcoord.st).rgb, vec3(2.2f));
	vec3 normal  = texture2D(gnormal ,texcoord.st).rgb * 2.0 - 1.0;
	vec2 mclight = texture2D(gaux2, texcoord.st).xy;
	
	float stage     = texture2D(gaux2, texcoord.st).b;
	float materials = texture2D(gdepth, texcoord.st).r;
	
	float metallic  = GetMetallic (texcoord.st);
	float emmisive  = GetEmmisive (texcoord.st);
	float roughness = GetRoughness(texcoord.st);
	
	float iswater = float(stage > 0.15f && stage < 0.25f);
	float isice   = float(stage > 0.35f && stage < 0.45f);
	
	float pixeldepth0 = texture2D(depthtex0, texcoord.st).x;
	float pixeldepth1 = texture2D(depthtex1, texcoord.st).x;
	float pixeldepth2 = texture2D(depthtex2, texcoord.st).x;
	
	float island0 = float(pow(pixeldepth0, 2.0) < pow(pixeldepth0, 1.0));
	float island  = float(pow(pixeldepth1, 2.0) < pow(pixeldepth1, 1.0));
	float isglass = float(materials > 94.9 && materials < 95.1);
	
	//Calculate Positions
	vec4 fragpos  = gbufferProjectionInverse * vec4(vec3(texcoord.st, pixeldepth1) * 2.0 - 1.0, 1.0);
	     fragpos /= fragpos.w;
	vec4 worldpos = gbufferModelViewInverse * fragpos;
	
	//Add Sky
	//Calculate Ambient Scattering
	vec3 ambLight = mix(ambientColor, vec3(0.2) * (1.0 - timeMidnight * 0.98), rainStrength);

	//Add Atmospheric.
	vec3 skyLight = getAtmospheric(fragpos.xyz, ambLight, 0.0);
	//Add Clouds.
	vec4 cloud    = getClouds(fragpos.xyz, ambLight);
	
	//Add up all elements.
	vec3 sky   = mix(skyLight, cloud.rgb, cloud.a);
	color.rgb  = mix(color.rgb, sky.rgb + color * timeSkyDark * 0.5f * (1.0f - isice * timeMidnight), (1.0f - isice * 0.5f) * (1.0f - island));
	color.rgb *= 1.0f - isglass * 0.95f * (1.0f - island) * timeMidnight;
	
	float fogDensity = mix(0.01f, 0.005f, isEyeInWater);
	float visibility = 1.0f / (pow(exp(GetDepthLinear1(texcoord.st) * fogDensity), 1.0f));
	float fogFactor = 1.0f - visibility;
		  fogFactor = clamp(fogFactor, 0.0f, 1.0f);
		  
	const vec3 primaryWavelengths = vec3(700, 546.1, 435.8);
	vec3 watercolor = vec3(normalize(vec3(1.0f) / normalize(pow(primaryWavelengths, vec3(2.2f)))) / 4.0f) * Luminance(sunColor);
	
	color.rgb = mix(sqrt(watercolor * ambientColor * Luminance(sunColor)) * 0.18f, color.rgb, 1.0f - (1.0f - island) * island0 * fogFactor * (1.0f - isglass) * (1.0f - isice));
	
	//Do Land Wet.
	//Calculate Positions.
    vec2 coord  = vec2(-1.0) + 3.0 * (worldpos.xz + cameraPosition.xz);
		 coord /= 35.0;

	//Calculate Wet Factor.
	float iswet = wetness * pow(mclight.y, 10.0f) * sqrt(0.5 + max(dot(normal, normalize(upPosition)), 0.0));
	float dark  = iswet * (roughness * 0.8f + 0.2f) * 1.5f;
	
	#ifdef WET_EFFECT
	
	//Get Noise.
	float noise = 0.0f;
	if (iswet > 0.0f) noise = fbm(coord * 4.0);
	float cover = clamp(wetness, 0.0f, 1.0f);
		  cover = cover / (cover + 1.0f);
	float sharpness = 0.80;
	
    float factor = max(noise - (1.0 - cover), 0.0f);
		  noise = 1.0 - pow(1.0 - sharpness, factor);
	
	//Change Reflect Factor.
	float mixer = clamp(noise * iswet * 8.0f * (1.0f - iswater), 0.0f, 1.0f);
	
	if (bool(iswater) || !bool(isEyeInWater)) {
		roughness = mix(roughness, 0.15f, mixer);
		metallic  = mix(metallic,  0.06f, mixer);
	}
	
	#else
	
	float mixer = 0.0f;
	
	#endif

	roughness = mix(roughness, 0.25, isglass);
	metallic  = mix(metallic,  0.10, isglass);
	
	#ifdef WET_EFFECT
	//Make Land Dark according to the wetness.
	if (!bool(timeMidnight) && bool(island)) {
		if (dark > 0.10) {color *= 1.0; 
		if (dark > 0.15) {color *= 0.98;
		if (dark > 0.20) {color *= 0.96;
		if (dark > 0.25) {color *= 0.94;
		if (dark > 0.30) {color *= 0.92;
		if (dark > 0.35) {color *= 0.90;
		if (dark > 0.40) {color *= 0.88;
		if (dark > 0.45) {color *= 0.86;
		if (dark > 0.50)  color *= 0.84;}}}}}}}}
	}
	#endif
	
	color *= mix(1.0f, mix(20.0f, 36.0f, timeMidnight), emmisive / (emmisive + 1.0f) * 2.0f);

	vec2  aa = vec2(0.0f);
	float ao = 0.0f;
	
	#ifdef SMAA
	 	aa = getAAEdge(texcoord.st);
	#endif
	#ifdef HBAO
	 	ao = getAO(texcoord.st, normal);
	#endif
	
/* DRAWBUFFERS:0345 */

	//0:gcolor    = albedo(r.g.b), cloudmask/godrays(a) RGBA16
	//1:gdepth    = materials(r), luminance(g) RG16F
	//2:gnormal   = normals(r.g.b) RGB16
	//3:composite = bloomdata/aaEdgeTex(r.g.b) RGB16
	//4:gaux1     = specular(r.g.b) RGB16
	//5:gaux2     = lmcoord(r.g), state(b), ao(a) RGBA16
	//6:gaux3     = aaAreaTex
	//7:gaux4     = aaSearchTex
	
	// state 
	// 0.0 : none 
	// 0.1 : ishand
	// 0.2 : iswater
	// 0.3 : isentity
	// 0.4 : isice
	
	gl_FragData[0] = vec4(color.rgb, cloud.a * (1.0f - island));
	gl_FragData[1] = vec4(aa, 0.0f, 1.0f);
	gl_FragData[2] = vec4(roughness, metallic, emmisive, mixer);
	gl_FragData[3] = vec4(texture2D(gaux2, texcoord.st).rgb, ao);

}