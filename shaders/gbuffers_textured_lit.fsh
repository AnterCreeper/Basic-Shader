#version 120
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

uniform int fogMode;
uniform sampler2D texture;

varying vec4 color;
varying vec4 texcoord;
varying vec3 normal;
varying float entityType;

/* DRAWBUFFERS:04 */
void main() {
	if(entityType < -2.5) discard;
	gl_FragData[0] = texture2D(texture, texcoord.st) * color;
	if(fogMode == 9729)
		gl_FragData[0].rgb = mix(gl_Fog.color.rgb, gl_FragData[0].rgb, clamp((gl_Fog.end - gl_FogFragCoord) / (gl_Fog.end - gl_Fog.start), 0.0, 1.0));
	else if(fogMode == 2048)
		gl_FragData[0].rgb = mix(gl_Fog.color.rgb, gl_FragData[0].rgb, clamp(exp(-gl_FogFragCoord * gl_Fog.density), 0.0, 1.0));
	gl_FragData[1] = vec4(normal, 1.0);
}