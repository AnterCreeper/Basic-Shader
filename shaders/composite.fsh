#version 120

// Basic Shader Version v3.3
// Kernel Version v2.1

// This file is part of Basic Shader.
// This shader don't have any profile.
// Everything is configured by default.
//
// (C) Copyright 2017 AnterCreeper <wangzhihao9@yeah.net>
// This Shader is Written by AnterCreeper. Some rights reserved.
// You can use my code; You can modify my code; You can share your
// own style shader based on it.
//
// But ... You >> MUST << obey the gnu licenses.
//
// Some codes from NVIDIA, ATI, shadertoy, Learn OpenGL, etc..
// These codes is allowed in open source.
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
#define RENDER_WATER
#define SCALE

//Properties of effects
const int noiseTextureResolution  = 720;

const float sunPathRotation       = -40.0;
const float eyeBrightnessHalflife = 6.0f;
const float ambientOcclusionLevel = 0.6f;

const float wetnessHalflife       = 500.0f;
const float drynessHalflife 	  = 20.0f;

const float shadowDistanceRenderMul = 1.0;
const float shadowIntervalSize      = 2.0;

//Please read the license before change things below this line !!

const int RGBA16        = 0;
const int RGBA32F 		= 12450;
const int gcolorFormat 	= RGBA16;
const int gnormalFormat = RGBA32F;

uniform int moonPhase;
uniform int isEyeInWater;

uniform float far;
uniform float wetness;
uniform float rainStrength;
uniform float frameTimeCounter;

uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform vec3 cameraPosition;
uniform vec3 shadowLightPosition;

uniform ivec2 eyeBrightnessSmooth;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform sampler2D gcolor;
uniform sampler2D gnormal;
uniform sampler2D gdepthtex;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D composite;
uniform sampler2D noisetex;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

varying vec4 texcoord;

varying vec3 sunlight;
varying vec3 ambientColor;
varying vec3 colorTorchlight;

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
varying float timeSkyDark;

const int maxf  = 4;				                    //Number of refinements.

const float stp = 1.2;			                        //Size of one step for raytracing algorithm.
const float ref = 0.1;			                        //Refinement multiplier.
const float inc = 2.2;			                        //Increasement factor at each step.
 
#include "/lib/Envlib.frag"
#include "/lib/PRlib.frag"
#include "/lib/Noiselib.frag"

vec3 nvec3(vec4 pos){
    return pos.xyz/pos.w;
}

vec4 nvec4(vec3 pos){
    return vec4(pos.xyz, 1.0);
}

float cdist(vec2 coord) {
	return max(abs(coord.s-0.5),abs(coord.t-0.5))*2.0;
}

float calcluma(vec3 color) {
	return dot(color.rgb,vec3(0.2125f, 0.7154f, 0.0721f));
}

float noise(in vec2 p){
	return texture2D(noisetex, fract(p)).x;
}

#define SAMPLE1 40
#define SAMPLE2 55

vec4 raytrace(vec3 fragpos, vec3 normal) {

    vec4 color = vec4(0.0);
    vec3 start = fragpos;
    vec3 rvector = normalize(reflect(normalize(fragpos), normalize(normal)));
    vec3 vector = stp * rvector;
    vec3 oldpos = fragpos;
    fragpos += vector;
	vec3 tvector = vector;
    int sr = 0;
    for(int i=0;i<SAMPLE1;i++){
	
        vec3 pos = nvec3(gbufferProjection * nvec4(fragpos)) * 0.5 + 0.5;
        if(pos.x < 0 || pos.x > 1 || pos.y < 0 || pos.y > 1 || pos.z < 0 || pos.z > 1.0) break;
        vec3 spos = vec3(pos.st, texture2D(depthtex1, pos.st).r);
        spos = nvec3(gbufferProjectionInverse * nvec4(spos * 2.0 - 1.0));
        float err = abs(fragpos.z-spos.z);
		
			if(err < pow(length(vector)*1.85,1.15)){
                sr++;
                if(sr >= maxf){
                    float border = clamp(1.0 - pow(cdist(pos.st), 20.0), 0.0, 1.0);
                    color = texture2D(gcolor, pos.st);
					float land = texture2D(gnormal, pos.st).g;
					land = mix(1.0,0.05,land);
					land = float(land < 0.03);
					spos.z = mix(fragpos.z,2000.0*(0.4+clamp(sunVisibility+moonVisibility,0,1)*0.6),0.0);	

					color.a = 1.0;
                    color.a *= border;
                    break;
                }
				tvector -=vector;
                vector *=ref;
			}
			
        vector *= inc;
        oldpos = fragpos;
        tvector += vector;
		fragpos = start + tvector;
		
    }
	
    return color;
	
}

