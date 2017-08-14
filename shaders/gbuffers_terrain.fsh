#version 130
#extension GL_ARB_shader_texture_lod : enable
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

#define TEXTURE_RESOLUTION 128      //[32 64 128 256 512 1024 2048]
#define NOPBR
//#define NOBUMP
//#define BUMPTYPE

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D lightmap;

uniform int fogMode;
uniform int terrainIconSize;
uniform ivec2 atlasSize;

uniform float rainStrength;
uniform float wetness;

varying float material;
varying float POMdistance;
varying float fog_distance;

varying vec3 worldpos;
varying vec3 normal;
varying vec3 tangent;
varying vec3 binormal;
varying vec3 viewVector;

varying vec3 fogclr;
varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;

varying vec4 vtexcoord;
varying vec4 vtexcoordam;

const float normalMapAngle = 2.0;            //[0.5 1.0 1.5 2.0 3.0]
const float parallaxRes = exp2(8 - log2(float(TEXTURE_RESOLUTION)));

vec2 dcdx = dFdx(vtexcoord.st * vtexcoordam.pq);
vec2 dcdy = dFdy(vtexcoord.st * vtexcoordam.pq);

vec4 readNormal(vec2 coord) {
	return texture2DGradARB(normals, fract(coord) * vtexcoordam.pq + vtexcoordam.st, dcdx, dcdy);
}

float calcluma(vec3 color) {
	return dot(color.rgb,vec3(0.2125f, 0.7154f, 0.0721f));
}

vec4 GetTexture(in sampler2D tex, in vec2 coord) {

	vec4 texmap = vec4(0.0);
	if (POMdistance < 10) {
		texmap = texture2DLod(tex, coord, 0);
	} else {
		texmap = texture2D(tex, coord);
	}
	return texmap;
	
}

vec2 OffsetCoord(in vec2 coord, in vec2 offset, in int level) {

	int tileResolution    = TEXTURE_RESOLUTION;
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

	const int maxSteps  = 112;
	vec2 parallaxCoord  = coord.st;
	vec3 stepSize	    = vec3(0.001f, 0.001f, 0.15f);
	float parallaxDepth = 1.0;

	if(TEXTURE_RESOLUTION == 512) parallaxDepth = 4.0;

	stepSize.xy *= parallaxDepth;

	float heightmap = texture2D(normals, coord.st, 0).a;
	vec3  pCoord    = vec3(0.0, 0.0, 1.0);

	if(heightmap < 1.0 && heightmap != 0.0) {
	
		vec3 step = viewVector * stepSize;
		float distAngleWeight = ((POMdistance * 0.6) * (2.1 - viewVector.z)) / 32.0;
		step *= distAngleWeight;
		float sampleHeight = heightmap;

		for (int i = 0; sampleHeight < pCoord.z && i < 240; ++i) {
		
			pCoord.xy = mix(pCoord.xy, pCoord.xy + step.xy, clamp((pCoord.z - sampleHeight) / (stepSize.z * 1.0 * distAngleWeight / (-viewVector.z + 0.05)), 0.0, 1.0));
			pCoord.z += step.z;
			sampleHeight = texture2D(normals, OffsetCoord(coord.st, pCoord.st, 0), 0).a;
			
		}
		
		parallaxCoord.xy = OffsetCoord(coord.st, pCoord.st, 0);
		
	}
	
	return parallaxCoord;
	
}

vec3 Tonemapping(in vec3 color) {

	const float A = 2.51f;
	const float B = 0.03f;
	const float C = 2.43f;
	const float D = 0.59f;
	const float E = 0.14f;
	
	return (color*(A*color+B))/(color*(C*color+D)+E);

}

