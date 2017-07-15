#version 120

const float pi = 3.1415926535897932834919;

uniform float rainStrength;
uniform float frameTimeCounter;
uniform sampler2D noisetex;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec2 normal;

vec2 normalEncode(vec3 n) {
    vec2 enc = normalize(n.xy) * (sqrt(-n.z*0.5+0.5));
    enc = enc*0.5+0.5;
    return enc;
}

void main()
{
	vec4 position = gl_Vertex;
	float blockId = mc_Entity.x;
	if((blockId == 31.0 || blockId == 37.0 || blockId == 38.0) && gl_MultiTexCoord0.t < mc_midTexCoord.t)
	{
		float blockId = mc_Entity.x;
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
	else if(mc_Entity.x == 18.0 || mc_Entity.x == 106.0 || mc_Entity.x == 161.0 || mc_Entity.x == 175.0)
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
	position = gl_ModelViewMatrix * position;
	gl_Position = gl_ProjectionMatrix * position;
	gl_FogFragCoord = length(position.xyz);
	color = gl_Color;
	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
	normal = normalEncode(gl_NormalMatrix * gl_Normal);
}
