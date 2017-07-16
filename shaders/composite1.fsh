#version 120

const bool gcolorMipmapEnabled = true;

varying vec4 texcoord;

uniform sampler2D gcolor;
uniform sampler2D gdepthtex;
uniform sampler2D depthtex1;

uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;

uniform float far;
uniform float near;

uniform float rainStrength;
uniform ivec2 eyeBrightnessSmooth;
uniform mat4 gbufferProjectionInverse;

float pw = 1.0 / viewWidth;
float ph = 1.0 / viewHeight;
 
const vec2 bloom_offsets[49] = vec2[49]  (vec2(-3,-3),vec2(-2,-3),vec2(-1,-3),vec2(0,-3),vec2(1,-3),vec2(2,-3),vec2(3,-3),
									vec2(-3,-2),vec2(-2,-2),vec2(-1,-2),vec2(0,-2),vec2(1,-2),vec2(2,-2),vec2(3,-2),
									vec2(-3,-1),vec2(-2,-1),vec2(-1,-1),vec2(0,-1),vec2(1,-1),vec2(2,-1),vec2(3,-1),
									vec2(-3, 0),vec2(-2, 0),vec2(-1, 0),vec2(0, 0),vec2(1, 0),vec2(2, 0),vec2(3, 0),
									vec2(-3, 1),vec2(-2, 1),vec2(-1, 1),vec2(0, 1),vec2(1, 1),vec2(2, 1),vec2(3, 1),
									vec2(-3, 2),vec2(-2, 2),vec2(-1, 2),vec2(0, 2),vec2(1, 2),vec2(2, 2),vec2(3, 2),
									vec2(-3, 3),vec2(-2, 3),vec2(-1, 3),vec2(0, 3),vec2(1, 3),vec2(2, 3),vec2(3, 3)
									);


vec3 makeBloom(float lod,vec2 offset){

        vec3 bloom = vec3(0);
        float scale = pow(2,lod);
        vec2 coord = (texcoord.xy-offset)*scale;

        if (coord.x > -0.1 && coord.y > -0.1 && coord.x < 1.1 && coord.y < 1.1){
	  for (int i = 0; i < 49; i++) {
	    float wg = exp(3-length(bloom_offsets[i]));
	    vec2 bcoord = (texcoord.xy-offset+bloom_offsets[i]*pw*vec2(1.0,aspectRatio))*scale;
	    if (wg > 0) {
              vec3 bloomdata = pow(texture2D(gcolor,bcoord).rgb,vec3(2.2))*wg;
	      float brightness = dot(bloomdata.rgb, vec3(0.2126, 0.7152, 0.0722));
              float luma = max(brightness - 0.25, 0.0);
              bloom += bloomdata * luma / (luma + 0.4f);
            }
	  }
	}

	bloom /= 49;
	return bloom;

}

void CalculateRainFog(inout vec3 color)
{

        vec4 fragposition = gbufferProjectionInverse * vec4(texcoord.s * 2.0f - 1.0f, texcoord.t * 2.0f - 1.0f, 2.0f * texture2D(depthtex1, texcoord.st).x - 1.0f, 1.0f);
	     fragposition /= fragposition.w;

        vec3 fogColor = vec3(0.7,0.8,0.8) * 0.055f;

	float fogDensity = 0.00018f * rainStrength;
	      fogDensity *= mix(0.0f, 1.0f, pow(eyeBrightnessSmooth.y / 240.0f, 6.0f));

	float visibility = 1.0f / (pow(exp(distance(fragposition.xyz, vec3(0.0f)) * fogDensity), 1.0f));
	float fogFactor = 1.0f - visibility;
		  fogFactor = clamp(fogFactor, 0.0f, 1.0f);
		  fogFactor = mix(fogFactor, 1.0f, 0.8f * rainStrength);

	color = mix(color, fogColor, vec3(fogFactor));

}

float GetDepthLinear(in vec2 coord) {

	return 2.0f * near * far / (far + near - (2.0f * texture2D(gdepthtex, coord).x - 1.0f) * (far - near));
}

void CalculateScatteringFog(inout vec3 color)
{

	vec3 fogColor = pow(vec3(0.2,0.6,1.0), vec3(1.55f));

	float fogFactor = GetDepthLinear(texcoord.st) / 1500.0f;

        fogFactor = fogFactor - pow(fogFactor,1.8f);
	fogFactor *= pow(eyeBrightnessSmooth.y / 240.0f, 1.2f);

	//add scattered low frequency light
	color += fogColor * fogFactor * 0.4f;

}

void CalculateMieFog(inout vec3 color) {

	vec3 fogColor = vec3(0.6,0.7,1.0);

	float fogFactor = GetDepthLinear(texcoord.st) / 800.0f;
	      fogFactor = min(fogFactor, 0.7f);
	      fogFactor = sin(fogFactor * 3.1415 / 2.0f);
	      fogFactor = pow(fogFactor, 0.5f);
              fogFactor *= 0.62f;

	color.rgb = mix(color.rgb, fogColor * 0.002f, vec3(fogFactor));
	color.rgb *= mix(vec3(1.0f), pow(fogColor,vec3(4)), vec3(fogFactor));

}

void main() {

   vec3 blur = vec3(0);

	blur += makeBloom(2,vec2(0,0));
	blur += makeBloom(3,vec2(0.3,0));
	blur += makeBloom(4,vec2(0,0.3));
	blur += makeBloom(5,vec2(0.1,0.3));
	blur += makeBloom(6,vec2(0.2,0.3));
	blur += makeBloom(7,vec2(0.3,0.3));

        blur = clamp(pow(blur,vec3(1.0/2.2)),0.0,1.0);
   
   vec3 color = texture2D(gcolor,texcoord.st).rgb;
   
   CalculateMieFog(color);
   CalculateScatteringFog(color);
   CalculateRainFog(color);

/* DRAWBUFFERS:30 */
	gl_FragData[0] = vec4(blur,1.0);
	gl_FragData[1] = vec4(color,1.0);

}
