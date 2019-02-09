#version 120
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

//#define SPECULAR_TO_PBR_CONVERSION

uniform sampler2D texture;
uniform sampler2D specular;

varying vec4 color;
varying vec4 lmcoord;
varying vec4 texcoord;

varying vec3 normal;

void main() {

    vec3 spec = texture2D(specular, texcoord.st).rgb;
  
    //Convert normal specular map to PBR
	#ifdef SPECULAR_TO_PBR_CONVERSION
	 float spec_strength = dot(spec.rgb, vec3(0.3, 0.6, 0.1));
	 spec = vec3(spec.b, spec_strength, 0.0f);
	#endif

/* DRAWBUFFERS:0245 */

	//0:gcolor    = albedo(r.g.b), cloudmask(a) RGBA16
	//1:gdepth    = materials(r), luminance(g) RG16F
	//2:gnormal   = normals(r.g.b) RGB16
	//3:composite = bloomdata/aaEdgeTex(r.g.b) RGB16
	//4:gaux1     = specular(r.g.b) RGB16
	//5:gaux2     = lmcoord(r.g), state(b), godrays(a) RGBA16
	//6:gaux3     = aaAreaTex
	//7:gaux4     = aaSearchTex
	
	// state 
	// 0.0 : none 
	// 0.1 : ishand
	// 0.2 : iswater
	// 0.3 : isentity
	// 0.4 : isice
	
	gl_FragData[0] = texture2D(texture, texcoord.st) * color;
	gl_FragData[1] = vec4(normal * 0.5 + 0.5, 1.0);
	gl_FragData[2] = vec4(spec, 1.0f);
	gl_FragData[3] = vec4(lmcoord.st, 0.3f, 1.0f);

}
