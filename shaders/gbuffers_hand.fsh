#version 120
#extension GL_ARB_shader_texture_lod : enable

/* DRAWBUFFERS:024 */

varying vec4 color;
varying vec2 lmcoord;
varying vec3 tangent;
varying vec3 normal;
varying vec3 binormal;
varying vec2 texcoord;

uniform sampler2D texture;
uniform sampler2D lightmap;

void main() {

/* DRAWBUFFERS:0246 */

	//0:gcolor  = albedo
	//2:gnormal = materials,iswater,isentity
	//4:gaux1   = normals
	//5:gaux2   = specular
	//6:gaux3   = lmcoord,ishand
	
	vec4 light     = texture2D(lightmap, lmcoord.st);
         light.rgb = light.rgb / (light.rgb + vec3(1.0f)) * 2.0f;
		 
	vec4 frag2     = vec4(vec3(normal) * 0.5 + 0.5, 1.0f);
	
	gl_FragData[0] = texture2D(texture, texcoord.st) * color * light;
	gl_FragData[1] = vec4(0.0f, 0.0f, 0.0f, 1.0f);
	gl_FragData[2] = frag2;
    gl_FragData[4] = vec4(lmcoord.xy, 1.0f, 1.0f);
	
}