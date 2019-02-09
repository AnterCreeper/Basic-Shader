#version 120
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

#define WAVING_WATER

attribute vec4 mc_Entity;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform vec3 cameraPosition;

uniform float frameTimeCounter;

uniform int worldTime;
uniform int isEyeInWater;

varying vec4 color;

varying vec3 normal;
varying vec3 tangent;
varying vec3 binormal;
varying vec3 worldpos;
varying vec3 viewVector;

varying vec2 lmcoord;
varying vec2 texcoord;

varying float iswater;
varying float materialIDs;
varying float distance;

const float pi = 3.1415926535897932834919;

void main() {

	iswater 	= 0.0f;
	materialIDs = mc_Entity.x;
	
	float displacement = 0.0;
	vec4 position = gl_ModelViewMatrix * gl_Vertex;
	vec4 viewpos  = gbufferModelViewInverse * position;
	     worldpos = viewpos.xyz + cameraPosition;

	distance = length(position.xyz);

	if(mc_Entity.x == 2.0 || mc_Entity.x == 9.0) {
	
		iswater = 1.0;
		float fy = fract(worldpos.y + 0.1);
		
	    #ifdef WAVING_WATER
		 float wave = 0.05 * sin(2 * pi * (frameTimeCounter * 0.75 + worldpos.x /  7.0 + worldpos.z / 13.0))
				    + 0.05 * sin(2 * pi * (frameTimeCounter * 0.6  + worldpos.x / 11.0 + worldpos.z /  5.0));
		 displacement = clamp(wave, -fy, 1.0 - fy);
		 viewpos.y += displacement * 0.5;
	    #endif
		
	}
	
	viewpos 	= gbufferModelView * viewpos;
	gl_Position = gl_ProjectionMatrix * viewpos;
	color 		= gl_Color;
	texcoord 	= (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
	lmcoord 	= (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;
	
	gl_FogFragCoord = gl_Position.z;
	
	normal   = normalize(gl_NormalMatrix * gl_Normal);

	if (gl_Normal.x > 0.5) {
		//  1.0,  0.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0, -1.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	}
	
	else if (gl_Normal.x < -0.5) {
		// -1.0,  0.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	}
	
	else if (gl_Normal.y > 0.5) {
		//  0.0,  1.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
	}
	
	else if (gl_Normal.y < -0.5) {
		//  0.0, -1.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
	}
	
	else if (gl_Normal.z > 0.5) {
		//  0.0,  0.0,  1.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	}
	
	else if (gl_Normal.z < -0.5) {
		//  0.0,  0.0, -1.0
		tangent  = normalize(gl_NormalMatrix * vec3(-1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	}
	
	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
                          tangent.y, binormal.y, normal.y,
                          tangent.z, binormal.z, normal.z);
	
	viewVector = (gl_ModelViewMatrix * gl_Vertex).xyz;
	viewVector = normalize(tbnMatrix * viewVector);

}