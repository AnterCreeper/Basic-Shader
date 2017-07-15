#version 120

varying vec4 texcoord;

uniform int worldTime;

uniform float rainStrength;
uniform float sunAngle;

varying float timeSunrise;
varying float timeNoon;
varying float timeSunset;
varying float timeMidnight;

void main() {

	gl_Position = ftransform();
	
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
	
	texcoord = gl_MultiTexCoord0;

}
