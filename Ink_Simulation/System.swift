//
//  System.swift
//  Ink_Simulation
//
//  Created by Helen Huang on 4/30/23.
//

import MetalKit

class System {
    var camera: Camera
    var particles: [Particle]
    
    init() {
        self.camera = Camera(position: [0, 0, -3], eulers: [0, 0, 0])
        self.particles = [
            Particle(position: [0, 0, 0], color: [0, 1, 0, 1]),
            Particle(position: [-1, -1, 3], color: [1, 0, 0, 1]),
            Particle(position: [1, 1, 1], color: [0, 0, 1, 1])
        ]
    }
    
    func update() {
        camera.updateVectors()
    }
}
