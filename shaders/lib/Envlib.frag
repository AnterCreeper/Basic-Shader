//Environment Lib Version v2.8

//This file is part of Basic Shader.
//Read LICENSE First at composite.fsh

const float pi = 3.1415926535897932834919;

vec3 doTone(vec3 color, vec3 sunPos, float W) {

    float sunfade = 1.0 - clamp(1.0 - exp(-(sunPos.z / 500.0)), 0.0, 1.0);
	
    color = pow(color * 7.241657387 / W, vec3(2.2f));
    color = pow(color, vec3(1.0 / (1.2 + 1.2 * sunfade)));
	
    return color;
	
}

//Atmospheric.
float SunIntensity(float zenithAngleCos, float sunIntensity, float cutoffAngle, float steepness) {
	return sunIntensity * max(0.0, 1.0 - exp(-((cutoffAngle - acos(zenithAngleCos)) / steepness)));
}

float RayleighPhase(float cosViewSunAngle) {
	return (3.0 / (16.0 * pi)) * (1.0 + pow(max(cosViewSunAngle, 0.0), 2.0));
}

float MiePhase(float cosViewSunAngle, float g) {
	return (1.0 / (4.0 * pi)) * ((1.0 - pow(g, 2.0)) / pow(1.0 + pow(g, 2.0) - 2.0 * g * cosViewSunAngle, 1.5));
}

vec3 totalRayleigh(vec3 lambda, float n, float N, float pn){
	return (24.0 * pow(pi, 3.0) * pow(pow(n, 2.0) - 1.0, 2.0) * (6.0 + 3.0 * pn))
	/ (N * pow(lambda, vec3(4.0)) * pow(pow(n, 2.0) + 2.0, 2.0) * (6.0 - 7.0 * pn));
}

vec3 totalMie(vec3 lambda, vec3 K, float T, float v) {
	float c = (0.2 * T) * 10E-18;
	return 0.434 * c * pi * pow((2.0 * pi) / lambda, vec3(v - 2.0)) * K;
}

float getSun(vec3 fragpos, float sunStrength) {

	float weatherRatio = 1.0 - ambient_noise();
	
	float position	 = dot(normalize(fragpos.xyz + vec3(0.0, 15.0, 0.0)), upPosition);
	float horizonPos = mix(pow(clamp(1.0 - pow(abs(position) * 0.05, 1.5), 0.0, 1.0), 5.0), 1.0, 1.0 - clamp(position + length(position), 0.0, 1.0));

	float sunVector  = max(dot(normalize(fragpos), normalize(sunPosition)), 0.0);
	float sun = smoothstep(0.99, 1.0, pow(sunVector, 5.0)) * sunStrength * (3.0 - (timeSunrise + timeSunset));
	      sun = mix(sun, 0.0, horizonPos) * weatherRatio * (1.0f - rainStrength);
	
	return sun;

}

vec3 getAtmospheric(vec3 fragpos, vec3 fogColor, float hasSun){

	//Wavelength of the primary colors RGB in nanometers.
	const vec3 primaryWavelengths = vec3(700, 546.1, 435.8) * 1.0E-9;
	
	//Physics constants
	float n  = 1.000278;    //Refractive index of air
	float pn = 0.03;	    //Depolarization factor for standard air
	
	float Na = 6.022141E23; //Avogadro constant
	float R  = 8.314472;    //Gas constant
	float T  = 273.15;      //Thermodynamic temperature of 0 celsius
	
	//Environment variables
	float Tm = -45;         //Suppose that the average temperature is -45 celsius
	float AP = 101325;      //The standard air pressure
	
	//Number of molecules per unit volume for air
	float N  = AP * Na / (Tm + T) / R;

	//Optical length at zenith for molecules
	float rayleighZenithLength 		= 8.50E3;
	float mieZenithLength      		= 2.25E3;
	
	//Properties of scattering
	const float mie                 = 0.80;
	const float turbidity 			= 0.20;
	const float sunIntensity 		= 1000;
	
	const float rayleighCoefficient = 0.80;
	const float mieCoefficient		= 0.15;

	//Earth shadow hack
	float steepness   = 1.50;
	float brightness  = 0.18;
	float curvefactor = 12.0;
	float cutoffAngle = pi * 0.5128205128205128;

	//Cos Angles
	float cosViewSunAngle = dot(normalize(fragpos.xyz), sunVec);
	float cosSunUpAngle   = dot(sunVec, upVec) * 0.9 + 0.1;
	float cosUpViewAngle  = dot(upVec, normalize(fragpos.xyz));

	float sunE = SunIntensity(cosSunUpAngle, sunIntensity, cutoffAngle, steepness);

	float zenithAngle = max(0.0, cosUpViewAngle);
	float rayleighOpticalLength = rayleighZenithLength / zenithAngle;
	float mieOpticalLength 		= mieZenithLength 	   / zenithAngle;

	//Calculate scattering
	vec3 rayleighAtX = totalRayleigh(primaryWavelengths, n, N, pn) * rayleighCoefficient;
	vec3 mieAtX 	 = totalMie(primaryWavelengths, pow(sunColor, vec3(2.2f)), turbidity, 4.0) * mieCoefficient;

	vec3 rayleighXtoEye = rayleighAtX * RayleighPhase(cosViewSunAngle);
	vec3 mieXtoEye 		= mieAtX 	  * MiePhase(cosViewSunAngle, mie);

	vec3 Fex = exp(-(rayleighAtX * rayleighOpticalLength + mieAtX * mieOpticalLength));
	
	float NightLightScattering = pow(max(1.0 - max(cosUpViewAngle, 0.0), 0.0), 2.0);
		
	//Add up all scattering
	vec3 scattering  = sunE * (1.0 - Fex) * (rayleighXtoEye + mieXtoEye) / (rayleighAtX + mieAtX);
	     scattering *= mix(vec3(1.0), pow(scattering * Fex, vec3(0.5)), clamp(pow(1.0 - cosSunUpAngle, 5.0), 0.0, 1.0));

	vec3 sky  = max(mix(doTone(scattering, sunVec, pow(sunE / sunIntensity, 1.0 / curvefactor) * sunIntensity * brightness), fogColor, rainStrength), vec3(0.0f));
	
	float amount = 0.05f + 0.2f * timeSkyDark;
	float colorDesat = dot(sky, vec3(1.0f)) + 0.10 * timeMidnight;
	
	sky  = mix(sky, vec3(colorDesat) * vec3(0.2f, 0.4f, 1.0f), timeMidnight * amount);
	sky += pow(fogColor, vec3(2.2f)) * ((NightLightScattering + 0.5 * (1.0 - NightLightScattering)) * clamp(pow(1.0 - cosSunUpAngle, 35.0), 0.0, 1.0));
	sky += pow(sunColor, vec3(2.2f)) * getSun(fragpos.xyz, 2E3 * (1.0f - rainStrength)) * hasSun;
	
	float dist = length(fragpos);
	float power = 0.005;
	
	sky *= mix(vec3(1.0f), exp(-dist * ambientColor * power), pow(timeSunriseSunset + timeMidnight - timeSkyDark, 0.5f)) * 1.2f;
	
	return sky;

}

