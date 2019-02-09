//Final Process Lib Version v3.5

float Positive(float x) { 
	return clamp(x, 0.0, 1.0);
}  

vec2  Positive(vec2  x) { 
	return clamp(x, vec2(0.0), vec2(1.0)); 
}  

vec3  Positive(vec3  x) { 
	return clamp(x, vec3(0.0), vec3(1.0)); 
}  

vec4  Positive(vec4  x) { 
	return clamp(x, vec4(0.0), vec4(1.0)); 
}  
  
vec3 ColorTemperatureToRGB(float temperatureInKelvins)  
{  
    vec3 retColor = vec3(1.0, 1.0, 1.0);  
      
    temperatureInKelvins = clamp(temperatureInKelvins, 1000.0, 40000.0) / 100.0;  
      
    if (temperatureInKelvins <= 66.0) {  
        retColor.r = 1.0;  
        retColor.g = Positive(0.39008157876901960784 * log(temperatureInKelvins) - 0.63184144378862745098);  
    } else {  
        float t = temperatureInKelvins - 60.0;  
        retColor.r = Positive(1.29293618606274509804 * pow(t, -0.1332047592));  
        retColor.g = Positive(1.12989086089529411765 * pow(t, -0.0755148492));  
    }  
      
    if (temperatureInKelvins >= 66.0) { 
        retColor.b = 1.0;  
    } else if(temperatureInKelvins <= 19.0) { 
        retColor.b = 0.0;  
    } else {
		retColor.b = Positive(0.54320678911019607843 * log(temperatureInKelvins - 10.0) - 1.19625408914);  
	}
	
	return retColor; 
 
}

float vec3ToFloat(vec3 vec3Input) {

	float floatValue  = 0.0;
	      floatValue += vec3Input.x;
	      floatValue += vec3Input.y;
	      floatValue += vec3Input.z;

	      floatValue /= 3.0;

	return floatValue;

}

void doCinematicMode(inout vec3 color) {

	if (texcoord.t > 0.9 || texcoord.t < 0.1) color = vec3(0.0);
	
}
	
void doVignette(inout vec3 color) {

    float power = 0.6f;
	float dist  = distance(texcoord.st, vec2(0.5f)) * 2.0f;
	      dist /= 1.5142f;
	      dist  = pow(dist, 1.1f);

	color.rgb *= 1.0f - dist * power;

}

void doTonemapping(inout vec3 color) {

	const float A = 2.51f;
	const float B = 0.03f;
	const float C = 2.43f;
	const float D = 0.59f;
	const float E = 0.14f;
	
	color = (color * (A * color + B)) / (color * (C * color + D) + E);
	color = pow(color.rgb, vec3(1.0f / 2.2f));

}

void doCalculateExposure(inout vec3 color) {

	float avglod = int(log2(min(viewWidth, viewHeight)));
	float avgLumPow = 1.2;

	float exposureMax = 2.20f;
		  exposureMax *= mix(1.0f, 0.7f, timeMidnight);
		  exposureMax *= mix(1.0f, 0.25f, rainStrength);
	float exposureMin = 0.20f;
	float exposure = pow(eyeBrightnessSmooth.y / 240.0f, 6.0f) * exposureMax + exposureMin;

	color.rgb /= vec3(exposure);
	//color.rgb /= pow(log(texture2DLod(gcolor, vec2(0.5, 0.5), avglod).a * 10000.0), avgLumPow) * 0.9 + 0.00005;
	
}

void doColorProcess(inout vec3 color) {
	
	float gamma		 = mix(0.92f, 0.85f, timeMidnight);
	float exposure	 = mix(1.85f, 1.20f, timeMidnight);
	float saturation = mix(1.20f, 0.98f, timeMidnight);
	float contrast	 = mix(1.05f, 0.95f, timeMidnight);

	float luma = Luminance(color.rgb);
	
	color = pow(color, vec3(gamma)) * exposure;
	color = (((color - luma) * saturation) + luma) / luma * pow(luma, contrast);
	//color *= ColorTemperatureToRGB(6000);
	
}

