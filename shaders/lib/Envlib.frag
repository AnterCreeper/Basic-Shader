//Environment Lib Version v2.1

//This file is part of Basic Shader.
//Read LICENSE First at composite.fsh

const float pi = 3.141592653589793238462643383279502884197169;

vec4 GetScreenSpacePosition(in vec2 coord) {
	float depth = texture2D(depthtex1,coord.st).x;
	vec4 fragposition = gbufferProjectionInverse * vec4(coord.s * 2.0f - 1.0f, coord.t * 2.0f - 1.0f, 2.0f * depth - 1.0f, 1.0f);
		 fragposition /= fragposition.w;
	return fragposition;
}

float CalculateSunglow(in vec4 viewSpacePosition) {
	float sunglow = max(dot(normalize(viewSpacePosition.xyz), lightVector) - 0.01f, 0.0f);
	      sunglow = pow(sunglow * 0.8f, 4.0f);
	
	return sunglow;
}

float RayleighPhase(float cosViewSunAngle) {
	return (3.0 / (16.0*pi)) * (1.0 + pow(max(cosViewSunAngle, 0.0), 2.0));
}

float hgPhase(float cosViewSunAngle, float g) {
	return (1.0 / (4.0 * pi)) * ((1.0 - pow(g, 2.0)) / pow(1.0 + pow(g, 2.0) - 2.0*g * cosViewSunAngle, 1.5));
}

vec3 totalMie(vec3 lambda, vec3 K, float T, float v)
{
	float c = (0.2 * T ) * 10E-18;
	return 0.434 * c * pi * pow((2.0 * pi) / lambda, vec3(v - 2.0)) * K;
}

vec3 totalRayleigh(vec3 lambda, float n, float N, float pn){
	return (24.0 * pow(pi, 3.0) * pow(pow(n, 2.0) - 1.0, 2.0) * (6.0 + 3.0 * pn))
	/ (N * pow(lambda, vec3(4.0)) * pow(pow(n, 2.0) + 2.0, 2.0) * (6.0 - 7.0 * pn));
}

float SunIntensity(float zenithAngleCos, float sunIntensity, float cutoffAngle, float steepness)
{
	return sunIntensity * max(0.0, 1.0 - exp(-((cutoffAngle - acos(zenithAngleCos))/steepness)));
}

vec3 ACESTonemap(vec3 color, float W) {

	const float white = 7.241657387;
	
	const float a = 2.51f;
	const float b = 0.03f;
	const float c = 2.43f;
	const float d = 0.59f;
	const float e = 0.14f;
	
	color = mix(color, color * white / W, 1.0f - timeMidnight);
	color = (color*(a*color+b))/(color*(c*color+d)+e);
	return color;

}

vec3 ToneMap(vec3 color, vec3 sunPos, float W) {

    vec3 toneMappedColor;
	
    toneMappedColor = color * 0.04;
    toneMappedColor = ACESTonemap(toneMappedColor, W);

    float sunfade = 1.0-clamp(1.0-exp(-(sunPos.z/500.0)),0.0,1.0);
    toneMappedColor = pow(toneMappedColor,vec3(1.0/(1.2+(1.2*sunfade))));

    return toneMappedColor;
}

float calcSun(vec3 fragpos, vec3 sunVec){

	const float sunAngularDiameterCos = 0.99873194915;

	float cosViewSunAngle = dot(normalize(fragpos.rgb), sunVec);
	float sundisk = smoothstep(sunAngularDiameterCos,sunAngularDiameterCos+0.0001,cosViewSunAngle);

	return 10000.0 * sundisk * (1.0 - rainStrength);

}