vec4 land_raytrace(vec3 fragpos, vec3 normal, float rough) {

	vec4 color = vec4(0.0);
	vec4 samples = vec4(0.0);
	vec3 start = fragpos;
	vec3 rvector = normalize(reflect(normalize(fragpos), normalize(normal)));
	vec3 vector = 20.0 * rvector;
	vec3 oldpos = fragpos;
	fragpos += vector;
	vec3 tvector = vector;
	int sr = 0;
		
	for(int i=0;i<SAMPLE2;i++){
		
		vec3 pos = nvec3(gbufferProjection * nvec4(fragpos)) * 0.5 + 0.5;
		if(pos.x < 0 || pos.x > 1 || pos.y < 0 || pos.y > 1 || pos.z < 0 || pos.z > 1.0) break;
		vec3 spos = vec3(pos.st, texture2D(depthtex1, pos.st).r);
		spos = nvec3(gbufferProjectionInverse * nvec4(spos * 2.0 - 1.0));
		float err = distance(fragpos.xyz,spos.xyz);
		if(err < length(vector)*pow(length(tvector),0.11)*1.75){
				sr++;
				float border = clamp(1.0 - pow(cdist(pos.st), 5.0), 0.0, 1.0);
				samples += texture2DLod(gcolor, pos.st, int(rough * 3.0));
				
				color = samples;
				color.a = 1.0;
				color.a *= border;
				break;
				
			tvector -=vector;
			vector *= 0.5;
				
		}
			
		vector *= 2.0;
		oldpos = fragpos;
		tvector += vector;
		fragpos = start + tvector;
		
	}
		
	return color;
	
}

float waterH(in vec3 pos){

	float speed = 0.6;
	float t = frameTimeCounter * speed;
	
	vec2 coord = pos.xz / (64 + 32 + 16);
		 coord.x -= t / 128;
	
	float wave = 0.0;
	
	wave += noise(coord * vec2(2.00, 1.00));	coord /= 6;	  coord.x -= t / 256; coord.y += t / (128 + 64) * 1.25;
	wave += noise(coord * vec2(1.75, 1.50));	coord.y /= 4; coord.x /= 2;       coord.xy -= t / (256 - 64) * 0.5;
	wave += noise(coord * vec2(1.50, 2.00));
	
	return wave * 0.02;

}

LightSourcePBR sun;
LightSource torch;
LightSource amb;

Material landmat;

#define PBRFACTOR 4.0f
#define MATFACTOR 1000

