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

constant float TIMESTEP = 0.02;

constant vector_float3 GRAVITY = vector_float3(0, -5, 0);
constant float VISCOSITY = 1.0016;
constant float K_VORT = 1;

struct Fragment {
    float4 position [[ position ]];
    float4 color;
    float size [[ point_size ]];
};

int get1DIndexFrom3DIndex(int i, int j, int k) {
    return i + WATERGRID_X * (j + WATERGRID_Y * k);
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
}

kernel void applyExternalForces(const device Particle* particles [[ buffer(0) ]],
                                device Cell* waterGrid [[ buffer(2) ]],
                                uint tid [[ thread_position_in_grid ]]) {
    Particle p = particles[tid];
    int i = p.position[0];
    int j = p.position[1];
    int k = p.position[2];
    
    // Update center
    int index = get1DIndexFrom3DIndex(i, j, k);
    if (waterGrid[index].forceWasApplied == 0) {
        waterGrid[index].currVelocity += TIMESTEP * GRAVITY;
        waterGrid[index].forceWasApplied = 1;
    }
    
    // Update up
    if (isInBounds(i, j + 1, k)) {
        index = get1DIndexFrom3DIndex(i, j + 1, k);
        if (waterGrid[index].forceWasApplied == 0) {
            waterGrid[index].currVelocity += TIMESTEP * GRAVITY;
            waterGrid[index].forceWasApplied = 1;
        }
    }
    
    // Update down
    if (isInBounds(i, j - 1, k)) {
        index = get1DIndexFrom3DIndex(i, j - 1, k);
        if (waterGrid[index].forceWasApplied == 0) {
            waterGrid[index].currVelocity += TIMESTEP * GRAVITY;
            waterGrid[index].forceWasApplied = 1;
        }
    }
    
    // Update left
    if (isInBounds(i - 1, j, k)) {
        index = get1DIndexFrom3DIndex(i - 1, j, k);
        if (waterGrid[index].forceWasApplied == 0) {
            waterGrid[index].currVelocity += TIMESTEP * GRAVITY;
            waterGrid[index].forceWasApplied = 1;
        }
    }
    
    // Update right
    if (isInBounds(i + 1, j, k)) {
        index = get1DIndexFrom3DIndex(i + 1, j, k);
        if (waterGrid[index].forceWasApplied == 0) {
            waterGrid[index].currVelocity += TIMESTEP * GRAVITY;
            waterGrid[index].forceWasApplied = 1;
        }
    }
    
    // Update forward
    if (isInBounds(i, j, k + 1)) {
        index = get1DIndexFrom3DIndex(i, j, k + 1);
        if (waterGrid[index].forceWasApplied == 0) {
            waterGrid[index].currVelocity += TIMESTEP * GRAVITY;
            waterGrid[index].forceWasApplied = 1;
        }
    }
    
    // Update backward
    if (isInBounds(i, j, k - 1)) {
        index = get1DIndexFrom3DIndex(i, j, k - 1);
        if (waterGrid[index].forceWasApplied == 0) {
            waterGrid[index].currVelocity += TIMESTEP * GRAVITY;
            waterGrid[index].forceWasApplied = 1;
        }
    }
}

float laplacianOperatorOnVelocity(device Cell* waterGrid, int i, int j, int k, int idx) {
    float laplacianVelocity = 0;

    // i direction
    int cellIndex = get1DIndexFrom3DIndex(i+1, j, k);
    laplacianVelocity += (i+1 < WATERGRID_X) ? waterGrid[cellIndex].currVelocity[idx] : 0;
    cellIndex = get1DIndexFrom3DIndex(i-1, j, k);
    laplacianVelocity += (i-1 >= 0         ) ? waterGrid[cellIndex].currVelocity[idx] : 0;

    // j direction
    cellIndex = get1DIndexFrom3DIndex(i, j+1, k);
    laplacianVelocity += (j+1 < WATERGRID_Y) ? waterGrid[cellIndex].currVelocity[idx] : 0;
    cellIndex = get1DIndexFrom3DIndex(i, j-1, k);
    laplacianVelocity += (j-1 >= 0         ) ? waterGrid[cellIndex].currVelocity[idx] : 0;

    // k direction
    cellIndex = get1DIndexFrom3DIndex(i, j, k+1);
    laplacianVelocity += (k+1 < WATERGRID_Z) ? waterGrid[cellIndex].currVelocity[idx] : 0;
    cellIndex = get1DIndexFrom3DIndex(i, j, k-1);
    laplacianVelocity += (k-1 >= 0         ) ? waterGrid[cellIndex].currVelocity[idx] : 0;

    // -6*currCellCurrVelocity term
    cellIndex = get1DIndexFrom3DIndex(i, j, k);
    laplacianVelocity -= 6 * waterGrid[cellIndex].currVelocity[idx];

    return laplacianVelocity;
}

