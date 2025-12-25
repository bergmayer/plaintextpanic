#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Barrel distortion shader - creates CRT screen bulge effect
// For barrel distortion (CRT bulge where center appears magnified),
// we sample from positions CLOSER to center than the output position
[[ stitchable ]] float2 crtBulge(float2 position, float4 bounds, float strength) {
    // Get center of the view
    float2 center = float2(bounds.z / 2.0, bounds.w / 2.0);

    // Calculate normalized coordinates from center (-1 to 1)
    float2 coord = (position - center) / center;

    // Calculate squared distance from center
    float r2 = dot(coord, coord);

    // Apply barrel distortion - sample from positions further from center at edges
    // This compresses edges and magnifies center (convex CRT bulge)
    float distortion = 1.0 + r2 * strength;

    // Apply the distortion
    float2 distorted = coord * distortion;

    // Convert back to pixel coordinates
    return distorted * center + center;
}
