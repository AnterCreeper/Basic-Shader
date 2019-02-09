#version 120
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh
#define Version 4u10

//Switch of effects
//#define LENS_FLARE			   //Fake Lens Effects.
//#define CINEMATIC_MODE           //Provide Film Effects.
//#define CAMERA_NOISE             //Add noise to screen like camera.

#define RAIN_LENS				   //Fake Lens Effects

#define DOF                        //Fake Lens Effects
#define DOF_BlurSize 4             //The higher number, the blurer picture. [1 2 3 4 5]

#define NoiseStrength 0.65         //Strength of Noise On Camera. [0.4 0.5 0.6 0.65 0.7]

const float CinematicHeight = 16;  //2.35:1 for Wide Screen,16:9 for Normal Film.
const float CinematicWidth = 9;

const int noiseTextureResolution  = 720;

//Lens properties of DOF
 //"Near to human eyes (gameplay)":
 const float focal = 0.024;
 const float sizemult = 100.0;
 float aperture = 0.009;
 // ----------------------------------
 //"Tilt shift (cinematics)":
 //const float focal = 0.3;
 //const float sizemult = 1.0;
 //float aperture = 0.3;	
 // ----------------------------------
 //"Normal properties of Lens"
 //const float focal = 0.05;
 //const float sizemult = 100.0;
 //float aperture = focal/7.0;	
 // ----------------------------------
 
//Please read the license before change things below this line !!

const bool gcolorMipmapEnabled    = true;
const bool compositeMipmapEnabled = true;

uniform sampler2D gcolor;     //final data input
uniform sampler2D composite;  //bloom data input

uniform sampler2D gaux3;
uniform sampler2D gaux4;

uniform sampler2D noisetex;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex0;

uniform float wetness;

uniform int   worldTime;
uniform int   moonPhase;
uniform int   isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;

varying vec4 texcoord;

varying vec3 sunColor;
varying vec3 moonColor;
varying vec3 ambientColor;
varying vec3 torchColor;
varying vec3 glowColor;

varying float sunvisibility;

varying float timeSunrise;
varying float timeNoon;
varying float timeSunset;
varying float timeMidnight;
varying float timeSunriseSunset;

varying float timeSkyDark;
varying float timeFading;

uniform vec3 sunPosition;

uniform float far;
uniform float near;
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;
uniform float rainStrength;
uniform float frameTimeCounter;

uniform mat4 gbufferProjection;

float pixelwidth  = 1.0 / viewWidth;
float pixelheight = 1.0 / viewHeight;

float sky = 1.0 - near / far / far;

//60 offsets of DOF,provides better effects.
const vec2 circle_offsets[60] = vec2[60]  ( vec2( 0.0000, 0.2500 ),
											vec2( -0.2165, 0.1250 ),
											vec2( -0.2165, -0.1250 ),
											vec2( -0.0000, -0.2500 ),
											vec2( 0.2165, -0.1250 ),
											vec2( 0.2165, 0.1250 ),
											vec2( 0.0000, 0.5000 ),
											vec2( -0.2500, 0.4330 ),
											vec2( -0.4330, 0.2500 ),
											vec2( -0.5000, 0.0000 ),
											vec2( -0.4330, -0.2500 ),
											vec2( -0.2500, -0.4330 ),
											vec2( -0.0000, -0.5000 ),
											vec2( 0.2500, -0.4330 ),
											vec2( 0.4330, -0.2500 ),
											vec2( 0.5000, -0.0000 ),
											vec2( 0.4330, 0.2500 ),
											vec2( 0.2500, 0.4330 ),
											vec2( 0.0000, 0.7500 ),
											vec2( -0.2565, 0.7048 ),
											vec2( -0.4821, 0.5745 ),
											vec2( -0.6495, 0.3750 ),
											vec2( -0.7386, 0.1302 ),
											vec2( -0.7386, -0.1302 ),
											vec2( -0.6495, -0.3750 ),
											vec2( -0.4821, -0.5745 ),
											vec2( -0.2565, -0.7048 ),
											vec2( -0.0000, -0.7500 ),
											vec2( 0.2565, -0.7048 ),
											vec2( 0.4821, -0.5745 ),
											vec2( 0.6495, -0.3750 ),
											vec2( 0.7386, -0.1302 ),
											vec2( 0.7386, 0.1302 ),
											vec2( 0.6495, 0.3750 ),
											vec2( 0.4821, 0.5745 ),
											vec2( 0.2565, 0.7048 ),
											vec2( 0.0000, 1.0000 ),
											vec2( -0.2588, 0.9659 ),
											vec2( -0.5000, 0.8660 ),
											vec2( -0.7071, 0.7071 ),
											vec2( -0.8660, 0.5000 ),
											vec2( -0.9659, 0.2588 ),
											vec2( -1.0000, 0.0000 ),
											vec2( -0.9659, -0.2588 ),
											vec2( -0.8660, -0.5000 ),
											vec2( -0.7071, -0.7071 ),
											vec2( -0.5000, -0.8660 ),
											vec2( -0.2588, -0.9659 ),
											vec2( -0.0000, -1.0000 ),
											vec2( 0.2588, -0.9659 ),
											vec2( 0.5000, -0.8660 ),
											vec2( 0.7071, -0.7071 ),
											vec2( 0.8660, -0.5000 ),
											vec2( 0.9659, -0.2588 ),
											vec2( 1.0000, -0.0000 ),
											vec2( 0.9659, 0.2588 ),
											vec2( 0.8660, 0.5000 ),
											vec2( 0.7071, 0.7071 ),
											vec2( 0.5000, 0.8660 ),
											vec2( 0.2588, 0.9659 ));

