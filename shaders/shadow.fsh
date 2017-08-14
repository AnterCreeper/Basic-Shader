#version 130
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

uniform sampler2D tex;

varying vec4 texcoord;
varying vec4 color;
varying vec3 normal;

varying float materialIDs;
varying float iswater;

void main() {

	vec4 tex = texture2D(tex, texcoord.st) * color;
	vec3 shadowNormal = normal.xyz;

	gl_FragData[0] = tex;
	gl_FragData[1] = vec4(shadowNormal.xyz * 0.5 + 0.5, 1.0f);

}
