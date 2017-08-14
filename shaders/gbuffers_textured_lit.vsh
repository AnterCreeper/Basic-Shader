#version 120
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

attribute vec4 mc_Entity;

varying vec4 color;
varying vec4 texcoord;
varying vec3 normal;
varying float entityType;

void main() {
	vec4 position 	= gl_ModelViewMatrix * gl_Vertex;
	gl_Position 	= gl_ProjectionMatrix * position;
	gl_FogFragCoord = length(position.xyz);
	color 			= gl_Color;
	texcoord 		= gl_TextureMatrix[0] * gl_MultiTexCoord0;
	normal 			= gl_NormalMatrix * gl_Normal;
	entityType 		= mc_Entity.x;
}