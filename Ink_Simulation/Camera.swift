//
//  Camera.swift
//  Ink_Simulation
//
//  Created by Helen Huang on 4/30/23.
//

class Camera {
    var position: vector_float3
    var eulers: vector_float3
    
    var look: vector_float3
    var right: vector_float3
    var up: vector_float3
    
    init(position: vector_float3, eulers: vector_float3) {
        self.position = position
        self.eulers = eulers
        
        self.look = [0, 0, 0]
        self.right = [0, 0, 0]
        self.up = [0, 0, 0]
    }
    
    func updateVectors() {
        self.look = [
            cos(eulers[1] * .pi / 180.0) * sin(eulers[0] * .pi / 180.0),
            sin(eulers[1] * .pi / 180.0) * sin(eulers[0] * .pi / 180.0),
            cos(eulers[0] * .pi / 180.0)
        ]
        
        self.right = simd.cross(vector_float3(0, 1, 0), self.look)
        self.up = simd.cross(self.look, right)
    }
}
