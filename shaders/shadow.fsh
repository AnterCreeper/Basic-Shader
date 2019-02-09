#version 120
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

uniform sampler2D texture;
uniform sampler2D specular;

varying float materialIDs;
varying float iswater;
varying float isglass;

varying vec4 color;
varying vec4 texcoord;

varying vec3 normal;

vec2 normalEncode(vec3 normal) {
	return sqrt(-normal.z * 0.125 + 0.125) * normalize(normal.xy) + 0.5;
}

void main() {
	gl_FragData[0] = texture2D(texture, texcoord.st) * color;
	gl_FragData[1] = vec4(normalEncode(normalize(normal)), iswater * 0.1f + isglass * 0.2f, 1.0f);
}
