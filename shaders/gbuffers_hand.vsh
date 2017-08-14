#version 120

varying vec4 color;
varying vec4 vtexcoordam; // .st for add, .pq for mul.
varying vec4 vtexcoord;
varying vec3 tangent;
varying vec3 normal;
varying vec3 binormal;
varying vec2 texcoord;
varying vec2 lmcoord;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

uniform int worldTime;

void main() {

	tangent = vec3(0.0);
	binormal = vec3(0.0);
	
	vec2 midcoord;
	vec2 texcoordminusmid;
	
	texcoord 			= (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
	lmcoord 			= (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	midcoord 			= (gl_TextureMatrix[0] *  mc_midTexCoord).st;
	texcoordminusmid 	= texcoord - midcoord;
	vtexcoordam.pq  	= abs(texcoordminusmid) * 2;
	vtexcoordam.st  	= min(texcoord, midcoord - texcoordminusmid);
	vtexcoord.xy    	= sign(texcoordminusmid) * 0.5 + 0.5;
	
	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	
	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
	
	color = gl_Color;
	
	normal = normalize(gl_NormalMatrix * gl_Normal);
	
	if (gl_Normal.y > 0.5) {
		//  0.0,  1.0,  0.0
		tangent.xyz  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal.xyz = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
	} else if (gl_Normal.x > 0.5) {
		//  1.0,  0.0,  0.0
		tangent.xyz  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0, -1.0));
		binormal.xyz = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.x < -0.5) {
		// -1.0,  0.0,  0.0
		tangent.xyz  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
		binormal.xyz = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.z > 0.5) {
		//  0.0,  0.0,  1.0
		tangent.xyz  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal.xyz = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.z < -0.5) {
		//  0.0,  0.0, -1.0
		tangent.xyz  = normalize(gl_NormalMatrix * vec3(-1.0,  0.0,  0.0));
		binormal.xyz = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.y < -0.5) {
		//  0.0, -1.0,  0.0
		tangent.xyz  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal.xyz = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
	}
	
	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
						  tangent.y, binormal.y, normal.y,
						  tangent.z, binormal.z, normal.z);
	
}