struct BloomDataStruct
{
	vec3 blur0;
	vec3 blur1;
	vec3 blur2;
	vec3 blur3;
	vec3 blur4;
	vec3 blur5;

	vec3 bloom;
	
} bloomData;

float GetDepthLinear(in float depth) {
	return 2.0f * near * far / (far + near - depth * (far - near));
}

float GetDepthLinear(in vec2 coord) {
	return 2.0f * near * far / (far + near - (2.0f * texture2D(gdepthtex, coord).x - 1.0f) * (far - near));
}

float Luminance(vec3 color) {
	return dot(color.rgb, vec3(0.2125f, 0.7154f, 0.0721f));
}

#include "/lib/Filter.frag"

void CalculateBloom(inout BloomDataStruct bloomData, in vec2 coord) {		//Retrieve previously calculated bloom textures

	//constants for bloom bloomSlant
	const float    bloomSlant = 0.05f;
	const float[6] bloomWeight = float[6] (pow(6.0f, bloomSlant),
										   pow(5.0f, bloomSlant),
										   pow(4.0f, bloomSlant),
										   pow(3.0f, bloomSlant),
										   pow(2.0f, bloomSlant),
										   1.0f
										   );
										   
	vec2 recipres = vec2(1.0f / viewWidth, 1.0f / viewHeight);
	
	bloomData.blur0  =  pow(texture_Bicubic(composite, (texcoord.st - recipres * 0.5f) * (1.0f / exp2(2.0f)) + vec2(0.0f, 0.0f)		 + vec2(0.000f, 0.000f)).rgb * 100, vec3(1.0f + 1.2f));
	bloomData.blur1  =  pow(texture_Bicubic(composite, (texcoord.st - recipres * 0.5f) * (1.0f / exp2(3.0f)) + vec2(0.0f, 0.25f)	 + vec2(0.000f, 0.025f)).rgb * 100, vec3(1.0f + 1.2f));
	bloomData.blur2  =  pow(texture_Bicubic(composite, (texcoord.st - recipres * 0.5f) * (1.0f / exp2(4.0f)) + vec2(0.125f, 0.25f)	 + vec2(0.025f, 0.025f)).rgb * 100, vec3(1.0f + 1.2f));
	bloomData.blur3  =  pow(texture_Bicubic(composite, (texcoord.st - recipres * 0.5f) * (1.0f / exp2(5.0f)) + vec2(0.1875f, 0.25f)	 + vec2(0.050f, 0.025f)).rgb * 100, vec3(1.0f + 1.2f));
	bloomData.blur4  =  pow(texture_Bicubic(composite, (texcoord.st - recipres * 0.5f) * (1.0f / exp2(6.0f)) + vec2(0.21875f, 0.25f) + vec2(0.075f, 0.025f)).rgb * 100, vec3(1.0f + 1.2f));
	bloomData.blur5  =  pow(texture_Bicubic(composite, (texcoord.st - recipres * 0.5f) * (1.0f / exp2(7.0f)) + vec2(0.25f, 0.25f)	 + vec2(0.100f, 0.025f)).rgb * 100, vec3(1.0f + 1.2f));
 	
	bloomData.bloom  = bloomData.blur0 * bloomWeight[5];
 	bloomData.bloom += bloomData.blur1 * bloomWeight[4];
 	bloomData.bloom += bloomData.blur2 * bloomWeight[3];
 	bloomData.bloom += bloomData.blur3 * bloomWeight[2];
 	bloomData.bloom += bloomData.blur4 * bloomWeight[1];
 	bloomData.bloom += bloomData.blur5 * bloomWeight[0];

}