vec4 getClouds(vec3 fragpos, vec3 fogColor) {

	#ifndef NO_CLOUDS
	
	//Environment variable.
	float cloudSpeed   = 0.02;
	float cloudCover   = 0.50;
	float cloudOpacity = 0.75;
	
	float sunStrength  = 4.5;
	float moonStrength = 1.2;
	float shadingStrength = 0.2;
	
	float weatherRatio = clamp(sqrt(ambient_noise()), 0.5f, 1.0f);
	
	//Get position.
	vec4 worldPos  = gbufferModelViewInverse * vec4(fragpos, 1.0);
	vec4 worldPos2 = gbufferModelViewInverse * vec4(fragpos + lightVector * 20.0, 1.0);

	float position = dot(normalize(fragpos.xyz), upPosition);
	float horizonPos = max(1.0 - abs(position) * 0.03, 0.0);

	float horizonBorder = min((1.0 - clamp(position + length(position), 0.0, 1.0)) + horizonPos, 1.0);

	float sunVector  = max(dot(normalize(fragpos), normalize(sunPosition)),  0.0);
	float moonVector = max(dot(normalize(fragpos), normalize(moonPosition)), 0.0);

	float curvedPos = pow(position, 0.5);

	//Calculate light vectors.
	float sun  = pow(sunVector,   5.0);
	float moon = pow(moonVector, 10.0);

	vec2 wind = vec2(frameTimeCounter * 0.0008) * cloudSpeed;

	mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.5));

	vec2 coord  = ((worldPos.xz / worldPos.y)   * curvedPos * 0.00025) * rot + wind * 2.0;
	vec2 coord2 = ((worldPos2.xz / worldPos2.y) * curvedPos * 0.00025) * rot + wind * 2.0;

	float noise   = noise_tex(coord - wind);
		  noise  += noise_tex(coord * 4.0 - wind)   / 4.0;
	      noise  += noise_tex(coord * 12.0 - wind)  / 12.0;
		  noise  += noise_tex(coord * 34.0 - wind)  / 34.0;

	float noise2  = noise_tex(coord2 - wind);
		  noise2 += noise_tex(coord2 * 4.0 - wind)  / 4.0;
		  noise2 += noise_tex(coord2 * 12.0 - wind) / 12.0;

	cloudCover /= mix(1.0, 0.6, pow(weatherRatio, 1.2f));
    cloudCover /= mix(1.0, 1.5, horizonBorder);
	cloudCover /= mix(1.0, 4.0, pow(wetness, 0.5));

	float cloud        = max(noise  - cloudCover * 1.25, 0.0);
	float cloudShading = max(noise2 - cloudCover * 0.8,  0.0);

	//Apply conditions.
	sunStrength  	*= mix(1.0, 0.08, timeMidnight);
	moonStrength 	*= mix(1.0, 0.25, 1.0f - timeMidnight);

	cloudOpacity = mix(cloudOpacity, cloudOpacity * 2.5, cloudCover);

	vec3 cloudClr = vec3(0.015f * moonStrength + 0.25f * sunStrength * (1.2f - timeSunrise - timeSunset) / (1.0f + timeNoon * 0.2f));
		 cloudClr = mix(cloudClr, vec3(length(cloudClr) * 0.5), timeNoon);
		 
	cloudClr *= mix(0.75, 1.0, timeFading);
	cloud    *= mix(0.5,  1.0, timeFading);
    
	cloudClr = mix(cloudClr, fogColor * 0.6, cloudShading * shadingStrength * timeFading * cloudOpacity);

	return vec4(pow(max(cloudClr, vec3(0.0f)), vec3(2.2f)), min(cloud * cloudOpacity, 1.0) * (1.0 - horizonBorder));
	
	#else 
	
	return vec4(0.0f);
	
	#endif
	
}