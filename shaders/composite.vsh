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

varying vec4 offset[3];

#include "/lib/Global.vert"

#define lerp(a, b, t) mix(a, b, t)
#define saturate(a) clamp(a, 0.0, 1.0)
#define mad(a, b, c) (a * b + c)

vec4 SMAA_RT_METRICS = vec4(1.0 / viewWidth, 1.0 / viewHeight, viewWidth, viewHeight);

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
	
	SdotU = dot(sunVec, upVec);
	MdotU = dot(moonVec,upVec);
	sunVisibility  = pow(clamp(SdotU + 0.1, 0.0, 0.1) / 0.1, 2.0);
	moonVisibility = pow(clamp(MdotU + 0.1, 0.0, 0.1) / 0.1, 2.0);

	texcoord = gl_MultiTexCoord0;

	offset[0] = mad(SMAA_RT_METRICS.xyxy, vec4(-1.0, 0.0, 0.0, -1.0), texcoord.xyxy);
	offset[1] = mad(SMAA_RT_METRICS.xyxy, vec4( 1.0, 0.0, 0.0,  1.0), texcoord.xyxy);
	offset[2] = mad(SMAA_RT_METRICS.xyxy, vec4(-2.0, 0.0, 0.0, -2.0), texcoord.xyxy);
	
}
