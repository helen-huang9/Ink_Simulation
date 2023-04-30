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

vertex Fragment vertexShader(const device Particle* particleArray [[ buffer(0) ]], uint index [[ vertex_id ]]) {
    Particle input = particleArray[index];
    
    Fragment output;
    output.position = float4(input.position.x, input.position.y, 0, 1);
    output.color = input.color;
    output.size = input.size;
    
    return output;
}

fragment float4 fragmentShader(Fragment input [[ stage_in ]]) {
    return input.color;
}
