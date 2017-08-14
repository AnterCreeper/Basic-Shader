//Final-Color Process Lib Version v3.4
									
void Vignette(inout vec3 color) {

	float dist = distance(texcoord.st, vec2(0.5f)) * 2.0f;
	      dist /= 1.5142f;
	      dist = pow(dist, 1.1f);

	color.rgb *= 1.0f - dist * 0.5f;

}

void Tonemapping(inout vec3 color) {

	const float A = 2.51f;
	const float B = 0.03f;
	const float C = 2.43f;
	const float D = 0.59f;
	const float E = 0.14f;
	
	color = (color * (A * color + B)) / (color * (C * color + D) + E);
	color = clamp(pow(color.rgb, vec3(1.0f / 2.2f)), vec3(0.0), vec3(1.0));

}

void CalculateExposure(inout vec3 color) {

	float exposureMax = 1.45;
		  exposureMax *= mix(1.0f, 0.75f, timeMidnight);
		  exposureMax *= mix(1.0f, 0.25f, rainStrength);
	float exposureMin = 0.37f;
	float exposure = pow(eyeBrightnessSmooth.y / 1200.0f + 0.8f, 6.0f) * exposureMax + exposureMin;
	color.rgb /= exposure;
	
}

void LowtoneSaturate(inout vec3 color)
{
	color = pow(color,vec3(1.0f / (1.0f + 1.2f)));
	color.rgb *= 1.125f;
	color.rgb -= 0.125f;
	color.rgb = clamp(color.rgb, vec3(0.0f), vec3(1.0f));
}

void ColorProcess(inout vec3 color) {

	float gamma			= 1.02f;
	float exposure		= 0.96f;
	float saturation	= 1.16f;
	float contrast		= 1.08f;
	
	color = pow(color, vec3(gamma));
	color *= exposure;
		
	saturation = mix(saturation, 0.92, timeMidnight);
	float luma = calcluma(color.rgb);
	vec3 chroma = color - luma;
	color = (chroma * saturation) + luma;
	
	//vec3 nColor = color / luma;
	//luma = pow(luma, contrast);
	//color = nColor * luma;

	float ColorLength = length(color);
	vec3 nColor = color / ColorLength;
	ColorLength = pow(ColorLength, contrast);
	color = nColor * ColorLength;
	
	#ifdef COLORFUL_HUE
	 float hue_gain = 1.46f;
	 color.b = clamp(color.b, 0.02f, 0.9f);
	 color.rgb = color.rgb * hue_gain - (color.gbr + color.brg) * 0.2f;
	#endif

}

float vec3ToFloat(vec3 vec3Input) {

	float floatValue  = 0.0;
	      floatValue += vec3Input.x;
	      floatValue += vec3Input.y;
	      floatValue += vec3Input.z;

	      floatValue /= 3.0;

	return floatValue;

}

void addCameraNoise(inout vec3 color) {
	
	vec2 aspectcorrect = vec2(aspectRatio, 1.0);
	vec3 rgbNoise = texture2D(noisetex, texcoord.st * max(viewHeight,viewWidth) * aspectcorrect + vec2(frameTimeCounter)).rgb;
	color = mix(color, rgbNoise, vec3ToFloat(rgbNoise) * noiseStrength / (color.r + color.g + color.b + 0.3) / 18);

}

void doCinematicMode(inout vec3 color) {

	float heightst = viewWidth / CinematicHeight * CinematicWidth ;
	
	if (viewHeight > heightst){
	  float ast = (viewHeight - heightst) / viewHeight / 2;
	  float ss = 1 - ast;
	  if (texcoord.t > ss || texcoord.t < ast) color = vec3(0.0);
	}
	  
	if (viewHeight < heightst){
	  float widthst = viewHeight / CinematicWidth * CinematicHeight;
	  float bst = (viewWidth - widthst) / viewWidth / 2;
	  float tt = 1 - bst;
	  if (texcoord.s > tt || texcoord.s < bst) color = vec3(0.0);
	}
  
}