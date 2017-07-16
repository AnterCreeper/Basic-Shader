#version 120

uniform sampler2D gcolor;
uniform sampler2D composite;
uniform sampler2D noisetex;
uniform sampler2D gdepthtex;

varying vec4 texcoord;

varying float timeSunrise;
varying float timeNoon;
varying float timeSunset;
varying float timeMidnight;

uniform int worldTime;

uniform float far;
uniform float near;
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;
uniform float rainStrength;
uniform float frameTimeCounter;

uniform int   isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;

const float noiseStrength = 0.62;   //Strength of Noise On Camera.
const float CinematicHeight = 16;   //2.35:1 for Wide Screen,16:9 for Normal Film.
const float CinematicWidth = 9;

void Vignette(inout vec3 color) {

	float dist = distance(texcoord.st, vec2(0.5f)) * 2.0f;
	      dist /= 1.5142f;
	      dist = pow(dist, 1.1f);

	color.rgb *= 1.0f - dist * 0.5f;

}

vec3 Tonemapping(vec3 color) {

	const float a = 2.51f;
	const float b = 0.03f;
	const float c = 2.43f;
	const float d = 0.59f;
	const float e = 0.14f;
	color = (color*(a*color+b))/(color*(c*color+d)+e);
	color = clamp(color, vec3(0.0), vec3(1.0));
        return color;

}

void CalculateExposure(inout vec3 color) {

	float exposureMax = 1.25f;
	      exposureMax *= mix(1.0f, 0.0f, timeMidnight);
	float exposureMin = 0.45f;
	float exposure = pow((eyeBrightnessSmooth.y / 240.0f + 0.2f) / 1.2f, 5.0f) * exposureMax + exposureMin;

	color.rgb /= vec3(exposure * 0.7f);

}

void LowtoneSaturate(inout vec3 color)
{
	color.rgb *= 1.125f;
	color.rgb -= 0.125f;
	color.rgb = clamp(color.rgb, vec3(0.0f), vec3(1.0f));
}

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

 	bloomData.bloom  = bloomData.blur0 * bloomWeight[0];
 	bloomData.bloom += bloomData.blur1 * bloomWeight[1];
 	bloomData.bloom += bloomData.blur2 * bloomWeight[2];
 	bloomData.bloom += bloomData.blur3 * bloomWeight[3];
 	bloomData.bloom += bloomData.blur4 * bloomWeight[4];
 	bloomData.bloom += bloomData.blur5 * bloomWeight[5];

        bloomData.bloom = bloomData.bloom * pow(length(bloomData.bloom),0.4);

}

float GetDepthLinear(in vec2 coord) {

	return 2.0f * near * far / (far + near - (2.0f * texture2D(gdepthtex, coord).x - 1.0f) * (far - near));
}

void  ColorProcess(inout vec3 color) {

	float gamma		= 1.07;
	float exposure		= 1.24;
        float saturation        = 1.06;
	float darkness		= 0.03;
	float brightness	= 0.03;

	color = pow(color, vec3(gamma));
	color *= exposure;
	color = max(color - darkness, 0.0);
	color = color + brightness;

	float luma = dot(color.rgb, vec3(0.2125f, 0.7154f, 0.0721f));
	vec3 chroma = color - luma;
	color = (chroma * saturation) + luma;

}

void CalculateFilmColorMapping(inout vec3 color){

        const float p = 13.0;
	color = (pow(color, vec3(p)) - color) / (pow(color, vec3(p)) - 1.0);
	color = clamp(color, vec3(0.0), vec3(1.0));
	
	float averageLuminance = 1.15f;
	float power = 0.125f;

	const float R = 1.05; 
	const float B = 1.35; 
	const float G = 1.5; 
	vec3 FilmColor = vec3(R,B,G);

	color.rgb += normalize(FilmColor) * averageLuminance * power;

}

float vec3ToFloat(vec3 vec3Input) {

	float floatValue  = 0.0;
	      floatValue += vec3Input.x;
	      floatValue += vec3Input.y;
	      floatValue += vec3Input.z;

	      floatValue /= 3.0;

	return floatValue;

}

void addCameraNoise(inout vec3 color) {
	
        vec2 aspectcorrect = vec2(aspectRatio, 1.0);
        vec3 rgbNoise = texture2D(noisetex, texcoord.st * max(viewHeight,viewWidth) * aspectcorrect + vec2(frameTimeCounter)).rgb;
        color = mix(color, rgbNoise, vec3ToFloat(rgbNoise) * noiseStrength / (color.r + color.g + color.b + 0.3) / 18);

}

void doCinematicMode(inout vec3 color) {

  float heightst = viewWidth / CinematicHeight * CinematicWidth ;
	
  if (viewHeight > heightst){
	float ast = (viewHeight - heightst) / viewHeight / 2;
	float ss = 1 - ast;
    if (texcoord.t > ss || texcoord.t < ast) color = vec3(0.0);
  }
	  
  if (viewHeight < heightst){
	float widthst = viewHeight / CinematicWidth * CinematicHeight;
	float bst = (viewWidth - widthst) / viewWidth / 2;
	float tt = 1 - bst;
    if (texcoord.s > tt || texcoord.s < bst) color = vec3(0.0);
  }
  
}

vec3    Contrast(in vec3 color, in float contrast)
{
	float colorLength = length(color);
	vec3 nColor = color / colorLength;

	colorLength = pow(colorLength, contrast);

	return nColor * colorLength;
}

void 	AddRainFogScatter(inout vec3 color, in BloomDataStruct bloomData)
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

void main() {

	vec3 color = pow(texture2D(gcolor,texcoord.st).rgb,vec3(2.2f));

	CalculateBloom(bloomData);
        color.rgb = mix(color,bloomData.bloom,0.006);

	AddRainFogScatter(color, bloomData);
	CalculateExposure(color);
	Vignette(color);

        Tonemapping(color);
        color = pow(color,vec3(1.0f / (1.0f + 1.2f)));
        ColorProcess(color);
        Contrast(color,1.14f);

        CalculateFilmColorMapping(color);
        LowtoneSaturate(color);

        addCameraNoise(color);
        //doCinematicMode(color);

 	gl_FragColor = vec4(color.rgb, 1.0f);

}
