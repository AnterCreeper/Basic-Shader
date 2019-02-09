//Noise Lib Version v2.0

//This file is part of Basic Shader.
//Read LICENSE First at composite.fsh

float noise_tex(in vec2 pos) {
    return texture2D(noisetex, pos).x;
}

float frase_noise() {
	return 2.0 * noise_tex(vec2(moonPhase / 12.0)) - 1.0;
}

float ambient_noise() {
	float frase = frase_noise();
	float value = 1.0;
		  value *= abs(sin(frameTimeCounter * 0.06 * (1.2 + 0.3  * frase)));
		  value *= abs(cos(frameTimeCounter * 0.04 * (0.5 - 0.2  * frase)));
		  value *= abs(sin(frameTimeCounter * 0.02 * (2.0 + 0.35 * frase)));
	return mix(value * 0.7, 1.0, wetness);
}

float rand_fast(float code) {
	return fract(sin(code) * 43758.5453);
}

float rand(float code){
    return fract(sin(dot(vec2(code), vec2(12.9898,78.233))) * 43758.5453);
}

float hash_fast(vec2 pos) {
    return fract(mod(pos.x, 1.0) * 73758.23 - pos.y);
}

float hash_gr(vec2 pos) {
    return abs(fract(sin(dot(pos ,vec2(18.9898f,28.633f))) * 4378.5453f));
}

float hash(vec2 pos) {
    vec3 pos2  = fract(vec3(pos.xyx) * 0.2031);
         pos2 += dot(pos2, pos2.yzx + 19.19);
    return fract((pos2.x + pos2.y) * pos2.z);
}

float hashmix(vec2 pos) {
	vec2 i = floor(pos);
	vec2 f = fract(pos);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return -1.0 + 2.0 * mix(
		mix(hash(i),                 hash(i + vec2(1.0,0.0)), u.x),
		mix(hash(i + vec2(0.0,1.0)), hash(i + vec2(1.0,1.0)), u.x),
	u.y);
}

float hashran(vec2 pos) {
	vec2 i = floor(pos);
	vec2 f = fract(pos);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float n = i.x + i.y * 57.0;
	return mix(mix(rand(n + 0.0) , rand(n + 1.0),  u.x), 
	           mix(rand(n + 57.0), rand(n + 58.0), u.x), u.y);
} 

float fbm(vec2 pos) {
	float f  = 0.0;
		  f += 0.50000 * hashran(pos);  pos = pos * 2.5;
		  f += 0.25000 * hashran(pos);  pos = pos * 2.5;
		  f += 0.12500 * hashran(pos);  pos = pos * 2.5;
		  f += 0.06250 * hashran(pos);  pos = pos * 2.5;
		  f += 0.03125 * hashran(pos);
	return f / 0.984375;
}

float cubic_noise(vec3 pos) {
	vec3 p = floor(pos);
	vec3 f = fract(pos);
	vec2 uv  = (p.xy + p.z * vec2(17.0f)) + f.xy;
	vec2 uv2 = (p.xy + (p.z + 1.0f) * vec2(17.0f)) + f.xy;
	vec2 coord  = (uv  + 0.5f) / noiseTextureResolution;
	vec2 coord2 = (uv2 + 0.5f) / noiseTextureResolution;
	float xy1 = noise_tex(coord);
	float xy2 = noise_tex(coord2);
	return mix(xy1, xy2, f.z);
}