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
    vector_float2 position;
    vector_float4 color;
    float size;
};

#endif /* Types_h */
