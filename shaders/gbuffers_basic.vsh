#version 120
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

varying vec4 color;
varying vec3 normal;

void main() {
	gl_Position = ftransform();
	color       = gl_Color;
	normal      = gl_NormalMatrix * gl_Normal;
}