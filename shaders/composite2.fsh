#version 120
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

//Switch of effects (Please set the switch at composite1.fsh both.)
#define HBAO
#define MOTION_BLUR

#define SCALE
//#define WHITE_BLOCK

//Properties of effects
const bool gcolorMipmapEnabled = true;

//Please read the license before change things below this line !!

varying vec4 texcoord;

uniform sampler2D gcolor;
uniform sampler2D gaux3;
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
uniform vec3 sunPosition;
uniform ivec2 eyeBrightnessSmooth;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

float pw = 1.0 / viewWidth;
float ph = 1.0 / viewHeight;

//0:gcolor  = albedo
//2:gnormal = materials,iswater
//4:gaux1   = normals
//5:gaux2   = specular
//6:gaux3   = lightmap
//7:gaux4   = lmcoord

const vec2 bloom_offsets[49] = vec2[49]  (vec2(-3,-3),vec2(-2,-3),vec2(-1,-3),vec2(0,-3),vec2(1,-3),vec2(2,-3),vec2(3,-3),
									vec2(-3,-2),vec2(-2,-2),vec2(-1,-2),vec2(0,-2),vec2(1,-2),vec2(2,-2),vec2(3,-2),
									vec2(-3,-1),vec2(-2,-1),vec2(-1,-1),vec2(0,-1),vec2(1,-1),vec2(2,-1),vec2(3,-1),
									vec2(-3, 0),vec2(-2, 0),vec2(-1, 0),vec2(0, 0),vec2(1, 0),vec2(2, 0),vec2(3, 0),
									vec2(-3, 1),vec2(-2, 1),vec2(-1, 1),vec2(0, 1),vec2(1, 1),vec2(2, 1),vec2(3, 1),
									vec2(-3, 2),vec2(-2, 2),vec2(-1, 2),vec2(0, 2),vec2(1, 2),vec2(2, 2),vec2(3, 2),
									vec2(-3, 3),vec2(-2, 3),vec2(-1, 3),vec2(0, 3),vec2(1, 3),vec2(2, 3),vec2(3, 3)
									);

vec3 GetColorTex(vec2 coord){
	#ifdef SCALE
	 return texture2D(gcolor,coord).rgb * 100;
	#else
	 return texture2D(gcolor,coord).rgb;
	#endif
}

float calcluma(vec3 color) {
	return dot(color.rgb,vec3(0.2125f, 0.7154f, 0.0721f));
}

#define OFFSETS 0.4f

vec3 makeBloom(float lod,vec2 offset){

	vec3 bloom = vec3(0);
    float scale = pow(2,lod);
    vec2 coord = (texcoord.xy-offset)*scale;

    if (coord.x > -0.1 && coord.y > -0.1 && coord.x < 1.1 && coord.y < 1.1){
	  for (int i = 0; i < 49; i++) {
	    float wg = exp(3-length(bloom_offsets[i]));
	    vec2 bcoord = (texcoord.xy-offset+bloom_offsets[i]*pw*vec2(1.0,aspectRatio)*OFFSETS)*scale;
	    if (wg > 0) {
            vec3 bloomdata = pow(GetColorTex(bcoord),vec3(2.2))*wg;
	        //float luma = calcluma(bloomdata.rgb);
            //bloomdata = bloomdata * luma / (luma + 1.0f) * 2.0f;
            bloom += bloomdata;
        }
      }
    }

    bloom /= 49;
    return bloom;

}

float GetDepthLinear(in vec2 coord) {
    return 2.0f * near * far / (far + near - (2.0f * texture2D(gdepthtex, coord).x - 1.0f) * (far - near));
}

void CalculateRainFog(inout vec3 color) {

    vec4 fragposition = gbufferProjectionInverse * vec4(texcoord.s * 2.0f - 1.0f, texcoord.t * 2.0f - 1.0f, 2.0f * texture2D(depthtex1, texcoord.st).x - 1.0f, 1.0f);
         fragposition /= fragposition.w;

    vec3 fogColor = vec3(0.12f);

    float fogDensity = 0.04f * rainStrength;
	      fogDensity *= mix(0.0f, 1.0f, pow(eyeBrightnessSmooth.y / 240.0f, 6.0f));

    float visibility = 1.0f / (pow(exp(distance(fragposition.xyz, vec3(0.0f)) * fogDensity), 1.0f));
    float fogFactor = 1.0f - visibility;
	      fogFactor = clamp(fogFactor, 0.0f, 1.0f);
	      fogFactor = mix(fogFactor, 1.0f, 0.8f * rainStrength);

    color = mix(color, fogColor, vec3(fogFactor));

}

void CalculateScatteringFog(inout vec3 color){

    vec3 fogColor = pow(vec3(0.2,0.6,1.0), vec3(1.55f));

    float fogFactor = GetDepthLinear(texcoord.st) / 1500.0f;

    fogFactor = fogFactor - pow(fogFactor,1.8f);
    fogFactor *= pow(eyeBrightnessSmooth.y / 240.0f, 1.2f);

    //add scattered low frequency light
    color += fogColor * fogFactor * 0.08f;

}

