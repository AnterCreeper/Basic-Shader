#version 120
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;

attribute vec4 mc_Entity;

varying vec3 normal;

void main() {

	texcoord 		= gl_MultiTexCoord0;
	lmcoord 		= gl_TextureMatrix[1] * gl_MultiTexCoord1;
	gl_Position 	= ftransform();
	color 			= gl_Color;
	gl_FogFragCoord = gl_Position.z;
	normal 			= normalize(gl_NormalMatrix * gl_Normal);

}