vector_float3 calculateCurl(device Cell* waterGrid, int i, int j, int k) {
    vector_float3 curl(0, 0, 0);
    
    /// uz / y
    curl[0] += (j+1 < WATERGRID_Y) ? waterGrid[get1DIndexFrom3DIndex(i, j+1, k)].oldVelocity[2] : 0;
    curl[0] -= (j-1 >= 0         ) ? waterGrid[get1DIndexFrom3DIndex(i, j-1, k)].oldVelocity[2] : 0;
    /// uy / z
    curl[0] -= (k+1 < WATERGRID_Z) ? waterGrid[get1DIndexFrom3DIndex(i, j, k+1)].oldVelocity[1] : 0;
    curl[0] += (k-1 >= 0         ) ? waterGrid[get1DIndexFrom3DIndex(i, j, k-1)].oldVelocity[1] : 0;

    /// ux / z
    curl[1] += (k+1 < WATERGRID_Z) ? waterGrid[get1DIndexFrom3DIndex(i, j, k+1)].oldVelocity[0] : 0;
    curl[1] -= (k-1 >= 0         ) ? waterGrid[get1DIndexFrom3DIndex(i, j, k-1)].oldVelocity[0] : 0;
    /// uz / x
    curl[1] -= (i+1 < WATERGRID_X) ? waterGrid[get1DIndexFrom3DIndex(i+1, j, k)].oldVelocity[2] : 0;
    curl[1] += (i-1 >= 0         ) ? waterGrid[get1DIndexFrom3DIndex(i-1, j, k)].oldVelocity[2] : 0;

    /// uy / x
    curl[2] += (i+1 < WATERGRID_X) ? waterGrid[get1DIndexFrom3DIndex(i+1, j, k)].oldVelocity[1] : 0;
    curl[2] -= (i-1 >= 0         ) ? waterGrid[get1DIndexFrom3DIndex(i-1, j, k)].oldVelocity[1] : 0;
    /// ux / y
    curl[2] -= (j+1 < WATERGRID_Y) ? waterGrid[get1DIndexFrom3DIndex(i, j+1, k)].oldVelocity[0] : 0;
    curl[2] += (j-1 >= 0         ) ? waterGrid[get1DIndexFrom3DIndex(i, j-1, k)].oldVelocity[0] : 0;

    return curl;
}

float calculateNorm(vector_float3 v) {
    return sqrt(v[0]*v[0] + v[1]*v[1] + v[2]*v[2]);
}

vector_float3 getCurlGradient(device Cell* waterGrid, int i, int j, int k){
    vector_float3 gradient(0, 0, 0);
    gradient[0] += (i+1 < WATERGRID_X) ? calculateNorm(waterGrid[get1DIndexFrom3DIndex(i, j+1, k)].curl) : 0;
    gradient[0] -= (i-1 >= 0         ) ? calculateNorm(waterGrid[get1DIndexFrom3DIndex(i-1, j, k)].curl) : 0;
    gradient[1] += (j+1 < WATERGRID_Y) ? calculateNorm(waterGrid[get1DIndexFrom3DIndex(i, j+1, k)].curl) : 0;
    gradient[1] -= (j-1 >= 0         ) ? calculateNorm(waterGrid[get1DIndexFrom3DIndex(i, j-1, k)].curl) : 0;
    gradient[2] += (k+1 < WATERGRID_Z) ? calculateNorm(waterGrid[get1DIndexFrom3DIndex(i, j, k+1)].curl) : 0;
    gradient[2] += (k-1 < WATERGRID_Z) ? calculateNorm(waterGrid[get1DIndexFrom3DIndex(i, j, k-1)].curl) : 0;
    return gradient;
}

kernel void applyViscosity(device Cell* waterGrid [[ buffer(2) ]],
                           uint3 tid [[ thread_position_in_grid ]]) {
    if (!isInBounds(tid[0], tid[1], tid[2])) { return; }
    int cellIndex = get1DIndexFrom3DIndex(tid[0], tid[1], tid[2]);
    
    // Reset forceWasApplied term from previous applyExternalForces() call
    waterGrid[cellIndex].forceWasApplied = 0;
    
    // Apply viscosity term
    int i = tid[0];
    int j = tid[1];
    int k = tid[2];
    float u_x = laplacianOperatorOnVelocity(waterGrid, i, j, k, 0);
    float u_y = laplacianOperatorOnVelocity(waterGrid, i, j, k, 1);
    float u_z = laplacianOperatorOnVelocity(waterGrid, i, j, k, 2);
    waterGrid[cellIndex].currVelocity += TIMESTEP * VISCOSITY * vector_float3(u_x, u_y, u_z);
    
    // Calculate Curl
    waterGrid[cellIndex].curl = calculateCurl(waterGrid, tid[0], tid[1], tid[2]);
}

kernel void applyVorticityConfinement(device Cell* waterGrid [[ buffer(2) ]],
                                      uint3 tid [[ thread_position_in_grid ]]) {
    if (!isInBounds(tid[0], tid[1], tid[2])) { return; }
    int cellIndex = get1DIndexFrom3DIndex(tid[0], tid[1], tid[2]);
    
    // Apply vorticity confinement term
    vector_float3 curl = waterGrid[cellIndex].curl;
    if (curl[0] > 0 || curl[1] > 0 || curl[2] > 0) {
        vector_float3 N = getCurlGradient(waterGrid, tid[0], tid[1], tid[2]) / calculateNorm(curl);
        vector_float3 F_vort = K_VORT * cross(N, curl);
        waterGrid[cellIndex].currVelocity += TIMESTEP * F_vort;
    }
    
    // Make oldVelocity be currVelocity
    waterGrid[cellIndex].oldVelocity = waterGrid[cellIndex].currVelocity;
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
        p.velocity += TIMESTEP * v;
        p.position += TIMESTEP * p.velocity;
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
