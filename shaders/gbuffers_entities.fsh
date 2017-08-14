#version 120
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D lightmap;
uniform int entityHurt;

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;

varying vec3 normal;

const int GL_LINEAR = 9729;
const int GL_EXP    = 2048;

void main() {

/* DRAWBUFFERS:02456 */

	//0:gcolor  = albedo
	//2:gnormal = materials,iswater,isentity
	//4:gaux1   = normals
	//5:gaux2   = specular
	//6:gaux3   = lmcoord,ishand
	
	vec4 tex = texture2D(texture, texcoord.st) * color * texture2D(lightmap, lmcoord.st);
	
	gl_FragData[0] = vec4(tex.rgb * 0.8f, tex.a);
	gl_FragData[1] = vec4(0.0f, 0.0f, 1.0f, 1.0f);
	gl_FragData[2] = vec4(normal * 0.5 + 0.5, 1.0);
	gl_FragData[3] = texture2D(specular, texcoord.st);
	gl_FragData[4] = vec4(lmcoord.st, 0.0f, 1.0f);

}
