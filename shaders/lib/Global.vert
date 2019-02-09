varying vec3 sunColor;
varying vec3 moonColor;
varying vec3 ambientColor;
varying vec3 torchColor;
varying vec3 glowColor;

varying float timeSunrise;
varying float timeNoon;
varying float timeSunset;
varying float timeMidnight;
varying float timeSunriseSunset;

varying float timeSkyDark;
varying float timeFading;

float timePow   = 3.0f;
float timefract = worldTime;

float Luminance(vec3 color) {
	return dot(color.rgb, vec3(0.2125f, 0.7154f, 0.0721f));
}

void doCalculateTime() {

	timeSunrise  = (clamp(sunAngle, 0.95, 1.0f)  - 0.95f) / 0.05f + 1.0 - clamp(sunAngle, 0.0, 0.25)       / 0.25f;  
	timeNoon     =  clamp(sunAngle, 0.0, 0.25f)  	      / 0.25f - (clamp(sunAngle, 0.25f, 0.5f) - 0.25f) / 0.25f;
	timeSunset   = (clamp(sunAngle, 0.25f, 0.5f) - 0.25f) / 0.25f - (clamp(sunAngle, 0.5f, 0.52)  - 0.5f)  / 0.02f;  
	timeMidnight = (clamp(sunAngle, 0.5f, 0.52f) - 0.5f)  / 0.02f - (clamp(sunAngle, 0.95, 1.0)   - 0.95f) / 0.05f;
	
	timeSunrise  = pow(timeSunrise,  timePow       );
	timeNoon     = pow(timeNoon,     1.0f / timePow);
	timeSunset   = pow(timeSunset,   timePow       );
	timeMidnight = pow(timeMidnight, 1.0f / timePow);

	timeSunriseSunset = (1.0 - timeNoon) * (1.0 - timeMidnight);

	timeSkyDark = ((clamp(timefract, 12000.0, 16000.0) - 12000.0) / 4000.0) - ((clamp(timefract, 22000.0, 24000.0) - 22000.0) / 2000.0);
	timeSkyDark = pow(timeSkyDark, 3.0f);
	
	timeFading	= 1.0 - (clamp((timefract - 12000.0) / 750.0, 0.0, 1.0) - clamp((timefract - 12750.0) / 750.0, 0.0, 1.0)
										  +  clamp((timefract - 22000.0) / 750.0, 0.0, 1.0) - clamp((timefract - 23250.0) / 750.0, 0.0, 1.0));

}

void doCalculateColor(){

	sunColor = vec3(1.00f, 0.40f, 0.00f) * 0.35f * timeSunrise + vec3(1.0f, 1.0f, 1.0f) * timeNoon 
	             + vec3(1.10f, 0.28f, 0.00f) * 0.55f * timeSunset + vec3(0.45f, 0.60f, 0.80f) * 0.1f * 0.0025f * timeMidnight;
	
	sunColor = pow(sunColor, vec3(2.2f));
		
	moonColor = vec3(0.3, 0.55, 1.45) * 0.08;
	moonColor = mix(moonColor, vec3(Luminance(moonColor)), 0.2 * timeMidnight);
	

	vec3 rain = vec3(0.17, 0.18, 0.2) * (timeSunrise + timeNoon + timeSunset);
	
	ambientColor = vec3(0.50f, 0.70f, 1.00f) * timeSunrise + vec3(0.16f, 0.38f, 1.0f) * 0.4f * timeNoon 
	                 + vec3(0.50f, 0.70f, 1.00f) * 0.2f * timeSunset + moonColor * 0.065f * timeMidnight;
	
	ambientColor = mix(ambientColor, rain, rainStrength);
				 
	#ifndef MODERN
	float torchWhiteBalance = 0.015f;
	#else
	float torchWhiteBalance = 1.0f;
	#endif
	
	torchColor = pow(vec3(1.80f, 0.85f, 0.12f), vec3(2.2f));
	torchColor = mix(torchColor, vec3(1.5f), torchWhiteBalance);
	
	glowColor = vec3(1.00f, 0.46f, 0.00f) * timeSunrise + vec3(1.0f, 1.0f, 1.0f) * timeNoon 
	              + vec3(1.00f, 0.38f, 0.00f) * timeSunset + vec3(0.05f, 0.20f, 0.90f) * 0.8f * 0.0055f * timeMidnight;
				  
}