//
//  Types.h
//  Ink_Simulation
//
//  Created by Helen Huang on 4/30/23.
//

#ifndef Types_h
#define Types_h

#include <simd/simd.h>

struct Particle {
    vector_float3 position;
    vector_float3 velocity;
    vector_float4 color;
};

struct Cell {
    vector_float3 oldVelocity;
    vector_float3 currVelocity;
    vector_float3 curl;
    int forceWasApplied;
};

#endif /* Types_h */
