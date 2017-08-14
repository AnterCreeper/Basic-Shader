#version 120
#extension GL_ARB_shader_texture_lod : enable
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

#define NOPBR
//#define NOBUMP
#define FAST_WAVE
#define OPACITY 0.38f
#define WAVE_HEIGHT 0.65f
#define MATFACTOR 1000

const float PI = 3.14159265358979;
const vec3 primaryWavelengths = vec3(700, 546.1, 435.8);

varying vec4 color;
varying vec2 texcoord;
varying vec2 lmcoord;

varying vec3 wpos;
varying vec3 binormal;
varying vec3 normal;
varying vec3 tangent;
varying vec3 viewVector;
varying float iswater;
varying float material;
varying float distance;

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D lightmap;
uniform sampler2D specular;
uniform sampler2D noisetex;

uniform int worldTime;
uniform float far;
uniform float rainStrength;
uniform float frameTimeCounter;

uniform vec3 cameraPosition;

float hash(vec2 p) {
	vec3 p3  = fract(vec3(p.xyx) * 0.2031);
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p * 64);
	vec2 f = fract(p * 64);
	vec2 u = f*f*(3.0-2.0*f);
	return -1.0 + 2.0 * mix(
		mix(hash(i),                 hash(i + vec2(1.0,0.0)), u.x),
		mix(hash(i + vec2(0.0,1.0)), hash(i + vec2(1.0,1.0)), u.x),
	u.y);
}

float waterH(in vec3 pos){

	float speed = 4.0;
	float t = -frameTimeCounter * speed;
	
	vec2 coord = pos.xz / (64 + 32 + 16);
		 coord.x -= t / 128;
	
	float wave = 0.0;
	
	wave += noise(coord * vec2(2.00, 1.00));	coord /= 6;	  coord.x -= t / 256; coord.y += t / (128 + 64) * 1.25;
	wave += noise(coord * vec2(1.75, 1.50));	coord.y /= 4; coord.x /= 2;       coord.xy -= t / (256 - 64) * 0.5;
	wave += noise(coord * vec2(1.50, 2.00));
	
	return wave;

}

float waterH2(in vec3 posxz) {

	float wave = 0.0;
	float factor = 2.0;
	float amplitude = 0.2;
	float speed = 8.0;
	float size = 0.2;

	float px = posxz.x/50.0 + 250.0;
	float py = posxz.z/50.0  + 250.0;
	
	float fpx = abs(fract(px*20.0)-0.5)*2.0;
	float fpy = abs(fract(py*20.0)-0.5)*2.0;
	
	float d = length(vec2(fpx,fpy));
	for (int i = 1; i < 4; i++) {
		wave -= d*factor*cos((1/factor)*px*py*size + 1.0*frameTimeCounter*speed);
		factor /= 2;
	}

	factor = 1.0;
	px = -posxz.x/50.0 + 250.0;
	py = -posxz.z/150.0 - 250.0;
	
	fpx = abs(fract(px*20.0)-0.5)*2.0;
	fpy = abs(fract(py*20.0)-0.5)*2.0;

	d = length(vec2(fpx,fpy));
	float wave2 = 0.0;
	for (int i = 1; i < 4; i++) {
		wave2 -= d*factor*cos((1/factor)*px*py*size + 1.0*frameTimeCounter*speed);
		factor /= 2;
	}
	
	return amplitude*wave2+amplitude*wave;
	
}

float waterHComposite(vec3 posxz) {

	#ifdef FAST_WAVE
	 return waterH2(posxz) * 0.4f;
	#else
	 return (waterH(posxz) + waterH2(posxz)) * 0.2f;
	#endif

}

