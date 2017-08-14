#version 120
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

//sun and moon at composite texture

uniform sampler2D texture;

varying vec4 color;
varying vec4 texcoord;
varying vec3 normal;

/* DRAWBUFFERS:034 */
void main() {
	gl_FragData[0] = texture2D(texture, texcoord.st) * color;
	gl_FragData[1] = texture2D(texture, texcoord.st) * color;
	gl_FragData[2] = vec4(normal, 1.0);
}