void doDOF(inout vec3 color, in vec2 coord) {

    float depth = GetDepthLinear(texture2D(depthtex0,  coord.st).r);
    float focus = GetDepthLinear(texture2D(depthtex0, vec2(0.5)).r);
    float blursize = DOF_BlurSize * viewWidth / 1280;
    float factor  = min((abs(aperture * (focal * (depth - focus)) / (depth * (focus - focal)))) * sizemult, pixelwidth * blursize); 
		  factor += pow(distance(coord.st, vec2(0.5)), 2.5) * 0.005 + 0.0001;  //Add Edge Blur.

    vec3 bcolor = vec3(0);
	
	for (int i = 0; i < 60; i++) {
		bcolor += texture2D(gcolor, coord.st + circle_offsets[i] * factor * vec2(1.0, aspectRatio)).rgb;
	}
	
	color.rgb = bcolor / 60;
	
}

void AddRainFogScatter(inout vec3 color, in BloomDataStruct bloomData, in vec2 coord) {

	const float    bloomSlant = 0.2f;
	const float[6] bloomWeight = float[6] (pow(6.0f, bloomSlant),
										   pow(5.0f, bloomSlant),
										   pow(4.0f, bloomSlant),
										   pow(3.0f, bloomSlant),
										   pow(2.0f, bloomSlant),
										   1.0f
										   );

	vec3 fogBlur = bloomData.blur0 * bloomWeight[5] + 
			       bloomData.blur1 * bloomWeight[4] + 
			       bloomData.blur2 * bloomWeight[3] + 
			       bloomData.blur3 * bloomWeight[2] + 
			       bloomData.blur4 * bloomWeight[1] + 
			       bloomData.blur5 * bloomWeight[0];

	float fogTotalWeight = 	1.0f * bloomWeight[0] + 
			       			1.0f * bloomWeight[1] + 
			       			1.0f * bloomWeight[2] + 
			       			1.0f * bloomWeight[3] + 
			       			1.0f * bloomWeight[4] + 
			       			1.0f * bloomWeight[5];

	fogBlur /= fogTotalWeight;

	float linearDepth = GetDepthLinear(coord.st);
	float fogDensity  = 0.5f * rainStrength + 2.0f * isEyeInWater;

	float visibility  = 1.0f / (pow(exp(linearDepth * fogDensity), 1.0f));
	float fogFactor   = 1.0f - visibility;
	      fogFactor   = clamp(fogFactor, 0.0f, 1.0f);
	      fogFactor  *= mix(0.0f, 0.35f, pow(eyeBrightnessSmooth.y / 240.0f, 6.0f));

	color = mix(color, fogBlur, fogFactor);

}

#include "/lib/Colorlib.frag"
#include "/lib/Noiselib.frag"

vec2 getRainRefract(in vec2 coord) {
	if (rainStrength > 0.0) {
		float noise  = hashmix((coord.st * vec2(aspectRatio, 1.0) + vec2(0.1, 1.0) * frameTimeCounter * 0.5f) * 2.0);
			  noise -= 0.6 * abs(hashmix((coord.st * vec2(aspectRatio, 1.0) * 2.0 + vec2(0.1, 1.0) * frameTimeCounter * 0.5f) * 3.0));
			  noise *= (noise * noise) * (noise * noise);
			  noise *= rainStrength * smoothstep(0.8, 1.0, float(eyeBrightnessSmooth.y) / 240.0) * 0.0035;
		coord.st = mix(coord.st + vec2(noise, -noise), coord.st, pow(abs(coord.st + vec2(noise, -noise) - vec2(0.5)) * 2.0, vec2(2.0)));
	}
	return coord;
}

