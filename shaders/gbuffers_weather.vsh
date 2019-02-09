#version 120
// This file is part of Basic Shader.
// Read LICENSE First at composite.fsh

#define WAVING_RAIN

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;

uniform vec3 cameraPosition;

uniform float frameTimeCounter;

varying vec4 color;
varying vec4 lmcoord;
varying vec4 texcoord;

varying vec3 normal;

void main() {

	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	vec3 worldpos = position.xyz + cameraPosition;
	
	bool todo = worldpos.y > cameraPosition.y + 5.0;
	
	#ifdef WAVING_RAIN
		if (!todo) position.xz += vec2(2.3, 1.0) + pow(sin(frameTimeCounter), 3.0f) * vec2(2.1, 0.6);
				   position.xz -= (vec2(3.0, 1.0) + pow(sin(frameTimeCounter), 3.0f) * vec2(2.1, 0.6)) * 0.25;
	#endif
	
	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
	
	color 	 = gl_Color;
	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	lmcoord  = gl_TextureMatrix[1] * gl_MultiTexCoord1;
	normal   = normalize(gl_NormalMatrix * gl_Normal);

}