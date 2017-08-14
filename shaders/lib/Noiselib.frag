//Noise Lib Version v1.2

//This file is part of Basic Shader.
//Read LICENSE First at composite.fsh

#define CLOUD_SPEED 0.2

float noise_tex(in vec2 p) {
    return texture2D(noisetex, p).x;
}

float frasenoise() {
	return 2.0f * noise_tex(vec2(moonPhase)) - 1.0f;
}

float rand_fast(float n) {
	return fract(sin(n)*43758.5453);
}

float rand(float co){
    return fract(sin(dot(vec2(co) ,vec2(12.9898,78.233))) * 43758.5453);
}

float hash_fast(vec2 p) {
    return fract(mod(p.x, 1.0) * 73758.23f - p.y);
}

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.2031);
         p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

float hashnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f*f*(3.0-2.0*f);
	return -1.0 + 2.0 * mix(
		mix(hash(i),                 hash(i + vec2(1.0,0.0)), u.x),
		mix(hash(i + vec2(0.0,1.0)), hash(i + vec2(1.0,1.0)), u.x),
	u.y);
}

float hashnoise2(in vec2 x) {
	vec2 p = floor(x);
	vec2 f = fract(x);
	f = f*f*(3.0-2.0*f);
	float n = p.x + p.y*57.0;
	float res = mix(mix(rand(n+0.0), rand(n+1.0),f.x), mix(rand(n+57.0), rand(n+58.0),f.x),f.y);
	return res;
}

float fbm(vec2 p) {
	float f = 0.0;
	f += 0.50000*hashnoise2(p); p = p*2.5;
	f += 0.25000*hashnoise2(p); p = p*2.5;
	f += 0.12500*hashnoise2(p); p = p*2.5;
	f += 0.06250*hashnoise2(p); p = p*2.5;
	f += 0.03125*hashnoise2(p);
	return f / 0.984375;
}

float Get3DNoise(in vec3 pos)
{
	vec3 p = floor(pos);
	vec3 f = fract(pos);

	vec2 uv =  (p.xy + p.z * vec2(17.0f)) + f.xy;
	vec2 uv2 = (p.xy + (p.z + 1.0f) * vec2(17.0f)) + f.xy;
	
	vec2 coord =  (uv  + 0.5f) / noiseTextureResolution;
	vec2 coord2 = (uv2 + 0.5f) / noiseTextureResolution;
	
	float xy1 = texture2D(noisetex, coord).x;
	float xy2 = texture2D(noisetex, coord2).x;
	return mix(xy1, xy2, f.z);
}

float getRAWNoise(in vec3 p)
{
	float t = frameTimeCounter * CLOUD_SPEED * 0.2;
		  p.x *= 0.5f;
		  p.x -= t * 0.1f;
	float noise  = Get3DNoise(p * vec3(1.0f, 0.5f, 1.0f) + vec3(0.0f, t * 0.01f, 0.0f)) * 1.3;		p *= 2.0f;	p.x -= t * 0.557f;
		  noise += (2.0f - abs(Get3DNoise(p) * 2.0f - 0.0f)) * 0.35f;								p *= 3.0f;	p.xz -= t * 0.905f;	 p.x *= 2.0f;
		  noise += (3.0f - abs(Get3DNoise(p) * 3.0f - 0.0f)) * 0.085f;							    p *= 3.0f;	p.xz -= t * 3.905f;
		  noise += (3.0f - abs(Get3DNoise(p) * 3.0f - 0.0f)) * 0.035f;							    p *= 3.0f;	p.xz -= t * 3.905f;
		  noise += Get3DNoise(p) * 0.04f;												            p *= 3.0f;
		  noise /= 2.375f;
	return noise;
}