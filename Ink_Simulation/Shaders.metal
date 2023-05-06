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
constant float TIMESTEP = 0.01;

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

float getInterpolatedValue(device Cell* waterGrid, float x, float y, float z, int idx) {
    int i = int(x);
    int j = int(y);
    int k = int(z);
    
    float weightAccum = 0;
    float totalAccum = 0;
    
    if (isInBounds(i, j, k)) {
        int cellIndex = get1DIndexFrom3DIndex(i, j, k);
        totalAccum  += (i + 1 - x) * (j + 1 - y) * (k + 1 - z) * waterGrid[cellIndex].oldVelocity[idx];
    }
    weightAccum += (i + 1 - x) * (j + 1 - y) * (k + 1 - z);

    if (isInBounds(i + 1, j, k)) {
        int cellIndex = get1DIndexFrom3DIndex(i + 1, j, k);
        totalAccum  += (x - i) * (j + 1 - y) * (k + 1 - z) * waterGrid[cellIndex].oldVelocity[idx];
    }
    weightAccum += (x - i) * (j + 1 - y) * (k + 1 - z);

    if (isInBounds(i, j + 1, k)) {
        int cellIndex = get1DIndexFrom3DIndex(i, j + 1, k);
        totalAccum  += (i + 1 - x) * (y - j) * (k + 1 - z) * waterGrid[cellIndex].oldVelocity[idx];
    }
    weightAccum += (i + 1 - x) * (y - j) * (k + 1 - z);

    if (isInBounds(i + 1, j + 1, k)) {
        int cellIndex = get1DIndexFrom3DIndex(i + 1, j + 1, k);
        totalAccum  += (x - i) * (y - j) * (k + 1 - z) * waterGrid[cellIndex].oldVelocity[idx];
    }
    weightAccum += (x - i) * (y - j) * (k + 1 - z);

    if (isInBounds(i, j, k + 1)) {
        int cellIndex = get1DIndexFrom3DIndex(i, j, k + 1);
        totalAccum  += (i + 1 - x) * (j + 1 - y) * (z - k) * waterGrid[cellIndex].oldVelocity[idx];
    }
    weightAccum += (i + 1 - x) * (j + 1 - y) * (z - k);

    if (isInBounds(i + 1, j, k + 1)) {
        int cellIndex = get1DIndexFrom3DIndex(i + 1, j, k + 1);
        totalAccum += (x - i) * (j + 1 - y) * (z - k) * waterGrid[cellIndex].oldVelocity[idx];
    }
    weightAccum += (x - i) * (j + 1 - y) * (z - k);

    if (isInBounds(i, j + 1, k + 1)) {
        int cellIndex = get1DIndexFrom3DIndex(i, j + 1, k + 1);
        totalAccum  += (i + 1 - x) * (y - j) * (z - k) * waterGrid[cellIndex].oldVelocity[idx];
    }
    weightAccum += (i + 1 - x) * (y - j) * (z - k);

    if (isInBounds(i + 1, j + 1, k + 1)) {
        int cellIndex = get1DIndexFrom3DIndex(i + 1, j + 1, k + 1);
        totalAccum  += (x - i) * (y - j) * (z - k) * waterGrid[cellIndex].oldVelocity[idx];
    }
    weightAccum += (x - i) * (y - j) * (z - k);

    if (weightAccum == 0) {
        return 0;
    }
    return totalAccum / weightAccum;
}

vector_float3 getVelocity(device Cell* waterGrid, float x, float y, float z) {
    float newX = getInterpolatedValue(waterGrid, x, y - 0.5, z - 0.5, 0);
    float newY = getInterpolatedValue(waterGrid, x - 0.5, y, z - 0.5, 1);
    float newZ = getInterpolatedValue(waterGrid, x - 0.5, y - 0.5, z, 2);
    return vector_float3(newX, newY, newZ);
}

/**
 Performs a particle trace along the water gri'd current velocity field starting from the inputted (x, y, z) position.
 Returns the position of the particle after performing the particle trace
 */
