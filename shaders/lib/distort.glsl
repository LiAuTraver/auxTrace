const int shadowMapResolution = 2048; // simple way to make shadow sharper, but can cause performance issues
const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;
const bool shadowcolor0Nearest = true;

vec3 distortShadowClipPos(vec3 shadowClipPos){
  // Euclidean distance from the player in shadow clip space
  float distortionFactor = length(shadowClipPos.xy); 
  // very small distances can cause issues so we add this to slightly reduce the distortion
  distortionFactor += 0.1; 

  shadowClipPos.xy /= distortionFactor;
  shadowClipPos.z *= 0.5; // increases shadow distance on the Z axis, which helps when the sun is very low in the sky
  return shadowClipPos;
}