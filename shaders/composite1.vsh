#version 120
//#define MODERN

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform mat4 gbufferModelViewInverse;

uniform int worldTime;
uniform float sunAngle;
uniform float rainStrength;

varying float ShadowDarkness;
varying float IlluminationBrightness;

varying float SdotU;
varying float MdotU;
varying float sunVisibility;
varying float moonVisibility;

varying vec3 sunVec;
varying vec3 moonVec;
varying vec3 upVec;

varying vec3 sunlight;
varying vec3 ambientColor;
varying vec3 colorTorchlight;

varying float timeSunrise;
varying float timeNoon;
varying float timeSunset;
varying float timeMidnight;
varying float timeSkyDark;

varying vec4 texcoord;
varying vec3 lightVector;
varying vec3 lightPosition;
varying vec3 worldSunPosition;
varying vec3 cloudBase1;
varying vec3 cloudBase2;
varying vec3 cloudLight1;
varying vec3 cloudLight2;
varying float extShadow;

#define SUNRISE 23200
#define SUNSET 12800
#define FADE_START 500
#define FADE_END 250

#define SUNSET_START 11500.0
#define SUNSET_MID1 12300.0
#define SUNSET_MID2 13600.0
#define SUNSET_MID3 14200.0
#define SUNSET_END 14500.0
#define SUNRISE_START 21000.0
#define SUNRISE_MID1 22000.0
#define SUNRISE_MID2 22500.0
#define SUNRISE_MID3 23500.0
#define SUNRISE_END 24000.0

const vec3 BASE1_DAY = vec3(1.0,0.95,0.9), BASE2_DAY = vec3(0.3,0.315,0.325);
const vec3 LIGHTING1_DAY = vec3(0.7,0.75,0.8), LIGHTING2_DAY = vec3(1.8, 1.6, 1.35);

const vec3 BASE1_SUNSET = vec3(0.6,0.6,0.72), BASE2_SUNSET = vec3(0.1,0.1,0.1);
const vec3 LIGHTING1_SUNSET = vec3(0.63,0.686,0.735), LIGHTING2_SUNSET = vec3(1.2, 0.84, 0.72);

const vec3 BASE1_NIGHT_NOMOON = vec3(0.27,0.27,0.324), BASE2_NIGHT_NOMOON = vec3(0.05,0.05,0.1);
const vec3 LIGHTING1_NIGHT_NOMOON = vec3(1.5,1.5,1.5), LIGHTING2_NIGHT_NOMOON = vec3(0.8,0.8,0.9);

const vec3 BASE1_NIGHT = vec3(0.075,0.075,0.09), BASE2_NIGHT = vec3(0.05,0.05,0.1);
const vec3 LIGHTING1_NIGHT = vec3(6.0,6.0,6.3), LIGHTING2_NIGHT = vec3(1.0,1.0,1.0);
							
