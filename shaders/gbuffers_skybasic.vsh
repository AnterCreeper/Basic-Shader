#version 120
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

varying vec4 color;
varying vec3 normal;

void main() {
	vec4 position 	= gl_ModelViewMatrix * gl_Vertex;
	gl_Position 	= gl_ProjectionMatrix * position;
	gl_FogFragCoord = length(position.xyz);
	color 			= gl_Color;
	normal 			= gl_NormalMatrix * gl_Normal;
}