vec3 getAtmosphericScattering(vec3 color, vec3 fragpos, float sunMoonMult, vec3 fogColor){

	float turbidity = 1.5;
	float rayleighCoefficient = 2.0;
	float amount = 0.8;
	
	// constants for mie scattering
	const float mieCoefficient = 0.005;
	const float mieDirectionalG = 0.76;
	const float v = 4.0;

	// Wavelength of the primary colors RGB in nanometers.
	const vec3 primaryWavelengths = vec3(700, 546.1, 435.8) * 1.0E-9;
	
	float n = 1.000293;   // refractive index of air
	float N = 2.54743E25; // number of molecules per unit volume for air at 288.15K and 1013mb (sea level -45 celsius)
	float pn = 0.03;	  // depolarization factor for standard air

	// optical length at zenith for molecules
	float rayleighZenithLength = 8.4E3 ;
	float mieZenithLength = 2.25E3;
	
	const vec3 K = vec3(0.686, 0.678, 0.666);

	float sunIntensity = 1000.0;

	// earth shadow hack
	float cutoffAngle = pi * 0.5128205128205128;
	float steepness = 1.5;

	// Cos Angles
	float cosViewSunAngle = dot(normalize(fragpos.rgb), sunVec);
	float cosSunUpAngle = dot(sunVec, upVec) * 0.95 + 0.05; //Has a lower offset making it scatter when sun is below the horizon.
	float cosUpViewAngle = dot(upVec, normalize(fragpos.rgb));

	float sunE = SunIntensity(cosSunUpAngle, sunIntensity, cutoffAngle, steepness) + 25.0f * timeSkyDark;  // Get sun intensity based on how high in the sky it is

	vec3 totalRayleigh = totalRayleigh(primaryWavelengths, n, N, pn);
	vec3 rayleighAtX = totalRayleigh * rayleighCoefficient;
	vec3 mieAtX = totalMie(primaryWavelengths, K, turbidity, v) * mieCoefficient;

	float zenithAngle = max(0.0, cosUpViewAngle);

	float rayleighOpticalLength = rayleighZenithLength / zenithAngle;
	float mieOpticalLength = mieZenithLength / zenithAngle;

	vec3 Fex = exp(-(rayleighAtX * rayleighOpticalLength + mieAtX * mieOpticalLength));
	vec3 Fexsun = vec3(exp(-(rayleighCoefficient * 0.00002853075 * rayleighOpticalLength + mieAtX * mieOpticalLength)));

	vec3 rayleighXtoEye = rayleighAtX * RayleighPhase(cosViewSunAngle);
	vec3 mieXtoEye = mieAtX * hgPhase(cosViewSunAngle , mieDirectionalG);
	vec3 totalLightAtX = rayleighAtX + mieAtX;
	vec3 lightFromXtoEye = rayleighXtoEye + mieXtoEye;

	vec3 scattering = sunE * (lightFromXtoEye / totalLightAtX);
	vec3 sky = scattering * (1.0 - Fex);
	sky *= mix(vec3(1.0),pow(scattering * Fex,vec3(0.5)),clamp(pow(1.0-cosSunUpAngle,5.0),0.0,1.0));

	vec3 sun = sunlight * calcSun(fragpos, sunVec) * sunVisibility;
	vec3 moon = texture2D(composite,texcoord.st).rgb * moonVisibility;

	vec3 sunMax = sunE * pow(mix(Fexsun, Fex, clamp(pow(1.0-cosUpViewAngle,4.0),0.0,1.0)), vec3(1 / 2.2f))
	* mix(0.000005, 0.00003, clamp(pow(1.0-cosSunUpAngle,3.0),0.0,1.0)) * (1.0 - rainStrength);
	float moonMax = pow(clamp(cosUpViewAngle,0.0,1.0), 0.8) * (1.0 - rainStrength) * 1.5f;

	sky = max(ToneMap(sky * vec3(0.5,0.6,0.7), sunVec, sunE * 0.01), 0.0);
	sky = mix(sky, vec3(dot(sky, vec3(1.0f))) * vec3(0.2f, 0.5f, 1.0f), timeSkyDark * amount) + (sun * sunMax + moon * moonMax) * sunMoonMult;
	color = mix(sky, pow(fogColor, vec3(1 / 2.2f)), rainStrength);
	
	return color;
	
}