#version 130
#extension GL_ARB_shader_texture_lod : enable
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

#define POM

#define TEXTURE_RESOLUTION 128      //[32 64 128 256 512 1024 2048]
#define PARALLAX_DEPTH 1.0          //[0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.5 3.0]'

//#define SPECULAR_TO_PBR_CONVERSION

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;

uniform ivec2 atlasSize;
uniform int terrainIconSize;

uniform float rainStrength;
uniform float wetness;

varying float materialIDs;
varying float distance;

varying vec3 normal;
varying vec3 tangent;
varying vec3 binormal;
varying vec3 viewVector;

varying vec4 color;
varying vec4 lmcoord;
varying vec4 texcoord;

varying vec4 vtexcoord;
varying vec4 vtexcoordam;

const float normalMapAngle = 2.0; //[0.5 1.0 1.5 2.0 3.0]

vec2 dcdx = dFdx(vtexcoord.st * vtexcoordam.pq);
vec2 dcdy = dFdy(vtexcoord.st * vtexcoordam.pq);

float absoluteTexGrad = dot(abs(dcdx) + abs(dcdy), vec2(1.0));
	
vec2 OffsetCoord(in vec2 coord, in vec2 offset, in int level) {

	int tileResolution    = terrainIconSize;
	ivec2 atlasTiles      = textureSize(texture, 0) / TEXTURE_RESOLUTION;
	ivec2 atlasResolution = tileResolution * atlasTiles;

	coord *= atlasResolution;

	vec2 offsetCoord = coord + mod(offset.xy * atlasResolution, vec2(tileResolution));

	vec2 minCoord = vec2(coord.x - mod(coord.x, tileResolution), coord.y - mod(coord.y, tileResolution));
	vec2 maxCoord = minCoord + tileResolution;

	if (offsetCoord.x > maxCoord.x) {
		offsetCoord.x -= tileResolution;
	} else if (offsetCoord.x < minCoord.x) {
		offsetCoord.x += tileResolution;
	}

	if (offsetCoord.y > maxCoord.y) {
		offsetCoord.y -= tileResolution;
	} else if (offsetCoord.y < minCoord.y) {
		offsetCoord.y += tileResolution;
	}

	offsetCoord /= atlasResolution;
	return offsetCoord;
	
}

vec2 CalculateParallaxCoord(in vec2 coord, in vec3 viewVector) {

	const int maxSteps = 60;
	const float gradThreshold = 0.004;
	const float parallaxStepSize = 0.5;
	
	vec2 parallaxCoord = coord.st;
	vec3 stepSize 	   = vec3(0.001f, 0.001f, 0.15f);
	
	float parallaxDepth  = PARALLAX_DEPTH;
		  parallaxDepth *= clamp(1.0 - clamp(absoluteTexGrad / gradThreshold, 0.0f, 1.0f), 0.0, 1.0);
	
	if (absoluteTexGrad > gradThreshold) return texcoord.st;

	stepSize.xy  *= parallaxDepth;
	stepSize.xyz *= parallaxStepSize;
	
	float heightmap = texture2D(normals, coord.st, 0).a;
	vec3  pCoord    = vec3(0.0, 0.0, 1.0);

	if(heightmap < 1.0 && heightmap != 0.0) {
	
		float distAngleWeight = ((distance * 0.6) * (2.1 - viewVector.z)) / 16.0;
		vec3 step = viewVector * stepSize;
			 step *= distAngleWeight * 2.0;
		float sampleHeight = heightmap;

		for (int i = 0; sampleHeight < pCoord.z && i < maxSteps; ++i) {

			pCoord.xy = mix(pCoord.xy, pCoord.xy + step.xy, clamp((pCoord.z - sampleHeight) / (stepSize.z * 1.0 * distAngleWeight / (-viewVector.z + 0.05)), 0.0, 1.0));
			pCoord.z += step.z;
			sampleHeight = texture2DGradARB(normals, OffsetCoord(coord.st, pCoord.st, 0), dcdx, dcdy).a;
			
		}
		
		parallaxCoord.xy = OffsetCoord(coord.st, pCoord.st, 0);
		
	}
	
	return parallaxCoord;
	
}

void main() {

	const float pomRenderDistance = 32.0;
	
	vec2 adjustedTexCoord  = vtexcoord.st * vtexcoordam.pq + vtexcoordam.st;
	vec4 norm              = vec4(normal * 0.5 + 0.5, 1.0);
	
	//Calculate POM
	#ifdef POM
		if (distance < pomRenderDistance) adjustedTexCoord = CalculateParallaxCoord(texcoord.st, viewVector);
	#endif
	
	//Calculate Specular
	vec3 spec = texture2DGradARB(specular, adjustedTexCoord.st, dcdx, dcdy).rgb;
	
	//Convert normal specular map to PBR
	#ifdef SPECULAR_TO_PBR_CONVERSION
		float spec_strength = dot(spec.rgb, vec3(0.3, 0.6, 0.1));
		spec = vec3(spec.b, spec_strength, 0.0f);
	#endif
		  
	//Calculate Normal
	vec3  bump      = texture2DGradARB(normals, adjustedTexCoord.st, dcdx, dcdy).rgb * 2.0 - 1.0;
	
	float bumpmult  = normalMapAngle;
	      bumpmult *= 1.0 - min(spec.r, 1.0) * 0.5;
	      bumpmult *= 1.0 - wetness * 0.85 * pow(lmcoord.y, 2.0);
	
		  bump      = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0, 0.0, 1.0 - bumpmult);
	
	mat3 tbnMatrix  = mat3(tangent.x, binormal.x, normal.x,
						   tangent.y, binormal.y, normal.y,
						   tangent.z, binormal.z, normal.z);
	
	      norm     = vec4(normalize(bump * tbnMatrix) * 0.5 + 0.5, 1.0);
	
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

	gl_FragData[0] = texture2DGradARB(texture, adjustedTexCoord.st, dcdx, dcdy) * color;
	gl_FragData[1] = vec4(materialIDs, 0.0f, 0.0f, 1.0f);
	gl_FragData[2] = norm;
	gl_FragData[3] = vec4(spec, 1.0f);
    gl_FragData[4] = vec4(lmcoord.st, 0.0f, 1.0f);

}
