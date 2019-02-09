#version 120
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

uniform sampler2D texture;

varying vec4 color;
varying vec4 texcoord;
varying vec3 normal;

/* DRAWBUFFERS:0 */
void main() {
	gl_FragData[0] = texture2D(texture, texcoord.st) * color;
}