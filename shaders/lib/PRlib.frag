//Physics Render Part Version v1.2

//This file is part of Basic Shader.
//Read LICENSE First at composite.fsh

struct LightSource {
	vec3 color;
	float attenuation;
};

struct LightSourcePBR {
	LightSource light;
	vec3 L;
};

struct Material {
	vec3 nvpos;
	vec3 N;
	vec3 albedo;
	float metallic;
	float roughness;
};

#define Positive(a) max(0.0000001, a)

void material_build(out Material mat, in vec3 vpos) {
	mat.nvpos = normalize(vpos);
	mat.N = texture2D(gaux1, texcoord.st).rgb * 2.0 - 1.0;;
	mat.albedo = texture2D(gcolor,texcoord.st).rgb;
	mat.metallic = texture2D(gaux2,texcoord.st).g;
	mat.roughness = texture2D(gaux2,texcoord.st).r;
}

vec3 light_calc_diffuse(LightSource Li, Material mat) {
	return Li.attenuation * mat.albedo * Li.color;
}

float light_mclightmap_attenuation(in float l) {
	float light_distance = clamp((1.0 - pow(l, 4.6)), 0.08, 1.0);
	float max_light = 80.5 * pow(l, 2.0);

	const float light_quadratic = 4.9f;
	const float light_constant1 = 1.09f;
	const float light_constant2 = 1.09f;

	return clamp(light_constant1 / (pow(light_distance, light_quadratic)) - light_constant2, 0.0, max_light);
}

float light_mclightmap_simulated_GI(in float Ld, in vec3 L, in vec3 N) {
	float simulatedGI = 0.4 * (-1.333 / (3.0 * pow(Ld, 4.0) + 1.0) + 1.333);
	
	vec3 sunRef = reflect(L, upVec);
	simulatedGI *= 1.5 + 0.5 * max(0.0, dot(sunRef, N));

	return simulatedGI;
}

float light_PBR_oren_diffuse(in vec3 v, in vec3 l, in vec3 n, in float r, in float NdotL, in float NdotV) {
	float t = max(NdotL,NdotV);
	float g = max(.0, dot(v - n * NdotV, l - n * NdotL));
	float c = g/t - g*t;

	float a = .285 / (r+.57) + .5;
	float b = .45 * r / (r+.09);

	return Positive(NdotL) * (b * c + a);
}

vec3 light_PBR_fresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness) {
	return F0 + (max(vec3(1.0 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
}

#define GeometrySchlickGGX(NdotV, k) (NdotV / (NdotV * (1.0 - k) + k))

float GeometrySmith(float NdotV, float NdotL, float k) {
	float ggx1 = GeometrySchlickGGX(NdotV, k);
	float ggx2 = GeometrySchlickGGX(NdotL, k);

	return ggx1 * ggx2;
}

float DistributionGGX(vec3 N, vec3 H, float roughness) {
	float a      = roughness*roughness;
	float a2     = a*a;
	float NdotH  = Positive(dot(N, H));

	float denom = (NdotH * NdotH * (a2 - 1.0) + 1.0);
	denom = pi * denom * denom;

	return a2 / denom;
}

vec3 light_calc_PBR(in LightSourcePBR Li, in Material mat, in float wet) {
	
	mat.roughness = max(mat.roughness - wet * 0.25f, 0.0f);
	
	float NdotV = Positive(dot(mat.N, -mat.nvpos));
	float NdotL = Positive(dot(mat.N, Li.L));
	
	float oren = light_PBR_oren_diffuse(-mat.nvpos, Li.L, mat.N, mat.roughness, NdotL, NdotV);
	float att = min(1.0, Li.light.attenuation * oren);
	vec3 radiance = att * Li.light.color;

	vec3 F0 = vec3(0.01);
	F0 = mix(F0, mat.albedo, mat.metallic);
	
	vec3 H = normalize(Li.L - mat.nvpos);
	
	float NDF = DistributionGGX(mat.N, H, mat.roughness);
	float G = GeometrySmith(NdotV, NdotL, mat.roughness);
	vec3 F = light_PBR_fresnelSchlickRoughness(Positive(dot(H, -mat.nvpos)), F0, mat.roughness);

	vec3 kD = max(vec3(0.0), vec3(1.0) - F);
	kD *= 1.0 - mat.metallic;

	vec3 nominator = NDF * G * F;
	float denominator =  4 * NdotV * NdotL + 0.001;
	vec3 specular = nominator / denominator;

	return (kD / pi * mat.albedo + specular) * radiance;

}

vec3 light_calc_PBR_IBL(in vec3 L, Material mat, in vec3 env) {

	vec3 H = normalize(L - mat.nvpos);
	vec3 F0 = vec3(0.02);
	F0 = mix(F0, mat.albedo, mat.metallic);
	
	vec3 F = light_PBR_fresnelSchlickRoughness(max(dot(H, -mat.nvpos), 0.00001), F0, mat.roughness);

	return (1.0 - mat.roughness) * F * env;
	
}