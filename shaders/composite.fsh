#version 330 compatibility

// constant variables which was defined by developer(we)
const vec3 blocklightColor = vec3(1.0, 0.5, 0.08);
const vec3 skylightColor = vec3(0.05, 0.15, 0.3);
const vec3 sunlightColor = vec3(1.0);
const vec3 ambientColor = vec3(0.1);

uniform sampler2D colortex0; // info of blocks and entities
uniform sampler2D colortex1; // lightmap data
uniform sampler2D colortex2; // encoded surface normals

uniform vec3 shadowLightPosition;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform sampler2D shadowtex0;

uniform sampler2D depthtex0;

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;
/*
const int colortex0Format = RGB16;
*/

vec3 projectAndDivide(mat4 projMat, vec3 pos){
  vec4 homePos = projMat * vec4(pos, 1.0);
  return homePos.xyz / homePos.w;
}

void main() {
	color = texture(colortex0, texcoord);
  color.rgb = pow(color.rgb, vec3(2.2)); // gamma correction, revert it in `final.fsh/vsh`
	
  vec2 lightmap = texture(colortex1,texcoord).rg; // block light in red channel, skylight in green channel
  vec3 encodedNormal = texture(colortex2,texcoord).rgb;
  vec3 normal = normalize((encodedNormal - 0.5) * 2.0); // we normalize to make sure it is of unit length

  vec3 blocklight = lightmap.r * blocklightColor;
  vec3 skylight = lightmap.g * skylightColor;
  vec3 ambient = ambientColor;

  float depth = texture(depthtex0, texcoord).r;

  if (depth == 1.0) {
    return;
  }
  vec3 NDCPos = vec3(texcoord.xy, depth) * 2.0 - 1.0;
  vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);
  vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
  vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
  vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);
  vec3 shadowNDCPos = shadowClipPos.xyz / shadowClipPos.w;
  vec3 shadowScreenPos = shadowNDCPos * 0.5 + 0.5;
  
  float shadow = step(shadowScreenPos.z, texture(shadowtex0, shadowScreenPos.xy).r);
  vec3 lightVector = normalize(shadowLightPosition);
  vec3 worldLightVector = mat3(gbufferModelViewInverse) * lightVector;
  vec3 sunlight = sunlightColor * clamp(dot(worldLightVector, normal), 0.0, 1.0) * shadow;
  
  color.rgb *= blocklight + skylight + ambient + sunlight;


}