vector_float3 traceParticle(device Cell* waterGrid, float x, float y, float z, float t) {
    vector_float3 vel = getVelocity(waterGrid, x, y, z);
    vel = getVelocity(waterGrid, x + 0.5*TIMESTEP*vel[0], y + 0.5*TIMESTEP*vel[1], z + 0.5*TIMESTEP*vel[2]);
    return vector_float3(x, y, z) + vel;
}

/// Apply the convection term to the water grid. Uses oldVelocity to update currVelocity
kernel void applyConvection(device Cell* waterGrid [[ buffer(2) ]],
                            uint3 tid [[ thread_position_in_grid ]]) {
    if (!isInBounds(tid[0], tid[1], tid[2])) { return; }
    
    // Backwards particle trace
    vector_float3 virtualParticlePos = traceParticle(waterGrid, tid[0] + 0.5, tid[1] + 0.5, tid[2] + 0.5, -TIMESTEP);

    // Get the velocity from the virtual particle
    int i = int(virtualParticlePos[0]);
    int j = int(virtualParticlePos[1]);
    int k = int(virtualParticlePos[2]);
    vector_float3 newVelocity = vector_float3(0, 0, 0);
    if (isInBounds(i, j, k)) {
        int virtCellIndex = get1DIndexFrom3DIndex(i, j, k);
        newVelocity = waterGrid[virtCellIndex].oldVelocity;
    }
    
    // Set the cell's currVelocity
    int cellIndex = get1DIndexFrom3DIndex(tid[0], tid[1], tid[2]);
    waterGrid[cellIndex].currVelocity = newVelocity;
    
    // TODO: Calculate curl
}

kernel void applyExternalForces(device Cell* waterGrid [[ buffer(2) ]],
                                uint3 tid [[ thread_position_in_grid ]]) {
    if (!isInBounds(tid[0], tid[1], tid[2])) { return; }
    int cellIndex = get1DIndexFrom3DIndex(tid[0], tid[1], tid[2]);
    
    // TODO: Add external forces term
//    waterGrid[cellIndex].currVelocity[1] = -1;
}

kernel void applyViscosity(device Cell* waterGrid [[ buffer(2) ]],
                           uint3 tid [[ thread_position_in_grid ]]) {
    if (!isInBounds(tid[0], tid[1], tid[2])) { return; }
    int cellIndex = get1DIndexFrom3DIndex(tid[0], tid[1], tid[2]);
    
    // TODO: Add viscosity term
//    waterGrid[cellIndex].currVelocity[1] = -1;
}

kernel void applyVorticityConfinement(device Cell* waterGrid [[ buffer(2) ]],
                                      uint3 tid [[ thread_position_in_grid ]]) {
    if (!isInBounds(tid[0], tid[1], tid[2])) { return; }
    int cellIndex = get1DIndexFrom3DIndex(tid[0], tid[1], tid[2]);
    
    // TODO: Add vorticity confinement term
//    waterGrid[cellIndex].currVelocity[1] = -1;
}


/// Updates the particle positions
kernel void updateParticles(device Particle* particleArray [[ buffer(0) ]],
                            const device Cell* waterGrid [[ buffer(2) ]],
                            uint tid [[ thread_position_in_grid ]]) {
    // Get the particle
    Particle p = particleArray[tid];
    
    // Get the cell the particle is in
    int i = p.position.x;
    int j = p.position.y;
    int k = p.position.z;
    
    // Update the particle if its in bounds
    if (isInBounds(i, j, k)) {
        // TODO: Change to use Midpoint Method
        int cellIndex = get1DIndexFrom3DIndex(i, j, k);
        vector_float3 v = waterGrid[cellIndex].currVelocity;
        p.position += TIMESTEP * v; // TODO: currently hardcoding particle timestep
        particleArray[tid] = p;
    }
}

/// Vertex shader
vertex Fragment vertexShader(const device Particle* particleArray [[ buffer(0) ]],
                             constant matrix_float4x4 &viewProj [[ buffer(1) ]],
                             uint tid [[ vertex_id ]]) {
    
    // Create fragment to be passed to fragment shader
    Particle input = particleArray[tid];
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
