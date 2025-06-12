#version 330 compatibility

#include "/lib/distort.glsl"

// constant variables which was defined by developer(we)
const vec3 blocklightColor = vec3(1.0, 0.5, 0.08);
const vec3 skylightColor = vec3(0.05, 0.15, 0.3);
const vec3 sunlightColor = vec3(1.0);
const vec3 ambientColor = vec3(0.1);

uniform sampler2D colortex0; // info of blocks and entities
uniform sampler2D colortex1; // lightmap data
uniform sampler2D colortex2; // encoded surface normals

uniform vec3 shadowLightPosition;

// these variables were provided by Iris/OptiFine and aren't standard GL variables
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform sampler2D shadowtex0; // everything that casts shadows
uniform sampler2D shadowtex1; // only opaque stuff that casts shadows
uniform sampler2D shadowcolor0; // color and alpha of the shadow caster

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

vec3 getShadow(vec3 shadowScreenPos){
  // sample the shadow map containing everything
  float transparentShadow = step(shadowScreenPos.z, texture(shadowtex0, shadowScreenPos.xy).r);

  // a value of 1.0 means 100% of sunlight is getting through, not 100% shadowing
  if(transparentShadow == 1.0){
    // no shadow at all, return full sunlight
    return vec3(1.0);
  }

  float opaqueShadow = step(shadowScreenPos.z, texture(shadowtex1, shadowScreenPos.xy).r); // sample the shadow map containing only opaque stuff

  if(opaqueShadow == 0.0){
    // there is a shadow cast by something opaque, return no sunlight
    return vec3(0.0);
  }

  // contains the color and alpha (transparency) of the thing casting a shadow
  vec4 shadowColor = texture(shadowcolor0, shadowScreenPos.xy);


  /*
  use 1 - the alpha to get how much light is let through
  and multiply that light by the color of the caster
  */
  return shadowColor.rgb * (1.0 - shadowColor.a);
}
#define SHADOW_QUALITY 2
#define SHADOW_SOFTNESS 1
vec3 getSoftShadow(vec4 shadowClipPos){
  const float range = SHADOW_SOFTNESS / 2.0; // how far away from the original position we take our samples from
  const float increment = range / SHADOW_QUALITY; // distance between each sample

  vec3 shadowAccum = vec3(0.0); // sum of all shadow samples
  int samples = 0;

  for(float x = -range; x <= range; x += increment){
    for (float y = -range; y <= range; y+= increment){
      vec2 offset = vec2(x, y) / shadowMapResolution; // we divide by the resolution so our offset is in terms of pixels
      vec4 offsetShadowClipPos = shadowClipPos + vec4(offset, 0.0, 0.0); // add offset
      offsetShadowClipPos.z -= 0.001; // apply bias
      offsetShadowClipPos.xyz = distortShadowClipPos(offsetShadowClipPos.xyz); // apply distortion
      vec3 shadowNDCPos = offsetShadowClipPos.xyz / offsetShadowClipPos.w; // convert to NDC space
      vec3 shadowScreenPos = shadowNDCPos * 0.5 + 0.5; // convert to screen space
      shadowAccum += getShadow(shadowScreenPos); // take shadow sample
      samples++;
    }
  }

  return shadowAccum / float(samples); // divide sum by count, getting average shadow
}
void main() {
	color = texture(colortex0, texcoord);
  // gamma correction, revert it in `final.fsh/vsh`
  color.rgb = pow(color.rgb, vec3(2.2));
	
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
  // avoid `shadow acne` by `biasing` the shadow position,
  // see https://computergraphics.stackexchange.com/questions/2192/cause-of-shadow-acne/2193
  // shadowClipPos -= 0.001;
  // shadowClipPos.xyz = distortShadowClipPos(shadowClipPos.xyz); // distortion
  // vec3 shadowNDCPos = shadowClipPos.xyz / shadowClipPos.w;
  // vec3 shadowScreenPos = shadowNDCPos * 0.5 + 0.5;
  
  // float shadow = step(shadowScreenPos.z, texture(shadowtex0, shadowScreenPos.xy).r);
  vec3 shadow = getSoftShadow(shadowClipPos);
  vec3 lightVector = normalize(shadowLightPosition);
  vec3 worldLightVector = mat3(gbufferModelViewInverse) * lightVector;
  vec3 sunlight = sunlightColor * clamp(dot(worldLightVector, normal), 0.0, 1.0) * shadow;
  
  color.rgb *= blocklight + skylight + ambient + sunlight;


}