#version 120
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

//#define COLORFUL_HUE             //A kind of Saturation Boost.Don't suggest to open.

//#define CINEMATIC_MODE           //Lock the screen size.
//#define CAMERA_NOISE             //Add noise to screen like camera.

#define DOF                        //Fake Lens Effects
#define DOF_DistantBlur_Range 304  //Blur distance from player position (best : render distance(in block) * 2.5 - 16)
#define DOF_BlurSize 6

const float noiseStrength = 0.68;  //Strength of Noise On Camera.
const float CinematicHeight = 16;  //2.35:1 for Wide Screen,16:9 for Normal Film.
const float CinematicWidth = 9;

//Lens properties of DOF
 //"Near to human eyes (gameplay)":
 //const float focal = 0.024;
 //float aperture = 0.009;	
 //const float sizemult = 100.0;
 // ----------------------------------
 //"Tilt shift (cinematics)":
 //const float focal = 0.3;
 //float aperture = 0.3;	
 //const float sizemult = 1.0;
 // ----------------------------------
 //"Normal properties of Lens"
 const float focal = 0.05;
 float aperture = focal/7.0;	
 const float sizemult = 100.0;
 // ----------------------------------
 
uniform sampler2D gcolor;
uniform sampler2D composite;  //bloom data
uniform sampler2D noisetex;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex0;

uniform int   worldTime;
uniform int   isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;

varying vec4 texcoord;

varying float timeSunrise;
varying float timeNoon;
varying float timeSunset;
varying float timeMidnight;

uniform vec3 sunPosition;

uniform float far;
uniform float near;
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;
uniform float rainStrength;
uniform float frameTimeCounter;

float pw = 1.0/ viewWidth;
float ph = 1.0/ viewHeight;

float sky = 1.0-near/far/far;

//0:gcolor  = albedo
//2:gnormal = materials,iswater
//4:gaux1   = normals
//5:gaux2   = specular
//6:gaux3   = lightmap
//7:gaux4   = 

//60 offsets of DOF,provides better effects.
const vec2 circle_offsets[60] = vec2[60]  (  vec2( 0.0000, 0.2500 ),
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

float ld(float depth) {
	return (2.0 * near) / (far + near - depth * (far - near));
}

float GetDepthLinear(in vec2 coord) {
	return 2.0f * near * far / (far + near - (2.0f * texture2D(gdepthtex, coord).x - 1.0f) * (far - near));
}

float calcluma(vec3 color) {
	return dot(color.rgb,vec3(0.2125f, 0.7154f, 0.0721f));
}

void CalculateBloom(inout BloomDataStruct bloomData) {		//Retrieve previously calculated bloom textures

	//constants for bloom bloomSlant
	const float    bloomSlant = 0.25f;
	const float[6] bloomWeight = float[6] (pow(6.0f, bloomSlant),
										   pow(5.0f, bloomSlant),
										   pow(4.0f, bloomSlant),
										   pow(3.0f, bloomSlant),
										   pow(2.0f, bloomSlant),
										   1.0f
										   );

	bloomData.blur0 = pow(texture2D(composite,texcoord.st / pow(2.0,2.0) + vec2(0.0,0.0)).rgb ,vec3(2.2));
	bloomData.blur1 = pow(texture2D(composite,texcoord.st / pow(2.0,3.0) + vec2(0.3,0.0)).rgb ,vec3(2.2));
	bloomData.blur2 = pow(texture2D(composite,texcoord.st / pow(2.0,4.0) + vec2(0.0,0.3)).rgb ,vec3(2.2));
	bloomData.blur3 = pow(texture2D(composite,texcoord.st / pow(2.0,5.0) + vec2(0.1,0.3)).rgb ,vec3(2.2));
	bloomData.blur4 = pow(texture2D(composite,texcoord.st / pow(2.0,6.0) + vec2(0.2,0.3)).rgb ,vec3(2.2));
	bloomData.blur5 = pow(texture2D(composite,texcoord.st / pow(2.0,7.0) + vec2(0.3,0.3)).rgb ,vec3(2.2));

 	bloomData.bloom  = bloomData.blur0 * bloomWeight[5];
 	bloomData.bloom += bloomData.blur1 * bloomWeight[4];
 	bloomData.bloom += bloomData.blur2 * bloomWeight[3];
 	bloomData.bloom += bloomData.blur3 * bloomWeight[2];
 	bloomData.bloom += bloomData.blur4 * bloomWeight[1];
 	bloomData.bloom += bloomData.blur5 * bloomWeight[0];

}

void doDOF(inout vec3 color)
{
    float z = ld(texture2D(depthtex0, texcoord.st).r)*far;
    float focus = ld(texture2D(depthtex0, vec2(0.5)).r)*far;
    float blursize = DOF_BlurSize*viewWidth/1280;
    float pcoc = min((abs(aperture * (focal * (z - focus)) / (z * (focus - focal))))*sizemult,pw*blursize); 
    pcoc += pow(distance(texcoord.st, vec2(0.5)),2.5) * 0.012 + 0.0001;  //Add Edge Blur.
  
    vec4 sample = vec4(0.0);
    vec3 bcolor = vec3(0);
    float nb = 0.0;
    vec2 bcoord = vec2(0.0);
	
    if (pcoc > pw){
      for (int i = 0; i < 60; i++) {
		bcolor += pow(texture2D(gcolor, texcoord.st + circle_offsets[i]*pcoc*vec2(1.0,aspectRatio)).rgb,vec3(2.2));
      }
      color.rgb = bcolor / 60;
    }
}

void AddRainFogScatter(inout vec3 color, in BloomDataStruct bloomData)
{
	const float    bloomSlant = 0.1f;
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

	fogBlur /= fogTotalWeight * 9.28f;

	float linearDepth = GetDepthLinear(texcoord.st);
	float fogDensity = 0.066f * rainStrength;

	float visibility = 1.0f / (pow(exp(linearDepth * fogDensity), 1.0f));
	float fogFactor = 1.0f - visibility;
	      fogFactor = clamp(fogFactor, 0.0f, 1.0f);
	      fogFactor *= mix(0.0f, 1.0f, pow(eyeBrightnessSmooth.y / 240.0f, 6.0f));

	color = mix(color, fogBlur, fogFactor * 0.12f);

}

#include "/lib/Colorlib.frag"

void main() {

    vec3 color = pow(texture2D(gcolor,texcoord.st).rgb,vec3(2.2f));
	
	#ifdef DOF
     doDOF(color);
	#endif
	
    CalculateBloom(bloomData);
    color.rgb = mix(color.rgb, bloomData.bloom, 0.02f);

    AddRainFogScatter(color, bloomData);
    CalculateExposure(color);
    Vignette(color);
	
	Tonemapping(color.rgb);
	ColorProcess(color.rgb);
	LowtoneSaturate(color.rgb);
	
    #ifdef CAMERA_NOISE
     addCameraNoise(color);
    #endif
    #ifdef CINEMATIC_MODE
     doCinematicMode(color);
    #endif

    color.rgb    = clamp(color.rgb, vec3(0.0f), vec3(1.0f));
    gl_FragColor = vec4(color.rgb, 1.0f);

}
