#version 120
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

//Switch of effects
//#define MODERN

//Please read the license before change things below this line !!

varying vec4 texcoord;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;

uniform float sunAngle;
uniform float rainStrength;
uniform float viewWidth;
uniform float viewHeight;

uniform int heldItemId;
uniform int worldTime;

varying vec3 sunVec;
varying vec3 moonVec;
varying vec3 upVec;

varying vec3 lightVector;

varying float SdotU;
varying float MdotU;
varying float handItemLight;
varying float sunVisibility;
varying float moonVisibility;

#include "/lib/Global.vert"

varying vec3 rayColor;

void main() {

	doCalculateTime();
	doCalculateColor();
	
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
	
	if (sunAngle < 0.5f) {
		lightVector = normalize(sunPosition);
	} else {
		lightVector = normalize(moonPosition);
	}
	
	sunVec  = normalize(sunPosition);
	moonVec = normalize(-sunPosition);
	upVec   = normalize(upPosition);
	
	SdotU = dot(sunVec,upVec);
	MdotU = dot(moonVec,upVec);
	sunVisibility  = pow(clamp(SdotU + 0.1, 0.0, 0.1) / 0.1, 2.0);
	moonVisibility = pow(clamp(MdotU + 0.1, 0.0, 0.1) / 0.1, 2.0);

	texcoord = gl_MultiTexCoord0;

	rayColor += vec3(0.9,  0.8, 0.5) * 0.8 	* timeSunrise;
	rayColor += vec3(1.0,  1.0, 1.0) * 1.0	* timeNoon;
	rayColor += vec3(1.0,  0.7, 0.3) * 0.8	* timeSunset;
	rayColor += vec3(0.65, 0.8, 1.2) * 0.25 * timeMidnight;
	
	rayColor  = pow(rayColor, vec3(2.0f));

}
