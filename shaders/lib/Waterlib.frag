//Water Render Part Version v3.0

//This file is part of Basic Shader.
//Read LICENSE First at composite.fsh

//Water Properties

#define SEA_HEIGHT 0.70 

const float SEA_SPEED = 0.25;

vec2 cube(in vec2 x) {
	return x * x * (3.0 - 2.0 * x);
}

vec4 textureSmooth(in sampler2D tex, in vec2 coord)
{
	vec2 res = vec2(64.0f, 64.0f);

	coord *= res;
	coord += 0.5f;

	vec2 whole = floor(coord);
	vec2 part  = fract(coord);

	part.x = part.x * part.x * (3.0f - 2.0f * part.x);
	part.y = part.y * part.y * (3.0f - 2.0f * part.y);
	// part.x = 1.0f - (cos(part.x * 3.1415f) * 0.5f + 0.5f);
	// part.y = 1.0f - (cos(part.y * 3.1415f) * 0.5f + 0.5f);

	coord = whole + part;

	coord -= 0.5f;
	coord /= res;

	return texture2D(tex, coord);
}

vec2 SmoothNoiseCoord(in vec2 coord) { 
	coord *= 64;
	coord  = floor(coord) + cube(fract(coord)) + 0.5;
	coord /= 64;	
	return coord;
}

float SharpenWave(in float wave) {
	wave = 1.0 - abs(wave * 2.0 - 1.0);
	if (wave > 0.78) wave = 5.0 * wave - wave * wave * 2.5 - 1.6;
	return wave;
}

float AlmostIdentity(in float x, in float m, in float n)
{
	if (x > m) return x;

	float a = 2.0f * n - m;
	float b = 2.0f * m - 3.0f * n;
	float t = x / m;

	return (a * t + b) * t * t + n;
}

vec4 getnoise0(sampler2D tex, vec2 coord){return textureSmooth(tex, coord);}

float doWave(vec3 position, in float scale) {

	float speed = 0.9f;

	vec2 p = position.xz / 80.0f;

	p.xy -= position.y / 40.0f;

	p.x = -p.x;

	p.x += (SEA_SPEED * frameTimeCounter / 40.0f) * speed;
	p.y -= (SEA_SPEED * frameTimeCounter / 40.0f) * speed;

	float weight = 1.0f;
	float weights = weight;

	float allwaves = 0.0f;

	float wave = getnoise0(noisetex, (p * vec2(2.0f, 1.2f))  + vec2(0.0f,  p.x * 2.1f) ).x; 			p /= 2.1f; 	/*p *= pow(2.0f, 1.0f);*/ 	p.y -= (SEA_SPEED * frameTimeCounter / 20.0f) * speed; p.x -= (SEA_SPEED * frameTimeCounter / 30.0f) * speed;
	allwaves += wave;

	weight = 4.1f;
	weights += weight;
	wave = getnoise0(noisetex, (p * vec2(2.0f, 1.4f))  + vec2(0.0f,  -p.x * 2.1f) ).x;	p /= 1.5f;/*p *= pow(2.0f, 2.0f);*/ 	p.x += (SEA_SPEED * frameTimeCounter / 20.0f) * speed;
	wave *= weight;
	allwaves += wave;

	weight = 17.25f;
	weights += weight;
	wave = (getnoise0(noisetex, (p * vec2(1.0f, 0.75f))  + vec2(0.0f,  p.x * 1.1f) ).x);		p /= 1.5f; 	p.x -= (SEA_SPEED * frameTimeCounter / 55.0f) * speed;
	wave *= weight;
	allwaves += wave;

	weight = 15.25f;
	weights += weight;
	wave = (getnoise0(noisetex, (p * vec2(1.0f, 0.75f))  + vec2(0.0f,  -p.x * 1.7f) ).x);		p /= 1.9f; 	p.x += (SEA_SPEED * frameTimeCounter / 155.0f) * speed;
	wave *= weight;
	allwaves += wave;

	weight = 29.25f;
	weights += weight;
	wave = abs(getnoise0(noisetex, (p * vec2(1.0f, 0.8f))  + vec2(0.0f,  -p.x * 1.7f) ).x * 2.0f - 1.0f);		p /= 2.0f; 	p.x += (SEA_SPEED * frameTimeCounter / 155.0f) * speed;
	wave = 1.0f - AlmostIdentity(wave, 0.2f, 0.1f);
	wave *= weight;
	allwaves += wave;

	weight = 15.25f;
	weights += weight;
	wave = abs(getnoise0(noisetex, (p * vec2(1.0f, 0.8f))  + vec2(0.0f,  p.x * 1.7f) ).x * 2.0f - 1.0f);
	wave = 1.0f - AlmostIdentity(wave, 0.2f, 0.1f);
	wave *= weight;
	allwaves += wave;

	allwaves /= weights;

	return allwaves * SEA_HEIGHT;
}
