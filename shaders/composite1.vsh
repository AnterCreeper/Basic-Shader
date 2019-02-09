#version 120
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

//Switch of effects
//#define MODERN

//AA Properties
#define LOW    0
#define MEDIUM 1
#define HIGH   2
#define ULTRA  3

#define QUALITY MEDIUM //[LOW MEDIUM HIGH ULTRA]

//Please read the license before change things below this line !!

#if QUALITY == LOW
#define SMAA_THRESHOLD 0.15
#define SMAA_MAX_SEARCH_STEPS 4
#define SMAA_DISABLE_DIAG_DETECTION
#define SMAA_DISABLE_CORNER_DETECTION
#elif QUALITY == MEDIUM
#define SMAA_THRESHOLD 0.1
#define SMAA_MAX_SEARCH_STEPS 8
#define SMAA_DISABLE_DIAG_DETECTION
#define SMAA_DISABLE_CORNER_DETECTION
#elif QUALITY == HIGH
#define SMAA_THRESHOLD 0.1
#define SMAA_MAX_SEARCH_STEPS 16
#define SMAA_MAX_SEARCH_STEPS_DIAG 8
#define SMAA_CORNER_ROUNDING 25
#elif QUALITY == ULTRA
#define SMAA_THRESHOLD 0.05
#define SMAA_MAX_SEARCH_STEPS 32
#define SMAA_MAX_SEARCH_STEPS_DIAG 16
#define SMAA_CORNER_ROUNDING 25
#endif

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;

uniform float sunAngle;
uniform float rainStrength;
uniform float viewWidth;
uniform float viewHeight;

uniform int worldTime;

varying vec3 sunVec;
varying vec3 moonVec;
varying vec3 upVec;

varying vec3 lightVector;

varying float SkyBrightness;
varying float SunBrightness;

varying float fogdistance;

varying float SdotU;
varying float MdotU;
varying float sunVisibility;
varying float moonVisibility;

varying vec4 texcoord;
varying vec2 pixcoord;

varying vec4 offset[3];

#include "/lib/Global.vert"

#define lerp(a, b, t) mix(a, b, t)
#define saturate(a) clamp(a, 0.0, 1.0)
#define mad(a, b, c) (a * b + c)

vec4 SMAA_RT_METRICS = vec4(1.0 / viewWidth, 1.0 / viewHeight, viewWidth, viewHeight);

void main() {

	doCalculateTime();
	doCalculateColor();
	
	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0;
	pixcoord = texcoord.st * SMAA_RT_METRICS.zw;

    // We will use these offsets for the searches later on (see @PSEUDO_GATHER4):
    offset[0] = mad(SMAA_RT_METRICS.xyxy, vec4(-0.25, -0.125,  1.25, -0.125), texcoord.xyxy);
    offset[1] = mad(SMAA_RT_METRICS.xyxy, vec4(-0.125, -0.25, -0.125,  1.25), texcoord.xyxy);

    // And these for the searches, they indicate the ends of the loops:
    offset[2] = mad(SMAA_RT_METRICS.xxyy,
                    vec4(-2.0, 2.0, -2.0, 2.0) * float(SMAA_MAX_SEARCH_STEPS),
                    vec4(offset[0].xz, offset[1].yw));

	if (sunAngle < 0.5f) {
		lightVector = normalize(sunPosition);
	} else {
		lightVector = normalize(moonPosition);
	}
	
	sunVec  = normalize(sunPosition);
	moonVec = normalize(-sunPosition);
	upVec   = normalize(upPosition);
	
	SdotU = dot(sunVec,upVec);
	MdotU = dot(moonVec,upVec);
	sunVisibility  = pow(clamp(SdotU+0.1,0.0,0.1) / 0.1, 2.0);
	moonVisibility = pow(clamp(MdotU+0.1,0.0,0.1) / 0.1, 2.0);
	
	SkyBrightness  = 0.02f * (1.0f - rainStrength);
	SkyBrightness += 1.20f * (1.0f + rainStrength * 0.99f) * timeNoon;
	SkyBrightness += 0.45f * (1.0f + rainStrength * 0.99f) * timeSunriseSunset;
	SkyBrightness += 0.20f * (1.0f + rainStrength * 0.99f) * timeMidnight;
	
	SunBrightness  = 3.25f * (1.0f - rainStrength * 0.95f);
	SunBrightness += 1.50f * (1.0f - rainStrength * 0.95f) * timeNoon;
	SunBrightness += 2.50f * (1.0f - rainStrength * 0.95f) * timeSunriseSunset;
	
	// fog distance.
	float fog_sunrise  = 100.0 * timeSunrise  * (1.0 - rainStrength*1.0);
	float fog_noon     = 150.0 * timeNoon     * (1.0 - rainStrength*1.0);
	float fog_sunset   = 200.0 * timeSunset   * (1.0 - rainStrength*1.0);
	float fog_midnight = 75.0  * timeMidnight * (1.0 - rainStrength*1.0);
	float fog_rain     = 35.0  * rainStrength;
	
	fogdistance = (fog_sunrise + fog_noon + fog_sunset + fog_midnight + fog_rain) * 0.80f;
	
}