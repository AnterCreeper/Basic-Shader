#version 120
//#define MODERN

varying vec4 texcoord;

uniform int worldTime;

uniform float sunAngle;
uniform float rainStrength;
uniform int heldItemId;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;

varying float timeSunrise;
varying float timeNoon;
varying float timeSunset;
varying float timeMidnight;
varying float timeSkyDark;

varying vec3 sunlight;
varying vec3 ambientColor;
varying vec3 colorTorchlight;

varying float SdotU;
varying float MdotU;
varying float sunVisibility;
varying float moonVisibility;
varying float handItemLight;

varying vec3 lightVector;

varying vec3 sunVec;
varying vec3 moonVec;
varying vec3 upVec;

////////////////////sunlight color////////////////////
////////////////////sunlight color////////////////////
////////////////////sunlight color////////////////////
const ivec4 ToD[25] = ivec4[25](ivec4(0,200,134,48), //hour,r,g,b
								ivec4(1,200,134,48),
								ivec4(2,200,134,48),
								ivec4(3,200,134,48),
								ivec4(4,200,134,48),
								ivec4(5,200,134,48),
								ivec4(6,200,134,90),
								ivec4(7,200,180,110),
								ivec4(8,200,186,132),
								ivec4(9,200,195,145),
								ivec4(10,200,199,160),
								ivec4(11,200,200,175),
								ivec4(12,200,200,185),
								ivec4(13,200,200,175),
								ivec4(14,200,199,160),
								ivec4(15,200,195,145),
								ivec4(16,200,186,132),
								ivec4(17,200,180,110),
								ivec4(18,200,153,90),
								ivec4(19,200,134,48),
								ivec4(20,200,134,48),
								ivec4(21,200,134,48),
								ivec4(22,200,134,48),
								ivec4(23,200,134,48),
								ivec4(24,200,134,48));
								
