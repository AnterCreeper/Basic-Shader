#version 120
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

//Switch of effects
//#define SMAA
#define MOTION_BLUR

//Please read the license before change things below this line !!

const bool gcolorMipmapEnabled = true;

const float e = 2.7182818284590452353;

varying vec4 texcoord;

uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gaux1;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;

uniform float far;
uniform float near;

uniform float rainStrength;
uniform float frameTime;
uniform vec3 sunPosition;
uniform vec3 shadowLightPosition;
uniform ivec2 eyeBrightnessSmooth;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform vec3 upPosition;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

float pw = 1.0 / viewWidth;
float ph = 1.0 / viewHeight;

#define SMAASampleLevelZero(tex, coord) texture2DLod(tex, coord, 0.0)
#define SMAASampleLevelZeroPoint(tex, coord) texture2DLod(tex, coord, 0.0)
#define SMAASampleLevelZeroOffset(tex, coord, offset) texture2DLodOffset(tex, coord, 0.0, offset)
#define SMAASample(tex, coord) texture2D(tex, coord)
#define SMAASamplePoint(tex, coord) texture2D(tex, coord)
#define SMAASampleOffset(tex, coord, offset) texture2D(tex, coord, offset)
#define lerp(a, b, t) mix(a, b, t)
#define saturate(a) clamp(a, 0.0, 1.0)
#define mad(a, b, c) (a * b + c)

vec3 GetColorTex(vec2 coord){
	return SMAASampleOffset(gcolor, coord, 0).rgb;
}

const float bloom_offset[9] = float[9] (0.0, 1.4896, 3.4757, 5.4619, 7.4482, 9.4345, 11.421, 13.4075, 15.3941);
const float bloom_weight[9] = float[9] (0.066812, 0.129101, 0.112504, 0.08782, 0.061406, 0.03846, 0.021577, 0.010843, 0.004881);

vec3 CalculateBloom(in int LOD, in vec2 offset) {

	float scale   = pow(2.0f, float(LOD));
	float padding = 0.02f;

	if (	texcoord.s - offset.s + padding < 1.0f / scale + (padding * 2.0f) 
		&&  texcoord.t - offset.t + padding < 1.0f / scale + (padding * 2.0f)
		&&  texcoord.s - offset.s + padding > 0.0f 
		&&  texcoord.t - offset.t + padding > 0.0f) {
		
		vec4 bloom = vec4(0.0f);

		for (int i = -5; i <= 5; i++) {
		
			for (int j = -5; j <= 5; j++) {

				float weight = 1.0f - length(vec2(i, j)) / 3.5;
					  weight = clamp(weight, 0.0f, 1.0f);
					  weight = 1.0f - cos(weight * 3.1415 / 2.0f);
					  weight = pow(weight, 2.0f);

				vec2 coord = vec2(i, j);
					 coord.x /= viewWidth;
					 coord.y /= viewHeight;

				vec2 finalCoord = (texcoord.st + coord.st - offset.st) * scale;

				if (weight > 0.0f) {
					bloom.rgb += GetColorTex(finalCoord) * weight;
					bloom.a   += weight;
				}
				
			}
			
		}

		bloom.rgb /= bloom.a;

		return bloom.rgb;

	} else {
	
		return vec3(0.0f);
		
	}
	
}

vec3 MotionBlur(in vec2 TexCoords) {

    #ifdef MOTION_BLUR
	
	float maxVelocity = 0.05f;
	
	float depth = texture2D(gdepthtex, TexCoords.st).x;
	
	vec4 currentPosition = vec4(TexCoords.x * 2.0f - 1.0f, TexCoords.y * 2.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);

	vec4 fragposition = gbufferProjectionInverse * currentPosition;
		 fragposition = gbufferModelViewInverse * fragposition;
		 fragposition /= fragposition.w;
		 fragposition.xyz += cameraPosition;

	vec4 previousPosition = fragposition;
		 previousPosition.xyz -= previousCameraPosition;
		 previousPosition = gbufferPreviousModelView * previousPosition;
		 previousPosition = gbufferPreviousProjection * previousPosition;
		 previousPosition /= previousPosition.w;

	vec2 velocity = (currentPosition - previousPosition).st * 0.1f * (1.0 / frameTime) * 0.012;
		 velocity = clamp(velocity, vec2(-maxVelocity), vec2(maxVelocity));

	int samples = 0;
	vec3 color = vec3(0.0f);

	for (int i = -2; i <= 2; ++i) {
		vec2 coord = TexCoords.st + velocity * (float(i) / 2.0);
		if (coord.x > 0.0f && coord.x < 1.0f && coord.y > 0.0f && coord.y < 1.0f) {
			color += GetColorTex(coord).rgb;
			samples++;
		}
	}

	return color / samples;
	
	#else
	
	return GetColorTex(TexCoords);
	
	#endif

}

