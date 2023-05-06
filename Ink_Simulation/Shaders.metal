//
//  Shaders.metal
//  Ink_Simulation
//
//  Created by Helen Huang on 4/30/23.
//

#include <metal_stdlib>
#include "Types.h"

using namespace metal;

constant int WATERGRID_X = 15;
constant int WATERGRID_Y = 15;
constant int WATERGRID_Z = 15;

struct Fragment {
    float4 position [[ position ]];
    float4 color;
    float size [[ point_size ]];
};

int get1DIndexFrom3DIndex(int i, int j, int k) {
    return i + WATERGRID_X * (j + WATERGRID_Y * j);
}

bool isInBounds(int i, int j, int k) {
    bool inXRange = i >= 0 && i < WATERGRID_X;
    bool inYRange = j >= 0 && j < WATERGRID_Y;
    bool inZRange = k >= 0 && k < WATERGRID_Z;
    return inXRange && inYRange && inZRange;
}


kernel void applyConvection(device Cell* waterGrid [[ buffer(2) ]],
                            uint3 index [[ thread_position_in_grid ]]) {
    if (!isInBounds(index[0], index[1], index[2])) { return; }
    int cellIndex = get1DIndexFrom3DIndex(index[0], index[1], index[2]);
    
    // TODO: Add convection term
//    waterGrid[cellIndex].currVelocity[1] = -1;
    
}

kernel void applyExternalForces(device Cell* waterGrid [[ buffer(2) ]],
                                uint3 index [[ thread_position_in_grid ]]) {
    if (!isInBounds(index[0], index[1], index[2])) { return; }
    int cellIndex = get1DIndexFrom3DIndex(index[0], index[1], index[2]);
    
    // TODO: Add external forces term
//    waterGrid[cellIndex].currVelocity[1] = -1;
}

kernel void applyViscosity(device Cell* waterGrid [[ buffer(2) ]],
                           uint3 index [[ thread_position_in_grid ]]) {
    if (!isInBounds(index[0], index[1], index[2])) { return; }
    int cellIndex = get1DIndexFrom3DIndex(index[0], index[1], index[2]);
    
    // TODO: Add viscosity term
//    waterGrid[cellIndex].currVelocity[1] = -1;
}

kernel void applyVorticityConfinement(device Cell* waterGrid [[ buffer(2) ]],
                                      uint3 index [[ thread_position_in_grid ]]) {
    if (!isInBounds(index[0], index[1], index[2])) { return; }
    int cellIndex = get1DIndexFrom3DIndex(index[0], index[1], index[2]);
    
    // TODO: Add vorticity confinement term
//    waterGrid[cellIndex].currVelocity[1] = -1;
}


/// Updates the particle positions
kernel void updateParticles(device Particle* particleArray [[ buffer(0) ]],
                            const device Cell* waterGrid [[ buffer(2) ]],
                            uint index [[ thread_position_in_grid ]]) {
    // Get the particle
    Particle p = particleArray[index];
    
    // Get the cell the particle is in
    int i = p.position.x;
    int j = p.position.y;
    int k = p.position.z;
    
    // Update the particle if its in bounds
    if (isInBounds(i, j, k)) {
        // TODO: Change to use Midpoint Method
        int cellIndex = get1DIndexFrom3DIndex(i, j, k);
        vector_float3 v = waterGrid[cellIndex].currVelocity;
        p.position += 0.01 * v; // TODO: currently hardcoding particle timestep
        particleArray[index] = p;
    }
}

/// Vertex shader
vertex Fragment vertexShader(const device Particle* particleArray [[ buffer(0) ]],
                             constant matrix_float4x4 &viewProj [[ buffer(1) ]],
                             uint index [[ vertex_id ]]) {
    
    // Create fragment to be passed to fragment shader
    Particle input = particleArray[index];
    Fragment output;
    output.position = viewProj * float4(input.position.x, input.position.y, input.position.z, 1);
    output.color = input.color;
    output.size = 1;
    
    return output;
}

/// Fragment shader
fragment float4 fragmentShader(Fragment input [[ stage_in ]]) {
    return input.color;
}
