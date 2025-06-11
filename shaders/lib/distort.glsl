vec3 distortShadowClipPos(vec3 shadowClipPos){
  // Euclidean distance from the player in shadow clip space
  float distortionFactor = length(shadowClipPos.xy); 
  // very small distances can cause issues so we add this to slightly reduce the distortion
  distortionFactor += 0.1; 

  shadowClipPos.xy /= distortionFactor;
  shadowClipPos.z *= 0.5; // increases shadow distance on the Z axis, which helps when the sun is very low in the sky
  return shadowClipPos;
}