//Physical Lighting Render Lib Version v1.5

//This file is part of Basic Shader.
//Read LICENSE First at composite.fsh

#define Positive(input) max(input, 1E-10)
#define pi 3.1415926535897932834919

float DistributionGGX(vec3 N, vec3 H, float roughness) {
    float a     = roughness * roughness;
    float NdotH = Positive(dot(N, H));
	
    float nom   = dot(a, a);
    float denom = (dot(NdotH, NdotH) * (dot(a, a) - 1.0) + 1.0);
		  denom = pi * denom * denom;
		  
    return nom / denom;
}

float GeometrySchlickGGX(float NdotV, float roughness) {
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;
	
    float nom   = NdotV;
    float denom = NdotV * (1.0 - k) + k;
	
    return nom / denom;
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
    float NdotV = Positive(dot(N, V));
    float NdotL = Positive(dot(N, L));
	
    float ggx2  = GeometrySchlickGGX(NdotV, roughness);
    float ggx1  = GeometrySchlickGGX(NdotL, roughness);
	
    return ggx1 * ggx2;
}

vec3 FresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness) {
	return F0 + (max(vec3(1.0 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
}

vec3 getPBRLighting(in vec3 viewpos, in vec3 normal, in float metallic, in float roughness, in vec3 color) {

    vec3 N = normalize(normal);
    vec3 V = normalize(-viewpos);

    vec3 F0 = vec3(0.04);
    F0 = mix(F0, color, metallic);

    vec3 L = normalize(shadowLightPosition);
    vec3 H = normalize(L + V);

    //Cook-Torrance BRDF
	vec3 F    = FresnelSchlickRoughness(Positive(dot(H, V)), F0, roughness);
    float NDF = DistributionGGX(N, H, roughness);
    float G   = GeometrySmith(N, V, L, roughness);

    vec3 kD = vec3(1.0) - F;
         kD *= 1.0 - metallic;     

    vec3 nominator    = NDF * G * F;
    float denominator = 4 * Positive(dot(N, V)) * Positive(dot(N, L)) + 0.001; 
	
    vec3 specular = nominator / denominator;
		 
    return specular + kD / pi * color; 

}
