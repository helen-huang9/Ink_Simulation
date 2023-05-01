//
//  Shaders.metal
//  Ink_Simulation
//
//  Created by Helen Huang on 4/30/23.
//

#include <metal_stdlib>
#include "Types.h"

using namespace metal;

struct Fragment {
    float4 position [[ position ]];
    float4 color;
    float size [[ point_size ]];
};

vertex Fragment vertexShader(const device Particle* particleArray [[ buffer(0) ]],
                             constant matrix_float4x4 &viewProj [[ buffer(1) ]],
                             uint index [[ vertex_id ]]) {
    
    // Create fragment to be passed to fragment shader
    Particle input = particleArray[index];
    Fragment output;
    output.position = viewProj * float4(input.position.x, input.position.y, input.position.z, 1);
    output.color = input.color;
    output.size = 7;
    
    return output;
}

fragment float4 fragmentShader(Fragment input [[ stage_in ]]) {
    return input.color;
}
