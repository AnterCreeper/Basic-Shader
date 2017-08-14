#version 120
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

varying vec4 color;
varying vec3 normal;

/* DRAWBUFFERS:04 */
void main() {
	gl_FragData[0] = color;
	gl_FragData[1] = vec4(normal, 1.0);
}