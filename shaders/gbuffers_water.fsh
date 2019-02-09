#version 120
#extension GL_ARB_shader_texture_lod : enable
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

#define POM
//#define SPECULAR_TO_PBR_CONVERSION

#define OPACITY 0.6f	   //[0.0 0.5 0.6 0.65 0.7 0.72 0.75 0.78 0.8 0.9]
#define WAVE_HEIGHT 0.25f  //[0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.5]

const vec3 primaryWavelengths = vec3(700, 546.1, 435.8);
const float PI = 3.14159265358979;

const int noiseTextureResolution = 720;

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D noisetex;

uniform int moonPhase;
uniform float wetness;
uniform float rainStrength;
uniform float frameTimeCounter;

varying vec4 color;

varying vec3 normal;
varying vec3 tangent;
varying vec3 binormal;
varying vec3 worldpos;
varying vec3 viewVector;

varying vec2 lmcoord;
varying vec2 texcoord;

varying float iswater;
varying float materialIDs;
varying float distance;

#include "/lib/Noiselib.frag"
#include "/lib/Waterlib.frag"

//Waterlib interface
float GetWave(vec3 position) {
	return doWave(position, 1.0f);
}

vec3 GetWaterCoord(in vec3 position, in vec3 viewVector) {

	float waveHeight = GetWave(position);
	
	vec3 stepSize = vec3(0.6f * WAVE_HEIGHT, 0.6f * WAVE_HEIGHT, 0.6f);
	vec3 pCoord   = vec3(0.0f, 0.0f, 1.0f);
	
	vec3 step = viewVector * stepSize;
	
	float distAngleWeight = ((distance * 0.2f) * (2.1f - viewVector.z)) / 2.0f;
	float sampleHeight = waveHeight;

	step *= distAngleWeight;
		
	for (int i = 0; sampleHeight < pCoord.z && i < 120; ++i)
	{
		pCoord.xy = mix(pCoord.xy, pCoord.xy + step.xy, clamp((pCoord.z - sampleHeight) / (stepSize.z * 0.2f * distAngleWeight / (-viewVector.z + 0.05f)), 0.0f, 1.0f));
		pCoord.z += step.z;
		sampleHeight = GetWave(position + vec3(pCoord.x, 0.0f, pCoord.y));
	}

	return position.xyz + vec3(pCoord.x, 0.0f, pCoord.y);
	
}

void main() {

	vec4 watercolor = vec4(normalize(vec3(1.0f) / normalize(pow(primaryWavelengths, vec3(2.2f)))) / 4.0f, OPACITY);
	vec4 tex = vec4((watercolor * length(texture2D(texture, texcoord.xy).rgb * color.rgb) * color).rgb, watercolor.a);
	
	if (iswater < 0.1)  tex = texture2D(texture, texcoord.xy) * color;
	
	vec3 posxz = worldpos.xyz;

	posxz.x += sin(posxz.z + frameTimeCounter      ) * 0.25;
	posxz.z += cos(posxz.x + frameTimeCounter * 0.5) * 0.25;
	
	#ifdef POM
		posxz = GetWaterCoord(posxz, viewVector);
	#endif
	
	float deltaPos = 0.4;
	float h0 = GetWave(posxz);
	float h1 = GetWave(posxz + vec3(deltaPos, 0.0,0.0));
	float h2 = GetWave(posxz + vec3(-deltaPos,0.0,0.0));
	float h3 = GetWave(posxz + vec3(0.0,0.0, deltaPos));
	float h4 = GetWave(posxz + vec3(0.0,0.0,-deltaPos));
	
	float xDelta = ((h1-h0)+(h0-h2)) / deltaPos;
	float yDelta = ((h3-h0)+(h0-h4)) / deltaPos;
	
	vec3 newnormal = normalize(vec3(xDelta, yDelta, 1.0 - xDelta*xDelta - yDelta*yDelta));	
	vec4 frag2     = vec4(texture2D(normals, texcoord.st).rgb * 2.0f - 1.0f, 1.0f);
	
	vec3 bump = frag2.xyz;
	if (iswater > 0.9) bump = newnormal;
		
	float bumpmult = 0.05;	
		
	bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
						  tangent.y, binormal.y, normal.y,
						  tangent.z, binormal.z, normal.z);
		                 
	frag2 = vec4(normalize(bump * tbnMatrix) * 0.5 + 0.5, 1.0);
	
	vec3 spec = texture2D(specular, texcoord.st).rgb;
		 
	#ifdef SPECULAR_TO_PBR_CONVERSION
		float spec_strength = dot(spec.rgb, vec3(0.3, 0.6, 0.1));
		spec = vec3(spec.b, spec_strength, 0.0f);
	#endif
	
	spec = mix(spec, vec3(0.25f, 0.0f, 0.10f), iswater);

/* DRAWBUFFERS:01245 */

	//0:gcolor    = albedo(r.g.b), cloudmask(a) RGBA16
	//1:gdepth    = materials(r), luminance(g) RG16F
	//2:gnormal   = normals(r.g.b) RGB16
	//3:composite = bloomdata/aaEdgeTex(r.g.b) RGB16
	//4:gaux1     = specular(r.g.b) RGB16
	//5:gaux2     = lmcoord(r.g), state(b), godrays(a) RGBA16
	//6:gaux3     = aaAreaTex
	//7:gaux4     = aaSearchTex
	
	// state 
	// 0.0 : none 
	// 0.1 : ishand
	// 0.2 : iswater
	// 0.3 : isentity
	// 0.4 : isice

	gl_FragData[0] = tex;
	gl_FragData[1] = vec4(materialIDs, 0.0f, 0.0f, 1.0f);
	gl_FragData[2] = frag2;
	gl_FragData[3] = vec4(spec, 1.0f);
	gl_FragData[4] = vec4(lmcoord.st, mix(0.4f, 0.2f, iswater), 1.0f);

}