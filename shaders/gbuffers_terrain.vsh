#version 120

#define MATFACTOR 1000

const float pi = 3.1415926535897932834919;

uniform sampler2D noisetex;

uniform int worldTime;
uniform float rainStrength;
uniform float frameTimeCounter;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform ivec2 eyeBrightnessSmooth;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

varying float material;
varying float POMdistance;
varying float translucent;
varying float fog_distance;

varying vec3 normal;
varying vec3 tangent;
varying vec3 binormal;
varying vec3 viewVector;

varying vec3 fogclr;
varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;

varying vec4 vtexcoord;
varying vec4 vtexcoordam; // .st for add, .pq for mul.

float timefract = worldTime;
float TimeSunrise  = ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(timefract, 0.0, 4000.0)/4000.0));
float TimeNoon     = ((clamp(timefract, 0.0, 4000.0)) / 4000.0) - ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0);
float TimeSunset   = ((clamp(timefract, 8000.0, 12000.0) - 8000.0) / 4000.0) - ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0);
float TimeMidnight = ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0);

void main() {
	
	texcoord              = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	vec2 midcoord 		  = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
	vec2 texcoordminusmid = texcoord.st - midcoord;
	
	vtexcoordam.pq  = abs(texcoordminusmid) * 2;
	vtexcoordam.st  = min(texcoord.st, midcoord - texcoordminusmid);
	vtexcoord.xy    = sign(texcoordminusmid) * 0.5 + 0.5;
	
	vec4 position   = gl_Vertex;
	
	float ID = 0.0;
	material = mc_Entity.x / MATFACTOR;
	
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
	
	viewVector = (gl_ModelViewMatrix * gl_Vertex).xyz;
	viewVector = normalize(tbnMatrix * viewVector);
		
	//Don't apply POM blocks with alpha texture.
	if (mc_Entity.x == 18.0 ||	// Oak Leaves.
		mc_Entity.x == 20.0 ||	// Glass.
		mc_Entity.x == 161.0	// Acacia Leaves.
		) viewVector = vec3(0.0);
		
	POMdistance = length(gl_ModelViewMatrix * position);
	
	// fog distance.
	float fog_sunrise = 100.0 * TimeSunrise *  (1.0-rainStrength*1.0);
	float fog_noon = 150.0 * TimeNoon * (1.0-rainStrength*1.0);
	float fog_sunset = 200.0 * TimeSunset * (1.0-rainStrength*1.0);
	float fog_midnight = 75.0 * TimeMidnight * (1.0-rainStrength*1.0);
	float fog_rain = 75.0*rainStrength;
	fog_distance = fog_sunrise + fog_noon + fog_sunset + fog_midnight + fog_rain;
	
	// get fog color. 
	vec3 fogclr_day = vec3(0.6, 0.85, 1.27) * 0.5 * (TimeSunrise + TimeNoon + TimeSunset) * (1.0-rainStrength*1.0);
	vec3 fogclr_midnight = vec3(0.2, 0.6, 1.3) * 0.01 * TimeMidnight * (1.0-rainStrength*1.0);
	vec3 fogclr_rain_day = vec3(1.5, 1.9 ,2.55) * 0.2 * (TimeSunrise + TimeNoon + TimeSunset) * rainStrength;
	vec3 fogclr_rain_night = vec3(0.35, 0.7, 1.3) * 0.01  * TimeMidnight * rainStrength;
		
	fogclr = fogclr_day + fogclr_midnight + fogclr_rain_day + fogclr_rain_night;
	fogclr *= eyeBrightnessSmooth.y / 255.0f;
		
}