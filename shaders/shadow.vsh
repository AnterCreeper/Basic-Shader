#version 120
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

#define SHADOW_MAP_BIAS 0.80

const float pi = 3.1415926535897932834919;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

varying vec4 texcoord;
varying vec4 vPosition;
varying vec4 color;
varying vec4 lmcoord;

varying vec3 normal;
varying vec3 rawNormal;

varying float iswater;
varying float materialIDs;

uniform sampler2D noisetex;
uniform int worldTime;
uniform float rainStrength;
uniform float frameTimeCounter;
uniform vec3 cameraPosition;

uniform mat4 shadowProjectionInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;

void main() {

	gl_Position = ftransform();

	lmcoord 	= gl_TextureMatrix[1] * gl_MultiTexCoord1;
	texcoord 	= gl_MultiTexCoord0;

	vec4 position = gl_Position;
		 position = shadowProjectionInverse * position;
		 position = shadowModelViewInverse * position;
		 position.xyz += cameraPosition.xyz;

	materialIDs = 0.0f;
	iswater = 0.0;

	if (mc_Entity.x == 8 || mc_Entity.x == 9 || mc_Entity.x == 1971)  iswater = 1.0f;
	
	float ID = 0.0f;
	
	//Grass
	if(mc_Entity.x == 6
	|| mc_Entity.x == 31
	|| mc_Entity.x == 32
	|| mc_Entity.x == 37
	|| mc_Entity.x == 38	
	
	|| mc_Entity.x == 59
	|| mc_Entity.x == 141
	|| mc_Entity.x == 142

	//Biomes O Plenty
	|| mc_Entity.x == 176
	|| mc_Entity.x == 177
	|| mc_Entity.x == 178
		
	|| mc_Entity.x == 186
	|| mc_Entity.x == 187
		
	|| mc_Entity.x == 212
	|| mc_Entity.x == 213
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
		float maxStrength = 1.0 + rainStrength * 0.5;
		float time = frameTimeCounter * 0.2;
		float reset = sin(noise.z * 10.0 + time * 0.1);
		reset = max(reset * reset, max(rainStrength, 0.1));
        float x = noise.x * 10.0 + time;
        float y = noise.y * 10.0 + time;
		position.x += cos(pi*x) * cos(pi*3*x) * cos(pi*5*x) * cos(pi*7*x) * 0.2 * reset * maxStrength;
		position.z += cos(pi*y) * cos(pi*3*y) * cos(pi*5*y) * cos(pi*7*y) * 0.2 * reset * maxStrength;
	}
	else if(ID == 2 && gl_MultiTexCoord0.t < mc_midTexCoord.t)
	{
		vec3 noise = texture2D(noisetex, (position.xz + 0.5) / 16.0).rgb;
		float maxStrength = 1.0 + rainStrength * 0.5;
		float time = frameTimeCounter * 0.12;
		float reset = sin(noise.z * 10.0 + time * 0.1);
        float x = noise.x * 10.0 + time;
        float y = noise.y * 10.0 + time;
		position.x += cos(pi*x) * cos(pi*x) * cos(pi*3*x) * cos(pi*5*x) * 0.12 * reset * maxStrength;
		position.z += cos(pi*y) * cos(pi*y) * cos(pi*3*y) * cos(pi*5*y) * 0.12 * reset * maxStrength;
	}

	position.xyz -= cameraPosition.xyz;
	position = shadowModelView * position;
	position = shadowProjection * position;

	normal = normalize(gl_NormalMatrix * gl_Normal);

	float facingLightFactor = dot(normal, vec3(0.0, 0.0, 1.0));
	position.z += pow(max(0.0, 1.0 - facingLightFactor), 4.0) * 0.01;

	gl_Position = position;
	float dist  = sqrt(dot(gl_Position.xy, gl_Position.xy));
	float distortFactor = (1.0f - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;

	gl_Position.xy *= 1.0f / distortFactor;
	vPosition 		= gl_Position;

	gl_FrontColor 	= gl_Color;
	color 			= gl_Color;

}
