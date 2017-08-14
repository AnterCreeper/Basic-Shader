#version 120
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec3 normal;
varying vec3 fragpos;

uniform vec3 cameraPosition;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform float frameTimeCounter;

attribute vec4 mc_midTexCoord;

void main() {

	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	vec3 worldpos = position.xyz + cameraPosition;
	
	bool istopv  = worldpos.y > cameraPosition.y+5.0;
	if (!istopv) position.xz += vec2(2.3,1.0)+sin(frameTimeCounter)*sin(frameTimeCounter)*sin(frameTimeCounter)*vec2(2.1,0.6);
	position.xz -= (vec2(3.0,1.0)+sin(frameTimeCounter)*sin(frameTimeCounter)*sin(frameTimeCounter)*vec2(2.1,0.6))*0.25;
	gl_Position  = gl_ProjectionMatrix * gbufferModelView * position;
	
	color 	 = gl_Color;
	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	lmcoord  = gl_TextureMatrix[1] * gl_MultiTexCoord1;
	normal   = normalize(gl_NormalMatrix * gl_Normal);

}