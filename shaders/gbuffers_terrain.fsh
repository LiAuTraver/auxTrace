#version 330 compatibility

uniform sampler2D lightmap;
uniform sampler2D gtexture;

uniform float alphaTestRef = 0.1;

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec3 normal;

/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 lightmapData;
layout(location = 2) out vec4 encodedNormal;

void main() {
	color = texture(gtexture, texcoord) * glcolor; // glcolor containes biome tint
	// color *= texture(lightmap, lmcoord); // we dont need lightmap lighting since we are doing our own lighting
	if (color.a < alphaTestRef) {
		discard;
	}
  // color.rgb = normal;
  lightmapData = vec4(lmcoord, 0.0, 1.0);
  encodedNormal = vec4(normal * 0.5 + 0.5, 1.0);
}