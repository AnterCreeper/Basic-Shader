//Shadow Lib Version v1.1

//This file is part of Basic Shader.
//Read LICENSE First at composite.fsh

//HBAO Properties
#define NVIDIA_HBAO                 1     //1 means enable, 0 means disable

//PCSS Properties
#define LIGHT_SIZE                  12
#define MIN_PENUMBRA_SIZE           0.2
#define BLOCKER_SEARCH_SAMPLES_HALF 3
#define PCF_SIZE_HALF               5

float AmbientDynamic() {
	
	float value = 1.0;
		  value *= abs(sin(frameTimeCounter * 0.01 * 1.2));
		  value *= abs(cos(frameTimeCounter * 0.01 * 0.5));
		  value *= abs(sin(frameTimeCounter * 0.01 * 2.0));
	
	// Raining.
	value = mix(value, 0.2, rainStrength);
		  
	return value;
	
}	

float GetDepth(in vec2 coord) {
	return texture2D(gdepthtex, coord.st).x;
}

vec4 GetViewSpacePosition(in vec2 coord) {
	float depth = GetDepth(coord);
	vec4 fragposition = gbufferProjectionInverse * vec4(coord.s * 2.0 - 1.0, coord.t * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
		 fragposition /= fragposition.w;

	return fragposition;
}

vec2 rotateDirection(vec2 angle, vec2 rotation) {
    return vec2(angle.x * rotation.x - angle.y * rotation.y,
                angle.x * rotation.y + angle.y * rotation.x);
}

vec3 CalculateNoisePattern(const float size) {
	vec2 coord = texcoord.st;

	coord *= vec2(viewWidth, viewHeight);
	coord = mod(coord, vec2(size));
	coord /= noiseTextureResolution;

	return texture2D(noisetex, coord).xyz;
}

float calc_ao(in vec2 coord, in vec3 normal) {

	const float samplingRadius = 0.6;
	const int samplingDirections = 8;
	const float samplingStep = 0.004;
	const int numSampleSteps = 4;
	const float tangentBias = 0.2;
	const float PI = 3.14159265;

	vec3 viewPosition = GetViewSpacePosition(coord).xyz;
	vec3 viewNormal = normal;

	float total = 0.0;
	float sampleDirectionIncrement = 2.0 * PI / float(samplingDirections);

	vec2 randomRotation = CalculateNoisePattern(3).xy;

	for(int i = 0; i < samplingDirections; i++) {
		//Holding off jittering as long as possible.
		float samplingAngle = i * sampleDirectionIncrement; //Azimuth angle theta in the paper.
		vec2 sampleDirection = vec2(cos(samplingAngle * randomRotation.x), sin(samplingAngle * randomRotation.y));

		#if NVIDIA_HBAO == 1
			//Random Rotation Defined by NVIDIA
			sampleDirection = rotateDirection(vec2(cos(samplingAngle), sin(samplingAngle)), randomRotation.xy);
			sampleDirection.y = -sampleDirection.y;
		#endif

		float tangentAngle = acos(dot(vec3(sampleDirection, 0.0), viewNormal)) - (0.5 * PI) + tangentBias;
		float horizonAngle = tangentAngle;
		vec3 lastDiff = vec3(0.0);

		for(int j = 0; j < numSampleSteps; j++) {
			//Marching Time
			vec2 sampleOffset = float(j + 1) * samplingStep * sampleDirection;
			vec2 offset = coord + sampleOffset;

			vec3 offsetViewPosition = GetViewSpacePosition(offset).xyz;
			vec3 differential = offsetViewPosition - viewPosition;

			if(length(differential) < samplingRadius) { //skip samples outside local sample space
				lastDiff = differential;
				float elevationAngle = atan(differential.z / length(differential.xy));
				horizonAngle = max(horizonAngle, elevationAngle);
			}
		}
		float normalDiff = length(lastDiff) / samplingRadius;
		float atten = 1.0 - pow(normalDiff, 2);

		float AO = clamp(atten * (sin(horizonAngle) - sin(tangentAngle)), 0.0, 1.0);
		total += 1.0 - AO;
	}
	total /= samplingDirections;

	return total;
}

vec4 calcShadowCoordinate(in vec4 fragPosition, in vec3 normal) {

    vec4 shadowCoord = shadowModelView * fragPosition;
    shadowCoord = shadowProjection * shadowCoord;
    shadowCoord /= shadowCoord.w;

    float dist = sqrt(shadowCoord.x * shadowCoord.x + shadowCoord.y * shadowCoord.y);
	float distortFactor = dist * SHADOW_MAP_BIAS + 0.20f;
	
	shadowCoord.xy *= 1.0f / distortFactor;
    shadowCoord = 0.5 + 0.5 * shadowCoord;    //take it from [-1, 1] to [0, 1]
	
	float NdotL = dot(normal, lightVector);
	float depthBias = distortFactor*distortFactor*(0.0097297*tan(acos(NdotL)) + 0.01729729729)/2.8888888;
   
    return vec4(shadowCoord.xyz, dist-depthBias);
	
}

//Implements the Percentage-Closer Soft Shadow algorithm, as defined by NVIDIA
//Implemented by DethRaid - github.com/DethRaid

float calcPenumbraSize(vec3 shadowCoord, vec3 normal) {

	float dFragment = shadowCoord.z;
	float dBlocker = 0;
	float penumbra = 0;
	
	float NdotL = dot(normal, lightVector);
	float dist = sqrt(shadowCoord.x * shadowCoord.x + shadowCoord.y * shadowCoord.y);
    float distortFactor = dist * SHADOW_MAP_BIAS + 0.20f;
    float depthBias = distortFactor*distortFactor*(0.0097297*tan(acos(NdotL)) + 0.01729729729)/2.8888888;

	float temp;
	float numBlockers = 0;
    float searchSize = LIGHT_SIZE * (dFragment - 9.5) / dFragment;

    for( int i = -BLOCKER_SEARCH_SAMPLES_HALF; i <= BLOCKER_SEARCH_SAMPLES_HALF; i++ ) {
        for( int j = -BLOCKER_SEARCH_SAMPLES_HALF; j <= BLOCKER_SEARCH_SAMPLES_HALF; j++ ) {
			temp = texture2D(shadow, shadowCoord.st + (vec2(i, j) * searchSize / (shadowMapResolution * 25))).r - depthBias / 5;
		if( dFragment - temp > 0.0015 ) {
                dBlocker += temp;
                numBlockers += 1.0;
            }
        }
	}

    if( numBlockers > 0.1 ) {
		dBlocker /= numBlockers;
		penumbra = (dFragment - dBlocker) * LIGHT_SIZE / dFragment;
	}

    return max(penumbra, MIN_PENUMBRA_SIZE);
	
}

float calcShadowing(in vec4 fragPosition, in vec3 fragNormal) {

    vec4 shadowCoord = calcShadowCoordinate(fragPosition, fragNormal);
    float visibility = 1.0;
    float penumbraSize = 0.35;    // whoo magic number!
	
    #ifdef PCSS
      penumbraSize = calcPenumbraSize(shadowCoord.xyz, fragNormal);
    #endif
	
    float numBlockers = 0.0;
    float numSamples = 0.0;

    float diffthresh = shadowCoord.w * 1.0f + 0.10f;
	diffthresh *= 3.0f / (shadowMapResolution / 2048.0f);

	for(int i = -PCF_SIZE_HALF; i <= PCF_SIZE_HALF; i++) {
        for(int j = -PCF_SIZE_HALF; j <= PCF_SIZE_HALF; j++) {
            vec2 sampleCoord = vec2( j, i ) / shadowMapResolution;
			sampleCoord *= penumbraSize;
			sampleCoord *= 1.0f + AmbientDynamic() * 2.0f;
            float shadowDepth = texture2D(shadow, shadowCoord.st + sampleCoord).r;
            numBlockers += step(shadowCoord.z - shadowDepth, 0.00018f);
            numSamples++;
        }
	}

    visibility = max(numBlockers / numSamples, 0);

    return visibility;

}