void CalculateMieFog(inout vec3 color) {

    vec3 fogColor = vec3(0.6,0.7,1.0);

    float fogFactor = GetDepthLinear(texcoord.st) / 800.0f;
		fogFactor = min(fogFactor, 0.7f);
		fogFactor = sin(fogFactor * 3.1415 / 2.0f);
		fogFactor = pow(fogFactor, 0.5f);
		fogFactor *= 0.0068f;

    color.rgb = mix(color.rgb, fogColor * 0.0042f, vec3(fogFactor));
    color.rgb *= mix(vec3(1.0f), pow(fogColor,vec3(4)), vec3(fogFactor));

}

#define MOTIONBLUR_THRESHOLD 0.01
#define MOTIONBLUR_MAX 0.21
#define MOTIONBLUR_STRENGTH 0.5
#define MOTIONBLUR_SAMPLE 5

vec3 motionBlur(vec3 color, vec2 uv, vec4 viewPosition) {
	vec4 worldPosition = gbufferModelViewInverse * viewPosition + vec4(cameraPosition, 0.0);
	vec4 prevClipPosition = gbufferPreviousProjection * gbufferPreviousModelView * (worldPosition - vec4(previousCameraPosition, 0.0));
	vec4 prevNdcPosition = prevClipPosition / prevClipPosition.w;
	vec2 prevUv = (prevNdcPosition * 0.5 + 0.5).st;
	vec2 delta = uv - prevUv;
	float dist = length(delta);
	if(dist > MOTIONBLUR_THRESHOLD)
	{
		delta = normalize(delta);
		dist = min(dist, MOTIONBLUR_MAX) - MOTIONBLUR_THRESHOLD;
		dist *= MOTIONBLUR_STRENGTH;
		delta *= dist / float(MOTIONBLUR_SAMPLE);
		int sampleNum = 1;
		for(int i = 0; i < MOTIONBLUR_SAMPLE; i++)
		{
			uv += delta;
			if(uv.s <= 0.0 || uv.s >= 1.0 || uv.t <= 0.0 || uv.t >= 1.0)
				break;
			color += GetColorTex(uv).rgb;
			sampleNum++;
		}
		color /= float(sampleNum);
	}
	return color;
}

void main() {

	float ishand = texture2D(gaux3,texcoord.st).b;
	float depth  = texture2D(depthtex0, texcoord.st).r;
	
	vec4 viewPosition  = gbufferProjectionInverse * vec4(texcoord.s * 2.0 - 1.0, texcoord.t * 2.0 - 1.0, 2.0 * depth - 1.0, 1.0f);
		 viewPosition /= viewPosition.w;

    vec3 blur = vec3(0.0f);
 
 	     blur += pow(makeBloom(2,vec2(0,0))     * 1.36f, vec3(1.0));
	     blur += pow(makeBloom(3,vec2(0.3,0))   * 1.55f, vec3(0.9));
	     blur += pow(makeBloom(4,vec2(0,0.3))   * 0.40f, vec3(0.8));
	     blur += pow(makeBloom(5,vec2(0.1,0.3)) * 0.21f, vec3(0.7));
	     blur += pow(makeBloom(6,vec2(0.2,0.3)) * 0.23f, vec3(0.6));
	     blur += pow(makeBloom(7,vec2(0.3,0.3)) * 0.25f, vec3(0.5));

         blur = clamp(pow(blur / 4.0f,vec3(1.0/2.2)),0.0,1.0);
   
    vec3 color = GetColorTex(texcoord.st).rgb;
	
	#ifdef MOTION_BLUR
	 if (ishand < 0.9) color = motionBlur(color, texcoord.st, viewPosition);
	#endif
	
    #ifdef HBAO

     #define BLURFACTOR 1.2

     float ao  = texture2DLod(gcolor,texcoord.st                             , BLURFACTOR).a * 0.6;
		   ao += texture2DLod(gcolor,texcoord.st + vec2( pw, ph) * BLURFACTOR, BLURFACTOR).a * 0.1;
		   ao += texture2DLod(gcolor,texcoord.st + vec2(-pw, ph) * BLURFACTOR, BLURFACTOR).a * 0.1;
		   ao += texture2DLod(gcolor,texcoord.st + vec2( pw,-ph) * BLURFACTOR, BLURFACTOR).a * 0.1;
		   ao += texture2DLod(gcolor,texcoord.st + vec2(-pw,-ph) * BLURFACTOR, BLURFACTOR).a * 0.1;
	
	 #ifdef WHITE_BLOCK
      const float steep = 0.08f;
	 #else
	  const float steep = 0.14f;
	 #endif
	 
	 color.rgb *= (min(ao + steep ,1.0f) - steep);
	 
    #endif
	
    //Add fog.
    CalculateMieFog(color);
    CalculateScatteringFog(color);
    CalculateRainFog(color);
	
/* DRAWBUFFERS:03 */

	//0:gcolor  = albedo
	//2:gnormal = materials,iswater,isentity
	//4:gaux1   = normals
	//5:gaux2   = specular
	//6:gaux3   = lmcoord,ishand
	
    gl_FragData[0] = vec4(color, 1.0);
    gl_FragData[1] = vec4(blur,  1.0);

}
