
#ifndef APPLE
	#define IN in
#else
	#define IN varying
#endif

uniform sampler2D mainTexture;
#ifndef SHADOW_SHADER
	uniform vec4 glColor;
	uniform vec4 specularValue;
	uniform sampler2D lightmapTexture;
	uniform sampler2D toonTexture;
	uniform sampler2D spaTexture;
	uniform vec2 lightmapCoord;
	uniform vec3 lightDir;
	uniform bool pureColor;
	uniform bool enableLightmap;
	uniform bool enableToon;
	uniform bool shadersmod;
	uniform bool enableSpecular;
	uniform int enableSpa;
#endif

#ifdef APPLE
	IN vec3 vTexCoord;
	IN vec3 normal;
	#ifndef SHADOW_SHADER
		IN float edge;
	#endif
#else
	IN fData {
	vec2 vTexCoord;
	vec3 normal;
	#ifndef SHADOW_SHADER
		float edge;
	#endif
	};
#endif

void main() {
#ifdef SHADOW_SHADER
	#if defined(SEUS102) || defined(SEUS110)
		vec4 tex = texture2D(mainTexture, vTexCoord.st, 0);
		float NdotL = pow(max(0.0, mix(dot(normal.rgb, vec3(0.0, 0.0, 1.0)), 1.0, 0.0)), 1.0 / 2.2);
		vec3 toLight = normal.xyz;
		vec3 shadowNormal = normal.xyz;
		if (normal.z < 0.0)
		{
			tex.rgb = vec3(0.0);
		}
		gl_FragData[0] = vec4(tex.rgb * NdotL, tex.a);
		gl_FragData[1] = vec4(shadowNormal.xyz * 0.5 + 0.5, 1.0);
	#else
		gl_FragData[0] = texture2D(mainTexture, vTexCoord.st);
	#endif
#else
	vec4 color = pureColor ? glColor : texture2D(mainTexture, vTexCoord.st);
	if(edge > 0)
	{
		if(color.a < 1.0)
		{
			discard;
		}
		//gl_FragData[0] = vec4(0.0, 0.0, 0.0, 1.0);
		discard;
	}
	if(enableToon)
	{
		float f = 0.5 * (1.0 - dot(lightDir, normal ));
		vec2 toonCoord = vec2(0.0, f);
		color = color * texture2D(toonTexture, toonCoord);
	}
	if(enableSpa != 0)
	{
		vec2 spaCoord = (normal.xy + vec2(1.0,1.0))*0.5;
		float alpha=color.a;
		if(enableSpa==1)
			color = color * texture2D(spaTexture,spaCoord);
		else if(enableSpa==2)
			color = color + texture2D(spaTexture,spaCoord);
		else if(enableSpa==3)
			color = texture2D(spaTexture,spaCoord);
		color.a=alpha;
	}
	if(!pureColor)
	{
		color=color*glColor;
		color.a=color.a*glColor.a;
	}
	else
	{
		color.a=color.a*glColor.a;
	}
	if(enableLightmap)
	{	
		gl_FragData[0] = color * texture2D(lightmapTexture,lightmapCoord);
		#ifdef C13
			gl_FragData[0] = color;
		#endif
		#ifdef SEUS
			gl_FragData[0] = color;
		#endif
	}
	else
	{
		gl_FragData[0] = color;
	}
	#ifdef C13
		gl_FragData[1] = vec4(normal*0.5+0.5, 1.0);
		gl_FragData[2] = vec4(specularValue.rgb, 1.0);
		gl_FragData[3] = vec4(lightmapCoord.st, 1.0, 1.0);
	#endif
	#ifdef SEUS
		float ValueA=3.0;
		float VauleB=1.0;//SEUS101 is 5.7
		float lightA = clamp((lightmapCoord.s * 33.05 / 32.0) - 1.05 / 32.0, 0.0, 1.0);
			  lightA = pow(lightA, ValueA);
		float lightB = clamp((lightmapCoord.t * 33.05 / 32.0) - 1.05 / 32.0, 0.0, 1.0);
			  lightB = pow(lightB, VauleB);
		gl_FragData[1] = vec4(1.1/255.0, lightA, lightB, 1.0);
		gl_FragData[2] = vec4(normal*0.5+0.5, 1.0);
		gl_FragData[3] = vec4( specularValue.a*color.a ,specularValue.a*color.a, specularValue.a*color.a, 1.0);//*0.8
		#ifdef SEUS110
			gl_FragData[3] = vec4( specularValue.a*color.a,specularValue.a*color.a, 0, 1.0);
		#endif
		#ifdef SEUS110
			gl_FragData[4] = vec4(normal*0.5+0.5, 1.0);
		#endif
	#endif
#endif
}