vec3 GetWaterCoord(in vec3 position, in vec3 viewVector) {
	
	vec3 parallaxCoord = position.xyz;
	vec3 stepSize = vec3(0.6f * WAVE_HEIGHT, 0.6f * WAVE_HEIGHT, 0.6f);

	float waveHeight = waterHComposite(position);

		vec3 pCoord = vec3(0.0f, 0.0f, 1.0f);

		vec3 step = viewVector * stepSize;
		float distAngleWeight = ((distance * 0.2f) * (2.1f - viewVector.z)) / 2.0f;
		distAngleWeight = 1.0f;
		step *= distAngleWeight;

		float sampleHeight = waveHeight;

		for (int i = 0; sampleHeight < pCoord.z && i < 120; ++i)
		{
			pCoord.xy = mix(pCoord.xy, pCoord.xy + step.xy, clamp((pCoord.z - sampleHeight) / (stepSize.z * 0.2f * distAngleWeight / (-viewVector.z + 0.05f)), 0.0f, 1.0f));
			pCoord.z += step.z;
			sampleHeight = waterHComposite(position + vec3(pCoord.x, 0.0f, pCoord.y));
		}

	parallaxCoord = position.xyz + vec3(pCoord.x, 0.0f, pCoord.y);
	
	return parallaxCoord;
	
}

void main() {

	vec4 watercolor = vec4(normalize(vec3(1.0f) / normalize(pow(primaryWavelengths,vec3(4.0f)))) / 6.0f, OPACITY);
	vec4 tex = vec4((watercolor * length(texture2D(texture, texcoord.xy).rgb * color.rgb) * color).rgb, watercolor.a);
	
	if (iswater < 0.1)  tex = texture2D(texture, texcoord.xy) * color;
	
	vec3 posxz = wpos.xyz;

	posxz.x += sin(posxz.z + frameTimeCounter      ) * 0.25;
	posxz.z += cos(posxz.x + frameTimeCounter * 0.5) * 0.25;
	
	#ifndef NOBUMP
	 posxz = GetWaterCoord(posxz, viewVector);
	#endif
	
	float deltaPos = 0.4;
	float h0 = waterHComposite(posxz);
	float h1 = waterHComposite(posxz + vec3(deltaPos,0.0,0.0));
	float h2 = waterHComposite(posxz + vec3(-deltaPos,0.0,0.0));
	float h3 = waterHComposite(posxz + vec3(0.0,0.0,deltaPos));
	float h4 = waterHComposite(posxz + vec3(0.0,0.0,-deltaPos));
	
	float xDelta = ((h1-h0)+(h0-h2)) / deltaPos;
	float yDelta = ((h3-h0)+(h0-h4)) / deltaPos;
	
	vec3 newnormal = normalize(vec3(xDelta,yDelta,1.0-xDelta*xDelta-yDelta*yDelta));	
	vec4 frag2     = vec4(texture2D(normals, texcoord.st).rgb * 0.5f + 0.5f, 1.0f);
	
	vec3 bump = frag2.xyz;
	if (iswater > 0.9) bump = newnormal;
		
	float bumpmult = 0.05;	
		
	bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
						  tangent.y, binormal.y, normal.y,
						  tangent.z, binormal.z, normal.z);
		
	frag2 = vec4(normalize(bump * tbnMatrix) * 0.5 + 0.5, 1.0);
	
	vec3 spec = texture2D(specular, texcoord.st).rgb;
	#ifdef NOPBR
	 float spec_strength = dot(spec.rgb, vec3(0.6, 0.3, 0.1));
	 spec = vec3(1.0f - spec.b, spec_strength, 0.0f);
	#endif
	
/* DRAWBUFFERS:02456 */

	//0:gcolor  = albedo
	//2:gnormal = materials,iswater,isentity
	//4:gaux1   = normals
	//5:gaux2   = specular
	//6:gaux3   = lmcoord,ishand
	
	gl_FragData[0] = tex;
	gl_FragData[1] = vec4(material / MATFACTOR, iswater, 0.0f, 1.0f);
	gl_FragData[2] = frag2;
	gl_FragData[3] = vec4(mix(spec, vec3(1.0f), iswater), 1.0f);
	gl_FragData[4] = vec4(lmcoord.xy, 0.0f, 1.0f);

}