void main() {

	#define Exposure  0.68f
	#define Exposure2 0.82f
	
    vec4 color   = texture2D(gcolor,texcoord.st);
	vec3 normal  = texture2D(gaux1, texcoord.st).rgb * 2.0 - 1.0;
	vec2 mclight = texture2D(gaux3, texcoord.st).xy;

	float pixeldepth  = texture2D(depthtex0, texcoord.st).x;
	float pixeldepth1 = texture2D(depthtex1, texcoord.st).x;
	float materials  = texture2D(gnormal,texcoord.st).x * MATFACTOR;

	float island   = float(pow(pixeldepth, 2.0) < pow(pixeldepth, 1.0));
	float iswater  = texture2D(gnormal,texcoord.st).g;
	float isentity = texture2D(gnormal,texcoord.st).b;
	
	float isglass  = float((materials > 159.9 && materials < 160.1) || (materials > 94.9 && materials < 95.1));
	
	if (isglass > 0.9) {
	  landmat.metallic  = 0.25f;
	  landmat.roughness = 0.02f;
	}
	
	//Calculate Positions
	vec4 fragposition  = gbufferProjectionInverse * vec4(texcoord.s * 2.0f - 1.0f, texcoord.t * 2.0f - 1.0f, 2.0f * pixeldepth - 1.0f, 1.0f);
		 fragposition /= fragposition.w;
	vec4 worldposition = gbufferModelViewInverse * fragposition;
	
	vec4 fragpos  = gbufferProjectionInverse * vec4(vec3(texcoord.st, pixeldepth1) * 2.0 - 1.0, 1.0);
         fragpos /= fragpos.w;
	if (isEyeInWater > 0.9) fragpos.xy *= 0.817;
	
	vec3 fragpos2 = vec3(texcoord.st, texture2D(gdepthtex, texcoord.st).r);
		 fragpos2 = nvec3(gbufferProjectionInverse * nvec4(fragpos2 * 2.0 - 1.0));
	
	vec3 fragpos3 = nvec3(gbufferProjectionInverse * nvec4(vec3(texcoord.xy, pixeldepth) * 2.0 - 1.0));
    vec3 upos = nvec3(gbufferProjectionInverse * nvec4(vec3(texcoord.xy, texture2D(depthtex1, texcoord.xy).x) * 2.0 - 1.0));
	vec3 uvec = fragpos3 - upos;
	float UdotU = abs(dot(uvec, normal));
	float depth = length(uvec) * UdotU;
	
	//Build Material for PBR
	material_build(landmat, fragposition.xyz);
	
	//Add Atmosperic
    vec3 ambientlight = mix(ambientColor, vec3(0.3) * (1.0 - timeMidnight * 0.98), rainStrength);
    vec3 skyGradient  = getAtmosphericScattering(color.rgb, fragpos.xyz, 1.0f, ambientlight);
		 skyGradient  = mix(pow(skyGradient, vec3(0.8f - 0.1f * timeMidnight)), pow(skyGradient, vec3(2.2f)), timeSunrise + timeSunset + timeMidnight * 0.2f);
		 
	//Add Stars
	float starNoise = fract(sin(dot(texcoord.xy * 4.0f + (worldposition.xy + cameraPosition.xy) / 25000000.0 * vec2(frameTimeCounter / 300.0, frameTimeCounter / 300.0), vec2(18.9898f, 28.633f))) * 4378.5453f);
		  starNoise = pow(starNoise, pow(2.0f, 10.0f));
	
	float horizont 			= abs(worldposition.y + cameraPosition.y - texcoord.y);
	float horizont_position = max(pow(max(1.0 - horizont/(7.5*100.0),0.01),8.0)-0.1,0.0);
	
	float stars = starNoise * timeMidnight * (0.1 - horizont_position * 0.1);

	const float steep = 0.18f;  //Scale down at night.
	if (!(island > 0.9)) color.rgb = skyGradient * (0.5f + steep - timeMidnight * steep) * 1.12f + stars;
	
	//color.rgb += CalculateSunglow(fragposition) * sunlight * 0.1f;
	
	//Prepare for PBR
	sun.L 				  = normalize(shadowLightPosition);
	sun.light.attenuation = 1.0;
	sun.light.color 	  = sunlight;
	
	amb.color 		  = ambientColor;
	amb.attenuation   = light_mclightmap_simulated_GI(mclight.y, sun.L, landmat.N);
	
	torch.color 	  = colorTorchlight * 0.1;
	torch.attenuation = light_mclightmap_attenuation(mclight.x);
	
	//Prepare for water
	vec3 fakesky = getAtmosphericScattering(color.rgb, reflect(fragpos2, normal), 0.0, ambientlight);
	const vec3 primaryWavelengths = vec3(700, 546.1, 435.8);
	vec3 watercolor = normalize(vec3(1.0f) / normalize(pow(primaryWavelengths,vec3(4.0f)))) / 4.0f;
	
	#ifdef RENDER_WATER
	
	 if (iswater > 0.9 || bool(isEyeInWater)) {
		
		const float	refractstrength = 0.05;
	
		float deltaPos = 0.1;
		float h0 = waterH(worldposition.xyz + cameraPosition.xyz);
		float h1 = waterH(worldposition.xyz + cameraPosition.xyz - vec3(deltaPos, 0.0, 0.0));
		float h2 = waterH(worldposition.xyz + cameraPosition.xyz - vec3(0.0, 0.0, deltaPos));

		float dX = ((h0 - h1)) / deltaPos;
		float dY = ((h0 - h2)) / deltaPos;

		float nX = sin(atan(dX));
		float nY = sin(atan(dY));

		vec3 refract  = normalize(vec3(nX, nY, 1.0));
		float refMult = 0.005 - dot(normal, normalize(fragposition).xyz) * refractstrength;
		vec2 coordref = texcoord.st + refract.xy * refMult;
		
		vec4 ref  = texture2DLod(gcolor, coordref, 1.0) * 0.5;
			 ref += texture2DLod(gcolor, coordref, 2.0) * 0.3;
			 ref += texture2DLod(gcolor, coordref, 3.0) * 0.2;
				
		color.rgb = mix(color.rgb, ref.rgb, min(iswater + isEyeInWater, 1.0f));
		
		float dist_diff = bool(isEyeInWater) ? length(fragposition.xyz) : depth;
		float dist_diff_N = min(1.0, dist_diff * 0.125);
		float absorbtion = 2.0 / (dist_diff_N + 1.0);
		vec3 watercolor = color.rgb * absorbtion * (0.2 + 0.8 * isEyeInWater * (1.0f - iswater));
		vec3 waterfog = mix(vec3(0.2,0.8,1.0), vec3(0.1,0.35,0.5), rainStrength) * color.rgb;
		color.rgb = mix(waterfog, watercolor, smoothstep(0.0, 1.0, absorbtion));
		
		float normalDotEye = dot(normalize(normal), -normalize(fragpos2));
		float fresnel      = pow(1.0 - normalDotEye, 2.0);
			 
		vec4 reflection_w     = raytrace(fragpos2,normal);
			 reflection_w.a   = min(reflection_w.a,1.0);
			 reflection_w.rgb = mix(fakesky * (1.2f - timeMidnight), reflection_w.rgb, reflection_w.a);
		
		color.rgb = mix(color.rgb, reflection_w.rgb, fresnel * Exposure2 * (0.2f + (1.0f - timeMidnight) * (1.0f - (1.0f - timeMidnight) * (1.0f - timeNoon))) * 0.4f * (1.0f - isentity));
		color.rgb = mix(color.rgb, fakesky * Exposure, 0.25f * (2.0f - reflection_w.a * 0.6f) * 0.4f * (1.0f - isentity)) * Exposure2;
		
	 }
	
	#endif
	
	//Calculate PBR
	float iswet = wetness * pow(mclight.y, 10.0f) * sqrt(0.5 + max(dot(normal, normalize(upPosition)), 0.0));
		
	vec3 viewRef     = reflect(landmat.nvpos, landmat.N);
	vec3 pbr_reflect = min(light_calc_PBR(sun, landmat, iswet), PBRFACTOR) / PBRFACTOR;
	vec3 torchlight  = light_calc_diffuse(torch, landmat);
		 torchlight  = torchlight / (torchlight + vec3(1.0f));
	vec3 amblight    = light_calc_diffuse(amb, landmat);
		 amblight    = pow(amblight, vec3(0.7f)) * (0.8f + timeMidnight * 1.8f);
	if (landmat.roughness < 0.7)
	     amblight   += light_calc_PBR_IBL(viewRef, landmat, fakesky) * island;  //Add ibl to amblight
		 amblight   /= PBRFACTOR;
	
    // Set up domain for wet reflect
	if (island > 0.9 && iswater < 0.9 && isentity < 0.9) {
	
	vec3 sky_Color  = vec3(0.4);
		 sky_Color *= eyeBrightnessSmooth.y / 255.0;
		 sky_Color  = mix(fakesky, sky_Color, rainStrength * 0.8f + wetness * 0.2f);
	
	vec2 q = worldposition.xz + cameraPosition.xz;
    vec2 p = -1.0 + 3.0 * q;
		 p /= 35.0;
		  
	float f = fbm(p * 4.0);
	float cover = 0.55 * clamp(wetness, 0.0f, 1.0f);
	float sharpness = 0.996; // Brightness
	
    float c = max(f - (1.0 - cover), 0.0f);
		  f = 1.0 - (pow(1.0 - sharpness, c));
	
	vec4 reflection = land_raytrace(fragpos2, normal, landmat.roughness * (1.0f - 0.25f * wetness * landmat.metallic));
				
	float normalDotEye = dot(normal, normalize(fragpos2));
    float fresnel = clamp(pow(1.0 + normalDotEye, 1.0),0.0,1.0);
				
	reflection.rgb = mix(sky_Color, reflection.rgb, reflection.a * mclight.y) * 1.4; //fake sky reflection, avoid empty spaces
	reflection.a = min(reflection.a + 0.75,1.0);

	float dark  = iswet * landmat.roughness * 1.5f;
	
	if (!bool(timeMidnight) && (island > 0.9)) {
		if (dark > 0.10) color *= 1.0;
		if (dark > 0.15) color *= 0.98;
		if (dark > 0.20) color *= 0.96;
		if (dark > 0.25) color *= 0.94;
		if (dark > 0.30) color *= 0.92;
		if (dark > 0.35) color *= 0.90;
		if (dark > 0.40) color *= 0.88;
		if (dark > 0.45) color *= 0.86;
		if (dark > 0.50) color *= 0.84;
	}
	
	color.rgb = mix(color.rgb, reflection.rgb, fresnel * reflection.a * (1.0f - landmat.roughness + f * iswet * 2.0f * (0.5f + landmat.metallic * 0.5f)));
	
	}
	
	#ifdef SCALE
	 color.rgb *= 0.01;
	#endif
	
/* DRAWBUFFERS:0137 */

	//0:gcolor  = albedo
	//2:gnormal = materials,iswater,isentity
	//4:gaux1   = normals
	//5:gaux2   = specular
	//6:gaux3   = lmcoord,ishand

	gl_FragData[0] = color;
	gl_FragData[1] = vec4(amblight   , 1.0f);//Send amblight      to gdepth
 	gl_FragData[2] = vec4(pbr_reflect, 1.0f);//Send pbr highlight to composite
	gl_FragData[3] = vec4(torchlight , 1.0f);//Send torchlight    to gaux4

}