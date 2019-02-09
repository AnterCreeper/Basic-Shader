//Shadow Lib Version v2.1

//This file is part of Basic Shader.
//Read LICENSE First at composite.fsh

//PCSS Properties
#define LIGHT_SIZE                  12
#define MIN_PENUMBRA_SIZE           0.175
#define BLOCKER_SEARCH_SAMPLES_HALF 7
#define PCF_SIZE_HALF               2      //[1 2 4 7]

vec4 calcShadowCoordinate(in vec4 fragPosition, in vec3 normal) {

    vec4 shadowCoord = shadowModelView * fragPosition;
    shadowCoord = shadowProjection * shadowCoord;
    shadowCoord /= shadowCoord.w;

    float dist = sqrt(shadowCoord.x * shadowCoord.x + shadowCoord.y * shadowCoord.y);
	float distortFactor = (1.0f - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;
	
	shadowCoord.xy *= 1.0f / distortFactor;
    shadowCoord = 0.5 + 0.5 * shadowCoord;    //take it from [-1, 1] to [0, 1]
	
	float NdotL = dot(normal, lightVector);
	float depthBias = distortFactor * distortFactor * (0.0097297 * tan(acos(NdotL)) + 0.01729729729) / 2.8888888;
   
    return vec4(shadowCoord.xyz, dist - depthBias);
	
}

//Implements the Percentage-Closer Soft Shadow algorithm, as defined by NVIDIA
//Implemented by DethRaid - github.com/DethRaid

float calcPenumbraSize(vec3 shadowCoord, vec3 normal) {

	float dFragment = shadowCoord.z;
	float dBlocker = 0;
	float penumbra = 0;
	
	float NdotL = dot(normal, lightVector);
	float dist = length(shadowCoord.xy);
    float distortFactor = (1.0f - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;
    float depthBias = distortFactor * distortFactor * (0.0097297 * tan(acos(NdotL)) + 0.01729729729) * 0.3461538461538463;

	float temp;
	float numBlockers = 0;
    float searchSize = LIGHT_SIZE * (dFragment - 9.5) / dFragment;

    for(int i = -BLOCKER_SEARCH_SAMPLES_HALF; i <= BLOCKER_SEARCH_SAMPLES_HALF; i++) {
        for(int j = -BLOCKER_SEARCH_SAMPLES_HALF; j <= BLOCKER_SEARCH_SAMPLES_HALF; j++) {
			temp = texture2D(shadow, shadowCoord.st + (vec2(i, j) * searchSize / (shadowMapResolution * 25))).r - depthBias / 5;
			if(dFragment - temp > 0.0015) {
                dBlocker += temp;
                numBlockers++;
            }
        }
	}

    if(numBlockers > 0.1) {
		dBlocker /= numBlockers;
		penumbra = (dFragment - dBlocker) * LIGHT_SIZE / dFragment;
	}

    return max(penumbra, MIN_PENUMBRA_SIZE);
	
}

//vec4 getShadowing(in vec4 fragPosition, in vec3 fragNormal) {
float getShadowing(in vec4 fragPosition, in vec3 fragNormal) {

    vec4 shadowCoord = calcShadowCoordinate(fragPosition, fragNormal);
    float visibility = 1.0;
    float penumbraSize = 0.35;    // whoo magic number!
	
	//vec3 shadecolor = vec3(0.0f);
	
    #ifdef PCSS
      penumbraSize = calcPenumbraSize(shadowCoord.xyz, fragNormal);
    #endif
	
    float numBlockers = 0.0;
    float numSamples = 0.0;

    float diffthresh = shadowCoord.w * 1.0f + 0.10f;
	diffthresh *= 3.0f / (shadowMapResolution / 2048.0f);

	for(int i = -PCF_SIZE_HALF; i <= PCF_SIZE_HALF; i++) {
        for(int j = -PCF_SIZE_HALF; j <= PCF_SIZE_HALF; j++) {
            vec2 sampleCoord = vec2(i, j) / shadowMapResolution;
			sampleCoord *= penumbraSize;
			sampleCoord *= 1.0f + ambient_noise() * 4.0f;
            float shadowDepth = texture2D(shadow, shadowCoord.st + sampleCoord).r;
			//shadecolor += texture2D(shadowcolor0, shadowCoord.st + sampleCoord).rgb;
            numBlockers += step(shadowCoord.z - shadowDepth, 0.00018f);
            numSamples++;
        }
	}

    visibility = max(numBlockers / numSamples, 0);
	
	//shadecolor /= numSamples;
	//vec3 shadowval = texture2D(shadowcolor1, shadowCoord.st).rgb;
	
    return visibility;//vec4(mix(vec3(1.0f), shadecolor, shadowval.b), visibility);

}