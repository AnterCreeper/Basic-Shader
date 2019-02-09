#version 120
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

uniform sampler2D texture;

varying vec4 color;
varying vec4 lmcoord;
varying vec4 texcoord;

varying vec3 normal;

void main() {

/* DRAWBUFFERS:025 */

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
	gl_FragData[1] = vec4(normal * 0.5f + 0.5f, 1.0);
	gl_FragData[2] = vec4(lmcoord.st, 0.0f, 1.0f);
	
}