float centerdist(vec2 coord) {
	return max(abs(coord.s - 0.5), abs(coord.t - 0.5)) * 2.0;
}

float distratio(vec2 pos1, vec2 pos2) {
	float xvec = pos1.x * aspectRatio - pos2.x * aspectRatio;
	float yvec = pos1.y - pos2.y;
	return length(vec2(xvec, yvec));
}

float lens(vec2 center, float size) {
	float dist = distratio(center, texcoord.st) / size;
	return exp(-dist * dist);
}

void doLenFlare(inout vec3 color) {

	vec4 sunPos = vec4(sunPosition, 1.0f) * gbufferProjection;
		 sunPos = vec4(sunPos.xyz / sunPos.w, 1.0f);
	vec2 sunP = sunPos.xy / sunPos.z;
	
	vec2 lightPos = sunP * 0.5f + 0.5f;

	float xdist = abs(lightPos.x - texcoord.x);
	float ydist = abs(lightPos.y - texcoord.y);

	float centerdist = clamp(1.0 - pow(centerdist(lightPos), 1.2), 0.0, 1.0);
	
	if (sunvisibility > 0.0) {

		vec3 lensColor = exp(-xdist * xdist / 0.05  / (1.5f - centerdist)) * 
		                 exp(-ydist * ydist / 0.003 / (1.5f - centerdist)) * vec3(0.1f, 0.3f, 1.0f);

		vec2 coord = vec2(0.5f) - lightPos;

		lensColor += vec3(1.0f, 0.3f, 0.1f) * lens(vec2(lightPos + coord * 0.7f), 0.03f * (1.5f - centerdist)) * 0.98;
		lensColor += vec3(0.8f, 0.6f, 0.1f) * lens(vec2(lightPos + coord * 0.9f), 0.06f * (1.5f - centerdist)) * 0.77;
		lensColor += vec3(0.1f, 1.0f, 0.3f) * lens(vec2(lightPos + coord * 1.3f), 0.12f * (1.5f - centerdist)) * 0.68;
		lensColor += vec3(0.1f, 0.6f, 0.8f) * lens(vec2(lightPos + coord * 2.1f), 0.24f * (1.5f - centerdist)) * 0.61;
		
		color += lensColor * pow(sunvisibility, 2.2f) * sunColor * centerdist * 0.68f * (1.0f - rainStrength);
		
	}
	
}

void doFilmColorMapping(inout vec3 color) {

    const float p = 12.0;
	color = (pow(color, vec3(p)) - color) / (pow(color, vec3(p)) - 1.0);
	color = clamp(color, vec3(0.0), vec3(1.0));
	
	float averageLuminance = 1.15f;
	float power = 0.05f;

	const float R = 1.05; 
	const float G = 1.35; 
	const float B = 1.5;

	color.rgb += normalize(vec3(R,G,B)) * averageLuminance * power;

}

void main() {
	
	#ifdef RAIN_LENS
		vec2 coord = getRainRefract(texcoord.st);
	#else
		vec2 coord = texcoord.st;
	#endif
	
    vec3 color = texture2D(gcolor, coord.st).rgb;
	
	#ifdef DOF
		doDOF(color, coord);
	#endif
	
    CalculateBloom(bloomData, coord);
    color.rgb = mix(color.rgb, bloomData.bloom, 0.02f);

    AddRainFogScatter(color, bloomData, coord);
	
    doCalculateExposure(color);
    doVignette(color);
	
	doColorProcess(color.rgb);
	doTonemapping(color.rgb);
	doFilmColorMapping(color.rgb);
	
	#ifdef LENS_FLARE
		doLenFlare(color.rgb);
	#endif
    #ifdef CAMERA_NOISE
		doAddCameraNoise(color);
    #endif
    #ifdef CINEMATIC_MODE
		doCinematicMode(color);
    #endif
	#ifdef SIZE_LOCK
		#ifndef CINEMATIC_MODE
			doSizeLock(color);
		#endif
	#endif
	
    gl_FragColor = vec4(color, 1.0f);

}