void main() {

	handItemLight = 0.0;
	if (heldItemId == 50) {
		// torch
		handItemLight = 0.5;
	} else if (heldItemId == 76 || heldItemId == 94) {
		// active redstone torch / redstone repeater
		handItemLight = 0.1;
	} else if (heldItemId == 89) {
		// lightstone
		handItemLight = 0.6;
	} else if (heldItemId == 10 || heldItemId == 11 || heldItemId == 51) {
		// lava / lava / fire
		handItemLight = 0.5;
	} else if (heldItemId == 91) {
		// jack-o-lantern
		handItemLight = 0.6;
	} else if (heldItemId == 327) {
		handItemLight = 0.2;
	}
	
	gl_Position = ftransform();
	
	float timePow = 3.0f;
	float timefract = worldTime;
	
	if (sunAngle < 0.5f) {
		lightVector = normalize(sunPosition);
	} else {
		lightVector = normalize(moonPosition);
	}
	
	sunVec = normalize(sunPosition);
	moonVec = normalize(-sunPosition);
	upVec = normalize(upPosition);
	
	SdotU = dot(sunVec,upVec);
	MdotU = dot(moonVec,upVec);
	sunVisibility = pow(clamp(SdotU+0.1,0.0,0.1)/0.1,2.0);
	moonVisibility = pow(clamp(MdotU+0.1,0.0,0.1)/0.1,2.0);
	
	float hour = mod(worldTime/1000.0+6.0,24);
	
	ivec4 temp = ToD[int(floor(hour))];
	ivec4 temp2 = ToD[int(floor(hour)) + 1];
	
	sunlight = mix(vec3(temp.yzw),vec3(temp2.yzw),(hour-float(temp.x))/float(temp2.x-temp.x))/255.0f;
	
	timeSunrise  = ((clamp(sunAngle, 0.95, 1.0f)  - 0.95f) / 0.05f) + (1.0 - (clamp(sunAngle, 0.0, 0.25) / 0.25f));  
	timeNoon     = ((clamp(sunAngle, 0.0, 0.25f)) 	       / 0.25f) - (	 (clamp(sunAngle, 0.25f, 0.5f) - 0.25f) / 0.25f);
	timeSunset   = ((clamp(sunAngle, 0.25f, 0.5f) - 0.25f) / 0.25f) - (	 (clamp(sunAngle, 0.5f, 0.52) - 0.5f) / 0.02f);  
	timeMidnight = ((clamp(sunAngle, 0.5f, 0.52f) - 0.5f)  / 0.02f) - (      (clamp(sunAngle, 0.95, 1.0) - 0.95f) / 0.05f);
	
	timeSunrise  = pow(timeSunrise, timePow);
	timeNoon     = pow(timeNoon, 1.0f/timePow);
	timeSunset   = pow(timeSunset, timePow);
	timeMidnight = pow(timeMidnight, 1.0f/timePow);
	
	timeSkyDark = ((clamp(timefract, 12000.0, 16000.0) - 12000.0) / 4000.0) - ((clamp(timefract, 22000.0, 24000.0) - 22000.0) / 2000.0);
	timeSkyDark = pow(timeSkyDark, 3.0f);
	
	vec3 skycolor_sunrise = vec3(0.5, 0.7, 1.0) * 0.2 * (1.0 - rainStrength) * timeSunrise;
	vec3 skycolor_noon = vec3(0.16, 0.38, 1.0) * 0.4 * (1.0 - rainStrength) * timeNoon;
	vec3 skycolor_sunset = vec3(0.5, 0.7, 1.0) * 0.2 * (1.0 - rainStrength) * timeSunset;
	vec3 skycolor_night = vec3(0.0, 0.0, 0.0) * timeMidnight;
	vec3 skycolor_rain_day = vec3(1.2, 1.6, 2.0) * 0.1 * (timeSunrise + timeNoon + timeSunset) * rainStrength;
	vec3 skycolor_rain_night = vec3(0.0, 0.0, 0.0) * timeMidnight * rainStrength;
	ambientColor = skycolor_sunrise + skycolor_noon + skycolor_sunset + skycolor_night + skycolor_rain_day + skycolor_rain_night;
	
	vec3 moonlight = vec3(0.3, 0.55, 1.0) * 0.35;
	sunlight = mix(sunlight, moonlight, timeMidnight);
	
	float timeSunriseSunset = 1.0 - timeNoon;
		  timeSunriseSunset *= 1.0 - timeMidnight;
	
	vec3 colorSunglow_sunrise;
	 colorSunglow_sunrise.r = 1.00f * timeSunriseSunset;
	 colorSunglow_sunrise.g = 0.46f * timeSunriseSunset;
	 colorSunglow_sunrise.b = 0.00f * timeSunriseSunset;
	 
	vec3 colorSunglow_noon;
	 colorSunglow_noon.r = 1.0f * timeNoon;
	 colorSunglow_noon.g = 1.0f * timeNoon;
	 colorSunglow_noon.b = 1.0f * timeNoon;
	 
	vec3 colorSunglow_midnight;
	 colorSunglow_midnight.r = 0.05f * 0.8f * 0.0055f * timeMidnight;
	 colorSunglow_midnight.g = 0.20f * 0.8f * 0.0055f * timeMidnight;
	 colorSunglow_midnight.b = 0.90f * 0.8f * 0.0055f * timeMidnight;
	
	vec3 colorSunglow = colorSunglow_sunrise + colorSunglow_noon + colorSunglow_midnight;
	sunlight = mix(sunlight,colorSunglow,timeSunriseSunset);
	
	#ifndef MODERN
	float torchWhiteBalance = 0.015f;
	#else
	float torchWhiteBalance = 1.0f;
	#endif
	
	colorTorchlight = vec3(1.59f, 0.72f, 0.12f);
	colorTorchlight = mix(colorTorchlight, vec3(0.8f), vec3(torchWhiteBalance));
	colorTorchlight = pow(colorTorchlight, vec3(2.2f)) * 1.32f;
	
	texcoord = gl_MultiTexCoord0;

}
