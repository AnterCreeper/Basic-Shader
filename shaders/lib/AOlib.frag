//Ambient Occlusion Part Version v1.0

//This file is part of Basic Shader.
//Read LICENSE First at composite.fsh

float GetDepth(in vec2 coord) {
	return texture2D(gdepthtex, coord.st).x;
}

vec2 rotateDirection(vec2 angle, vec2 rotation) {
	return vec2(angle.x * rotation.x - angle.y * rotation.y,
                angle.x * rotation.y + angle.y * rotation.x);
}

vec4 GetViewSpacePosition(in vec2 coord) {

	float depth = GetDepth(coord);
	vec4 fragposition  = gbufferProjectionInverse * vec4(coord.s * 2.0 - 1.0, coord.t * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
	     fragposition /= fragposition.w;
	return fragposition;
	
}

vec3 CalculateNoisePattern(vec2 offset, float size) {

	vec2 coord = texcoord.st;
		 coord *= vec2(viewWidth, viewHeight);
		 coord  = mod(coord + offset, vec2(size));
		 coord /= noiseTextureResolution;

	return texture2D(noisetex, coord).xyz;
	
}

float getAO(in vec2 coord, in vec3 viewNormal) {

	const int numSampleSteps     = 4;
	const int samplingDirections = 8;
	const float tangentBias      = 0.2;
	const float samplingStep     = 0.004;
	const float samplingRadius   = 0.6;

	float total = 0.0;
	float sampleDirectionIncrement = 2.0 * pi / float(samplingDirections);

	vec3 viewPosition   = GetViewSpacePosition(coord).xyz;
	vec2 randomRotation = CalculateNoisePattern(vec2(0.0f), 3.0).xy;

	for(int i = 0; i < samplingDirections; i++) {
	
		//Holding off jittering as long as possible.
		float samplingAngle = i * sampleDirectionIncrement; //Azimuth angle theta in the paper.

		//Random Rotation Defined by NVIDIA
		vec2 sampleDirection = rotateDirection(vec2(cos(samplingAngle), sin(samplingAngle)), randomRotation.xy);
		sampleDirection.y = -sampleDirection.y;

		float tangentAngle = acos(dot(vec3(sampleDirection, 0.0), viewNormal)) - (0.5 * pi) + tangentBias;
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