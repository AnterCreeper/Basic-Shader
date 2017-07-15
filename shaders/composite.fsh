#version 120

// This file is part of Basic Shader.
//
// (C) Copyright 2016 AnterCreeper <wangzhihao9@yeah.net>
// This Shader is Written by AnterCreeper. Some rights reserved.
//
// Basic Shader is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Basic Shader is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Basic Shader at /LICENSE.
// If not, see <http://www.gnu.org/licenses/>.
    
#define SHADOW_MAP_BIAS 0.85

const int RG16 = 0;
const int RGB8 = 0;
const int colortex1Format = RGB8;
const int gnormalFormat = RG16;

const int shadowMapResolution = 2048;
const float shadowDistance = 64.0;		//75 draw distance of shadows

const int noiseTextureResolution = 720;
const float sunPathRotation = -40.0;
const bool shadowHardwareFiltering = true;

uniform float far;
uniform float frameTimeCounter;
uniform vec3 sunPosition;
uniform vec3 cameraPosition;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform sampler2D gcolor;
uniform sampler2D gnormal;
uniform sampler2D depthtex0;
uniform sampler2D noisetex;
uniform sampler2DShadow shadow;

varying float extShadow;
varying vec3 lightPosition;
varying vec3 worldSunPosition;
varying vec3 cloudBase1;
varying vec3 cloudBase2;
varying vec3 cloudLight1;
varying vec3 cloudLight2;
varying vec4 texcoord;

vec3 normalDecode(vec2 enc) {
    vec4 nn = vec4(2.0 * enc - 1.0, 1.0, -1.0);
    float l = dot(nn.xyz,-nn.xyw);
    nn.z = l;
    nn.xy *= sqrt(l);
    return nn.xyz * 2.0 + vec3(0.0, 0.0, -1.0);
}

float shadowMapping(vec4 worldPosition, float dist, vec3 normal, float alpha) {
	if(dist > 0.9)
		return extShadow;
	float shade = 0.0;
	float angle = dot(lightPosition, normal);
	if(angle <= 0.1 && alpha > 0.99)
	{
		shade = 1.0;
	}
	else
	{
		vec4 shadowposition = shadowModelView * worldPosition;
		shadowposition = shadowProjection * shadowposition;
		float edgeX = abs(shadowposition.x) - 0.9;
		float edgeY = abs(shadowposition.y) - 0.9;
		float distb = sqrt(shadowposition.x * shadowposition.x + shadowposition.y * shadowposition.y);
		float distortFactor = (1.0 - SHADOW_MAP_BIAS) + distb * SHADOW_MAP_BIAS;
		shadowposition.xy /= distortFactor;
		shadowposition /= shadowposition.w;
		shadowposition = shadowposition * 0.5 + 0.5;
		shade = 1.0 - shadow2D(shadow, vec3(shadowposition.st, shadowposition.z - 0.0001)).z;
		if(angle < 0.2 && alpha > 0.99)
			shade = max(shade, 1.0 - (angle - 0.1) * 10.0);
		shade -= max(0.0, edgeX * 10.0);
		shade -= max(0.0, edgeY * 10.0);
	}
	shade -= clamp((dist - 0.7) * 5.0, 0.0, 1.0);
	shade = clamp(shade, 0.0, 1.0);
	return max(shade, extShadow);
}

float hash(float n) {
	return fract(sin(n)*43758.5453);
}
	 
float noise(in vec2 x) {
	vec2 p = floor(x);
	vec2 f = fract(x);
	f = f*f*(3.0-2.0*f);
	float n = p.x + p.y*57.0;
	float res = mix(mix(hash(n+0.0), hash(n+1.0),f.x), mix(hash(n+57.0), hash(n+58.0),f.x),f.y);
	return res;
}
	 
float fbm(vec2 p) {
	float f = 0.0;
	f += 0.50000*noise(p); p = p*2.5;
	f += 0.25000*noise(p); p = p*2.5;
	f += 0.12500*noise(p); p = p*2.5;
	f += 0.06250*noise(p); p = p*2.5;
	f += 0.03125*noise(p);
	return f / 0.984375;
}

float noise(in vec3 pos)
{
	pos.z += 0.0f;
	vec3 p = floor(pos);
	vec3 f = fract(pos);

	vec2 uv =  (p.xy + p.z * vec2(17.0f)) + f.xy;
	vec2 uv2 = (p.xy + (p.z + 1.0f) * vec2(17.0f)) + f.xy;
	vec2 coord =  (uv  + 0.5f) / noiseTextureResolution;
	vec2 coord2 = (uv2 + 0.5f) / noiseTextureResolution;
	float xy1 = fbm(coord);
	float xy2 = fbm(coord2);
	return mix(xy1, xy2, f.z);
}

void main() {

	vec4 color = texture2D(gcolor, texcoord.st);
	vec3 normal = normalDecode(texture2D(gnormal, texcoord.st).rg);
	float depth = texture2D(depthtex0, texcoord.st).x;
	vec4 viewPosition = gbufferProjectionInverse * vec4(texcoord.s * 2.0 - 1.0, texcoord.t * 2.0 - 1.0, 2.0 * depth - 1.0, 1.0f);
	viewPosition /= viewPosition.w;
	vec4 worldPosition = gbufferModelViewInverse * (viewPosition + vec4(normal * 0.05 * sqrt(abs(viewPosition.z)), 0.0));
	float dist = length(worldPosition.xyz) / far;
	
	float shade = shadowMapping(worldPosition, dist, normal, color.a);
	color.rgb *= 1.0 - shade * 0.38;
        color.rgb *= shade * vec3(0.7,0.8,1.0) + (1 - shade) * vec3(0.96,0.97,0.94);
	
/* DRAWBUFFERS:0 */
	gl_FragData[0] = color;

}