void main() {

	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0;
	
	if(worldTime < SUNSET || worldTime > SUNRISE)
		lightPosition = normalize(sunPosition);
	else
		lightPosition = normalize(moonPosition);
		
	worldSunPosition = normalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
	
	float fTime = float(worldTime);
	if(fTime > SUNSET_START && fTime <= SUNSET_MID1)
	{
		float n = smoothstep(SUNSET_START, SUNSET_MID1, fTime);
		cloudBase1 = mix(BASE1_DAY, BASE1_SUNSET, n);
		cloudBase2 = mix(BASE2_DAY, BASE2_SUNSET, n);
		cloudLight1 = mix(LIGHTING1_DAY, LIGHTING1_SUNSET, n);
		cloudLight2 = mix(LIGHTING2_DAY, LIGHTING2_SUNSET, n);
	}
	else if(fTime > SUNSET_MID1 && fTime <= SUNSET_MID2)
	{
		cloudBase1 = BASE1_SUNSET;
		cloudBase2 = BASE2_SUNSET;
		cloudLight1 = LIGHTING1_SUNSET;
		cloudLight2 = LIGHTING2_SUNSET;
	}
	else if(fTime > SUNSET_MID2 && fTime <= SUNSET_MID3)
	{
		float n = smoothstep(SUNSET_MID2, SUNSET_MID3, fTime);
		cloudBase1 = mix(BASE1_SUNSET, BASE1_NIGHT_NOMOON, n);
		cloudBase2 = mix(BASE2_SUNSET, BASE2_NIGHT_NOMOON, n);
		cloudLight1 = mix(LIGHTING1_SUNSET, LIGHTING1_NIGHT_NOMOON, n);
		cloudLight2 = mix(LIGHTING2_SUNSET, LIGHTING2_NIGHT_NOMOON, n);
	}
	else if(fTime > SUNSET_MID3 && fTime <= SUNSET_END)
	{
		float n = smoothstep(SUNSET_MID3, SUNSET_END, fTime);
		cloudBase1 = mix(BASE1_NIGHT_NOMOON, BASE1_NIGHT, n);
		cloudBase2 = mix(BASE2_NIGHT_NOMOON, BASE2_NIGHT, n);
		cloudLight1 = mix(LIGHTING1_NIGHT_NOMOON, LIGHTING1_NIGHT, n);
		cloudLight2 = mix(LIGHTING2_NIGHT_NOMOON, LIGHTING2_NIGHT, n);
	}
	else if(fTime > SUNSET_END && fTime <= SUNRISE_START)
	{
		cloudBase1 = BASE1_NIGHT;
		cloudBase2 = BASE2_NIGHT;
		cloudLight1 = LIGHTING1_NIGHT;
		cloudLight2 = LIGHTING2_NIGHT;
	}
	else if(fTime > SUNRISE_START && fTime <= SUNRISE_MID1)
	{
		float n = smoothstep(SUNRISE_START, SUNRISE_MID1, fTime);
		cloudBase1 = mix(BASE1_NIGHT, BASE1_NIGHT_NOMOON, n);
		cloudBase2 = mix(BASE2_NIGHT, BASE2_NIGHT_NOMOON, n);
		cloudLight1 = mix(LIGHTING1_NIGHT, LIGHTING1_NIGHT_NOMOON, n);
		cloudLight2 = mix(LIGHTING2_NIGHT, LIGHTING2_NIGHT_NOMOON, n);
	}
	else if(fTime > SUNRISE_MID1 && fTime <= SUNRISE_MID2)
	{
		float n = smoothstep(SUNRISE_MID1, SUNRISE_MID2, fTime);
		cloudBase1 = mix(BASE1_NIGHT_NOMOON, BASE1_SUNSET, n);
		cloudBase2 = mix(BASE2_NIGHT_NOMOON, BASE2_SUNSET, n);
		cloudLight1 = mix(LIGHTING1_NIGHT_NOMOON, LIGHTING1_SUNSET, n);
		cloudLight2 = mix(LIGHTING2_NIGHT_NOMOON, LIGHTING2_SUNSET, n);
	}
	else if(fTime > SUNRISE_MID2 && fTime <= SUNRISE_MID3)
	{
		cloudBase1 = BASE1_SUNSET;
		cloudBase2 = BASE2_SUNSET;
		cloudLight1 = LIGHTING1_SUNSET;
		cloudLight2 = LIGHTING2_SUNSET;
	}
	else if(fTime > SUNRISE_MID3 && fTime <= SUNRISE_END)
	{
		float n = smoothstep(SUNRISE_MID3, SUNRISE_END, fTime);
		cloudBase1 = mix(BASE1_SUNSET, BASE1_DAY, n);
		cloudBase2 = mix(BASE2_SUNSET, BASE2_DAY, n);
		cloudLight1 = mix(LIGHTING1_SUNSET, LIGHTING1_DAY, n);
		cloudLight2 = mix(LIGHTING2_SUNSET, LIGHTING2_DAY, n);
	}
	else
	{
		cloudBase1 = BASE1_DAY;
		cloudBase2 = BASE2_DAY;
		cloudLight1 = LIGHTING1_DAY;
		cloudLight2 = LIGHTING2_DAY;
	}
	
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
	
	float timePow = 3.0f;
	float timefract = worldTime;
	
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
	
	const float rayleigh = 0.1f;
	
	vec3 sunrise_sun;
	 sunrise_sun.r = 1.00 * timeSunrise;
	 sunrise_sun.g = 0.56 * timeSunrise;
	 sunrise_sun.b = 0.00 * timeSunrise;
	 sunrise_sun *= 0.45f;
	
	vec3 sunrise_amb;
	 sunrise_amb.r = 0.85 * timeSunrise;
	 sunrise_amb.g = 0.40 * timeSunrise;
	 sunrise_amb.b = 0.95 * timeSunrise;	
	 sunrise_amb = mix(sunrise_amb, vec3(1.0f), 0.2f);
	 
	vec3 noon_sun;
	 noon_sun.r = mix(1.00, 1.00, rayleigh) * timeNoon;
	 noon_sun.g = mix(1.00, 0.48, rayleigh) * timeNoon;
	 noon_sun.b = mix(1.00, 0.00, rayleigh) * timeNoon;	 
	
	vec3 noon_amb;
	 noon_amb.r = 0.00 * timeNoon * 1.0;
	 noon_amb.g = 0.23 * timeNoon * 1.0;
	 noon_amb.b = 0.999 * timeNoon * 1.0;
	
	vec3 sunset_sun;
	 sunset_sun.r = 1.0 * timeSunset;
	 sunset_sun.g = 0.48 * timeSunset;
	 sunset_sun.b = 0.0 * timeSunset;
	 sunset_sun *= 0.55f;
	
	vec3 sunset_amb;
	 sunset_amb.r = 0.752 * timeSunset;
	 sunset_amb.g = 0.427 * timeSunset;
	 sunset_amb.b = 0.700 * timeSunset;
	
	vec3 midnight_sun;
	 midnight_sun.r = 0.45 * timeMidnight;
	 midnight_sun.g = 0.6 * timeMidnight;
	 midnight_sun.b = 0.8 * timeMidnight;
	 midnight_sun *= 0.07f;
	
	vec3 midnight_amb;
	 midnight_amb.r = 0.0 * timeMidnight;
	 midnight_amb.g = 0.23 * timeMidnight;
	 midnight_amb.b = 0.99 * timeMidnight;
	 midnight_amb *= 0.04f;

	sunlight.r = sunrise_sun.r + noon_sun.r + sunset_sun.r + midnight_sun.r;
	sunlight.g = sunrise_sun.g + noon_sun.g + sunset_sun.g + midnight_sun.g;
	sunlight.b = sunrise_sun.b + noon_sun.b + sunset_sun.b + midnight_sun.b;
	
	ambientColor.r = sunrise_amb.r + noon_amb.r + sunset_amb.r + midnight_amb.r;
	ambientColor.g = sunrise_amb.g + noon_amb.g + sunset_amb.g + midnight_amb.g;
	ambientColor.b = sunrise_amb.b + noon_amb.b + sunset_amb.b + midnight_amb.b;
	
	#ifndef MODERN
	float torchWhiteBalance = 0.015f;
	#else
	float torchWhiteBalance = 1.0f;
	#endif
	
	colorTorchlight = vec3(1.59f, 0.72f, 0.12f);
	colorTorchlight = mix(colorTorchlight, vec3(0.8f), vec3(torchWhiteBalance));
	colorTorchlight = pow(colorTorchlight, vec3(2.2f)) * 1.32f;
	
	ShadowDarkness = 0.6f*(1.0-rainStrength*0.50f);
	ShadowDarkness += 1.00f*(1.0-rainStrength*0.95f);
	ShadowDarkness += 1.00f*(1.0f-rainStrength*0.95f)*(timeSunrise+timeSunset);
	ShadowDarkness += 1.00f*(1.0f-rainStrength*0.95f)*timeMidnight;
	
	IlluminationBrightness = 3.25f*(1.0f-rainStrength*0.95f);
	IlluminationBrightness += 1.50f*(1.0f-rainStrength*0.95f);
	IlluminationBrightness += 2.50f*(1.0f-rainStrength*0.95f)*(timeSunrise+timeSunset);
	IlluminationBrightness += 2.00f*(1.0f-rainStrength*0.95f)*timeMidnight;
		  
}