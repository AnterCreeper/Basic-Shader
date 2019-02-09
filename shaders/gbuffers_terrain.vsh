#version 120
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

const float pi = 3.1415926535897932834919;
const float noiseTextureResolution = 720;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

uniform sampler2D noisetex;

uniform float rainStrength;
uniform float frameTimeCounter;

varying vec4 color;
varying vec4 lmcoord;
varying vec4 texcoord;

varying vec3 normal;
varying vec3 tangent;
varying vec3 binormal;
varying vec3 viewVector;

varying vec4 vtexcoord;
varying vec4 vtexcoordam; // .st for add, .pq for mul.

varying float materialIDs;
varying float distance;

float noise_tex(in vec2 pos) {
    return texture2D(noisetex, pos).x;
}

float cubic_noise(vec3 pos) {
	vec3 p = floor(pos);
	vec3 f = fract(pos);
	vec2 uv  = (p.xy + p.z * vec2(17.0f)) + f.xy;
	vec2 uv2 = (p.xy + (p.z + 1.0f) * vec2(17.0f)) + f.xy;
	vec2 coord  = (uv  + 0.5f) / noiseTextureResolution;
	vec2 coord2 = (uv2 + 0.5f) / noiseTextureResolution;
	float xy1 = noise_tex(coord);
	float xy2 = noise_tex(coord2);
	return mix(xy1, xy2, f.z);
}

void main() {
	
	materialIDs = mc_Entity.x;
	texcoord              = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	vec2 midcoord 		  = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
	vec2 texcoordminusmid = texcoord.st - midcoord;
	
	vtexcoordam.pq  = abs(texcoordminusmid) * 2;
	vtexcoordam.st  = min(texcoord.st, midcoord - texcoordminusmid);
	vtexcoord.xy    = sign(texcoordminusmid) * 0.5 + 0.5;
	
	float facingEast = abs(normalize(gl_Normal.xz).x);
	float facingUp   = abs(gl_Normal.y);
	
	vec4 position   = gl_Vertex;
	
	float ID = 0.0;
	
	//Grass
	if(mc_Entity.x == 31
	|| mc_Entity.x == 37
	|| mc_Entity.x == 38	

	//Biomes O Plenty
	|| mc_Entity.x == 1925
	|| mc_Entity.x == 1920
	|| mc_Entity.x == 1921
		
	|| mc_Entity.x == 175
	|| mc_Entity.x == 59
		
	){
		ID = 1.0;
	}
	
	//Leaves
	if(mc_Entity.x == 18
	|| mc_Entity.x == 161
	
	//Biomes O Plenty
	|| mc_Entity.x == 192
	|| mc_Entity.x == 193
	|| mc_Entity.x == 207	
	|| mc_Entity.x == 208
	|| mc_Entity.x == 209
	|| mc_Entity.x == 246
	|| mc_Entity.x == 247
	){
		ID = 2.0;
	}
	
	//Vine
	if(mc_Entity.x == 106
	
	//Biomes O Plenty
	|| mc_Entity.x == 181
	|| mc_Entity.x == 182
	|| mc_Entity.x == 184
	|| mc_Entity.x == 185
	){
		ID = 3.0;
	}
	
	//Lily Pad
	if(mc_Entity.x == 111){
		ID = 4.0;
	}
	
	if(mc_Entity.x == 51){
		ID = 5.0;
	}	
	
	if(mc_Entity.x == 89){
		ID = 6.0;
	}
	
	if(mc_Entity.x == 11 || mc_Entity.x == 10){
		ID = 8.0;
	}
	
	if(ID == 1 && gl_MultiTexCoord0.t < mc_midTexCoord.t)
	{
		vec3 noise = texture2D(noisetex, position.xz / 256.0).rgb;
		float maxStrength = 1.2 + rainStrength * 0.5;
		float time = frameTimeCounter * 0.2;
		float reset = sin(noise.z * 10.0 + time * 0.1);
		reset = max(reset * reset, max(rainStrength, 0.1));
        float x = noise.x * 10.0 + time;
        float y = noise.y * 10.0 + time;
		position.x += cos(pi*x) * cos(pi*3*x) * cos(pi*5*x) * cos(pi*7*x) * 0.2 * reset * maxStrength;
		position.z += cos(pi*y) * cos(pi*3*y) * cos(pi*5*y) * cos(pi*7*y) * 0.2 * reset * maxStrength;
	}

	position        = gl_ModelViewMatrix * position;
	gl_Position     = gl_ProjectionMatrix * position;
	gl_FogFragCoord = length(position.xyz);
	color 			= gl_Color;
	lmcoord 		= gl_TextureMatrix[1] * gl_MultiTexCoord1;
	normal			= normalize(gl_NormalMatrix * gl_Normal);

	if (gl_Normal.y > 0.5) {
		//  0.0,  1.0,  0.0
		tangent.xyz  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal.xyz = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
	} else if (gl_Normal.x >  0.5) {
		//  1.0,  0.0,  0.0
		tangent.xyz  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0, -1.0));
		binormal.xyz = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.x < -0.5) {
		// -1.0,  0.0,  0.0
		tangent.xyz  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
		binormal.xyz = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.z >  0.5) {
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
	
	viewVector = (gl_ModelViewMatrix * gl_Vertex).xyz;
	viewVector = normalize(tbnMatrix * viewVector);
		
	//Don't apply POM blocks with alpha texture.
	if (mc_Entity.x == 18.0 ||	// Oak Leaves.
		mc_Entity.x == 20.0 ||	// Glass.
		mc_Entity.x == 161.0	// Acacia Leaves.
		) viewVector = vec3(0.0);
		
	distance = length(position.xyz);
		
}