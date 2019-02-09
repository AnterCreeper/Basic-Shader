#version 120

varying vec4 texcoord;

varying float sunvisibility;

uniform sampler2D depthtex0;

uniform int worldTime;

uniform mat4 gbufferProjection;
uniform vec3 sunPosition;

uniform float rainStrength;
uniform float sunAngle;

uniform float viewWidth;
uniform float viewHeight;

#include "/lib/Global.vert"

float pixelwidth  = 1.0 / viewWidth;
float pixelheight = 1.0 / viewHeight;

void main() {

	doCalculateTime();
	doCalculateColor();
	
	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0;
	
	float n = 0;
	
	vec4 sunP = vec4(sunPosition, 1.0f) * gbufferProjection;
		 sunP = vec4(sunP.xyz / sunP.w, 1.0);
	vec2 lightPos = sunP.xy / sunP.z * 0.5f + 0.5f;
		
	if (lightPos.x >= 0.0 && lightPos.x <= 1.0 &&
	    lightPos.y >= 0.0 && lightPos.y <= 1.0) {
		for (int i = -5; i <= 5; i++) {
			for (int j = -5; j <= 5; j++) {
				float depth = texture2DLod(depthtex0, lightPos.st + vec2(pixelwidth * i, pixelheight * j), 0.0).r;
				sunvisibility += float(depth > 0.9999);
				n++;
			}
		}
		sunvisibility /= n;
	}
	
	float shortestDis = min(min(lightPos.s, 1.0 - lightPos.s),
							min(lightPos.t, 1.0 - lightPos.t));
							
	sunvisibility *= smoothstep(0.0, 0.2, clamp(shortestDis, 0.0, 0.2));
	
}