vec4 SMAA_RT_METRICS = vec4(1.0 / viewWidth, 1.0 / viewHeight, viewWidth, viewHeight);

void SMAAMovc(bvec2 cond, inout vec2 variable, vec2 value) {
    if (cond.x) variable.x = value.x;
    if (cond.y) variable.y = value.y;
}

void SMAAMovc(bvec4 cond, inout vec4 variable, vec4 value) {
    SMAAMovc(cond.xy, variable.xy, value.xy);
    SMAAMovc(cond.zw, variable.zw, value.zw);
}

vec3 doAA(vec2 coord) {

    vec4 a;
	vec4 offset = mad(SMAA_RT_METRICS.xyxy, vec4(1.0, 0.0, 0.0, 1.0), coord.xyxy);
    a.x  = SMAASample(composite, offset.xy).a; // Right
    a.y  = SMAASample(composite, offset.zw).g; // Top
    a.wz = SMAASample(composite, coord).xz; // Bottom / Left

    if (dot(a, vec4(1.0, 1.0, 1.0, 1.0)) < 1e-5) {
	
        vec3 color = MotionBlur(coord.st);
		
        return color;
		
    } else {
	
        bool h = max(a.x, a.z) > max(a.y, a.w); // max(horizontal) > max(vertical)

        // Calculate the blending offsets:
        vec4 blendingOffset = vec4(0.0, a.y, 0.0, a.w);
        vec2 blendingWeight = a.yw;
        SMAAMovc(bvec4(h, h, h, h), blendingOffset, vec4(a.x, 0.0, a.z, 0.0));
        SMAAMovc(bvec2(h, h), blendingWeight, a.xz);
        blendingWeight /= dot(blendingWeight, vec2(1.0, 1.0));

        // Calculate the texture coordinates:
        vec4 blendingCoord = mad(blendingOffset, vec4(SMAA_RT_METRICS.xy, -SMAA_RT_METRICS.xy), texcoord.xyxy);

        // We exploit bilinear filtering to mix current pixel with the chosen
        // neighbor:
        vec3 color  = blendingWeight.x * MotionBlur(blendingCoord.xy);
			 color += blendingWeight.y * MotionBlur(blendingCoord.zw);

        return color;
		
    }
	
}

vec3 convertHDR(vec3 color){

	float mult = 1.0;
	float max = 0.5;
	float min = 1.0;

	vec3 MaxExp = color * (2.0 * mult * max);
	vec3 MinExp = color / (1.5 * mult * min);

	vec3 getHDR = mix(MinExp,MaxExp,color.rgb);

	return getHDR;
	
}

void main() {

	float depth = texture2D(depthtex0, texcoord.st).r;
	vec3 normal = texture2D(gnormal ,texcoord.st).rgb * 2.0 - 1.0;

	vec4 viewPosition  = gbufferProjectionInverse * vec4(texcoord.s * 2.0 - 1.0, texcoord.t * 2.0 - 1.0, 2.0 * depth - 1.0, 1.0f);
		 viewPosition /= viewPosition.w;

	vec3 bloom  = pow(CalculateBloom(2, vec2(0.0f)			  + vec2(0.000f, 0.000f)), vec3(1.0));
		 bloom += pow(CalculateBloom(3, vec2(0.0f, 0.25f)	  + vec2(0.000f, 0.025f)), vec3(0.9));
		 bloom += pow(CalculateBloom(4, vec2(0.125f, 0.25f)	  + vec2(0.025f, 0.025f)), vec3(0.8));
		 bloom += pow(CalculateBloom(5, vec2(0.1875f, 0.25f)  + vec2(0.050f, 0.025f)), vec3(0.7));
		 bloom += pow(CalculateBloom(6, vec2(0.21875f, 0.25f) + vec2(0.075f, 0.025f)), vec3(0.6));
		 bloom += pow(CalculateBloom(7, vec2(0.25f, 0.25f)	  + vec2(0.100f, 0.025f)), vec3(0.5));
		 
    #ifdef SMAA
		vec3 color = doAA(texcoord.st).rgb;
	#else
		vec3 color = MotionBlur(texcoord.st).rgb;
	#endif
	
	float luma = 1.0f;//dot(color.rgb, vec3(0.2125f, 0.7154f, 0.0721f));
	//	  luma = exp(luma);
	
	//color = convertHDR(color);
		  
/* DRAWBUFFERS:03 */
	
    gl_FragData[0] = vec4(color, luma);
	gl_FragData[1] = vec4(pow(bloom, vec3(1.0f / 2.2f)) * 0.01, 1.0f);
	
}