void doAddCameraNoise(inout vec3 color) {
	
	vec2 aspectcorrect = vec2(aspectRatio, 1.0);
	vec3 rgbNoise = texture2D(noisetex, texcoord.st * max(viewHeight, viewWidth) * aspectcorrect + vec2(frameTimeCounter)).rgb;
	color = mix(color, rgbNoise, vec3ToFloat(rgbNoise) * NoiseStrength / (vec3ToFloat(color) * 3.0f + 0.3f) / 18.0f);

}

void doSizeLock(inout vec3 color) {

	float heightdepth = viewWidth / CinematicHeight * CinematicWidth ;
	
	if (viewHeight > heightdepth){
	  float correct = (viewHeight - heightdepth) / viewHeight / 2;
	  float fakecorrect = 1 - correct;
	  if (texcoord.t > fakecorrect || texcoord.t < correct) color = vec3(0.0);
	}
	  
	if (viewHeight < heightdepth){
	  float correct = viewHeight / CinematicWidth * CinematicHeight;
	        correct = (viewWidth - correct) / viewWidth / 2;
	  float fakecorrect = 1 - correct;
	  if (texcoord.s > fakecorrect || texcoord.s < correct) color = vec3(0.0);
	}
  
}

vec3 rgbToHsl(vec3 rgbColor) {
    rgbColor = clamp(rgbColor, vec3(0.0), vec3(1.0));
    float h, s, l;
    float r = rgbColor.r, g = rgbColor.g, b = rgbColor.b;
    float minval = min(r, min(g, b));
    float maxval = max(r, max(g, b));
    float delta = maxval - minval;
    l = ( maxval + minval ) / 2.0;  
    if (delta == 0.0) 
    {
        h = 0.0;
        s = 0.0;
    }
    else
    {
        if ( l < 0.5 )
            s = delta / ( maxval + minval );
        else 
            s = delta / ( 2.0 - maxval - minval );
             
        float deltaR = (((maxval - r) / 6.0) + (delta / 2.0)) / delta;
        float deltaG = (((maxval - g) / 6.0) + (delta / 2.0)) / delta;
        float deltaB = (((maxval - b) / 6.0) + (delta / 2.0)) / delta;
         
        if(r == maxval)
            h = deltaB - deltaG;
        else if(g == maxval)
            h = ( 1.0 / 3.0 ) + deltaR - deltaB;
        else if(b == maxval)
            h = ( 2.0 / 3.0 ) + deltaG - deltaR;
             
        if ( h < 0.0 )
            h += 1.0;
        if ( h > 1.0 )
            h -= 1.0;
    }
    return vec3(h, s, l);
}

float hueToRgb(float v1, float v2, float vH) {
    if (vH < 0.0)
        vH += 1.0;
    if (vH > 1.0)
        vH -= 1.0;
    if ((6.0 * vH) < 1.0)
        return (v1 + (v2 - v1) * 6.0 * vH);
    if ((2.0 * vH) < 1.0)
        return v2;
    if ((3.0 * vH) < 2.0)
        return (v1 + ( v2 - v1 ) * ( ( 2.0 / 3.0 ) - vH ) * 6.0);
    return v1;
}
 
vec3 hslToRgb(vec3 hslColor) {
    hslColor = clamp(hslColor, vec3(0.0), vec3(1.0));
    float r, g, b;
    float h = hslColor.r, s = hslColor.g, l = hslColor.b;
    if (s == 0.0)
    {
        r = l;
        g = l;
        b = l;
    }
    else
    {
        float v1, v2;
        if (l < 0.5)
            v2 = l * (1.0 + s);
        else
            v2 = (l + s) - (s * l);
     
        v1 = 2.0 * l - v2;
     
        r = hueToRgb(v1, v2, h + (1.0 / 3.0));
        g = hueToRgb(v1, v2, h);
        b = hueToRgb(v1, v2, h - (1.0 / 3.0));
    }
    return vec3(r, g, b);
}

vec3 RGBToYUV(vec3 color)
{
	mat3 mat = 	mat3( 0.2126,  0.7152,  0.0722,
				 	-0.09991, -0.33609,  0.436,
				 	 0.615, -0.55861, -0.05639);
				 	
	return color * mat;
}

vec3 YUVToRGB(vec3 color)
{
	mat3 mat = 	mat3(1.000,  0.000,  1.28033,
				 	1.000, -0.21482, -0.38059,
				 	1.000,  2.12798,  0.000);
				 	
	return color * mat;
}