void main() {

	const float pomSamples			= 256.0;
	const float pomDepth			= 2.5;		// Lower means deeper.
	const float pomRenderDistance	= 32.0;
	const int	pomOcclusionPoints	= 100;
		
	const vec3 intervalMult = vec3(1.0, 1.0, 1.0 / (1.0 / pomDepth)) / pomSamples; 
	
	vec2 adjustedTexCoord   = vtexcoord.st * vtexcoordam.pq + vtexcoordam.st;
	vec4 frag2              = vec4(normal * 0.5 + 0.5, 1.0);
	
	#ifndef NOBUMP
	
	#ifdef BUMPTYPE
	
	 if (POMdistance < pomRenderDistance) {
			
		if (viewVector.z < 0.0 && readNormal(vtexcoord.st).a < 0.99 && readNormal(vtexcoord.st).a > 0.01) {
			
			vec3 interval = viewVector.xyz * intervalMult;
			vec3 coord = vec3(vtexcoord.st, 1.0);
				
			for (int loopCount = 0; (loopCount < pomOcclusionPoints) && (readNormal(coord.st).a < coord.p); ++loopCount) {
				coord = coord + interval;
			}
			
			adjustedTexCoord = fract(coord.st) * vtexcoordam.pq + vtexcoordam.st, adjustedTexCoord;
			
		}
		
	 }
	
	#else
	
	 if (POMdistance < pomRenderDistance) adjustedTexCoord = CalculateParallaxCoord(texcoord.st, viewVector);
	
	#endif
	
	#endif
	
	//Calculate Specular
	vec3 spec = texture2DGradARB(specular, adjustedTexCoord.st, dcdx, dcdy).rgb;
	//Convert normal specular map to PBR
	#ifdef NOPBR
	 float spec_strength = dot(spec.rgb, vec3(0.6, 0.3, 0.1));
	 spec = vec3(1.0f - spec.b, spec_strength, 0.0f);
	#endif
	
	//float heightmap = texture2D(normals, adjustedTexCoord.st, 0).a;
		  
	//Calculate Normal
	vec3  bump      = texture2DGradARB(normals, adjustedTexCoord.st, dcdx, dcdy).rgb * 2.0 - 1.0;
	
	float bumpmult  = normalMapAngle;
	      bumpmult *= 1.0 - min(spec.b, 1.0) * 0.5;
	      bumpmult *= 1.0 - wetness * 0.85 * pow(lmcoord.y, 2.0);
	
		  bump      = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0, 0.0, 1.0 - bumpmult);
	
	mat3 tbnMatrix  = mat3(tangent.x, binormal.x, normal.x,
						   tangent.y, binormal.y, normal.y,
						   tangent.z, binormal.z, normal.z);
	
	      frag2     = vec4(normalize(bump * tbnMatrix) * 0.5 + 0.5, 1.0);
	
/* DRAWBUFFERS:02456 */

	//0:gcolor  = albedo
	//2:gnormal = materials,iswater,isentity
	//4:gaux1   = normals
	//5:gaux2   = specular
	//6:gaux3   = lmcoord,ishand
	
	vec4 light = texture2D(lightmap, lmcoord.st);
	
	vec4 texmap = texture2DGradARB(texture, adjustedTexCoord.st, dcdx, dcdy) * color;
	
	//gl_FragData[0] = vec4(Tonemapping(texmap.rgb), texmap.a) * color * light * 0.8f;
	gl_FragData[0] = vec4(texmap.rgb * 0.8f * dot(pow(light.rgb, vec3(1.6f)), vec3(1.0f / 3.0f)), texmap.a);
	
	if(fogMode == 9729)
	 gl_FragData[0].rgb = mix(gl_Fog.color.rgb * fogclr, gl_FragData[0].rgb, clamp((gl_Fog.end - gl_FogFragCoord) / (gl_Fog.end - gl_Fog.start), 0.0, 1.0) * 0.3f + 0.7f);
	else if(fogMode == 2048)
	 gl_FragData[0].rgb = mix(gl_Fog.color.rgb * fogclr, gl_FragData[0].rgb, clamp(exp(-gl_FogFragCoord * gl_Fog.density), 0.0, 1.0) * 0.3f + 0.7f);

	gl_FragData[1] = vec4(material, 0.0f, 0.0f, 1.0f);
	gl_FragData[2] = frag2;
	gl_FragData[3] = vec4(spec, 1.0f);
    gl_FragData[4] = vec4(lmcoord.xy, 0.0f, 1.0f);

}
