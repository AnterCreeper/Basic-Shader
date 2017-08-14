#version 120
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

varying vec4 color;
varying vec4 texcoord;
varying vec3 normal;

void main() {
	gl_Position = ftransform();
	color 		= gl_Color;
	texcoord 	= gl_TextureMatrix[0] * gl_MultiTexCoord0;
	normal 		= gl_NormalMatrix * gl_Normal;
}