#version 120
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

uniform sampler2D texture;

varying vec4 color;
varying vec4 texcoord;
varying vec3 normal;

void main() {
/* DRAWBUFFERS:045 */
	gl_FragData[0] = texture2D(texture, texcoord.st) * color;
	gl_FragData[1] = vec4(normal * 0.5 + 0.5, 1.0);
	gl_FragData[2] = vec4(0.01f, 0.25f, 0.0f, 1.0f);
}
