//
//  System.swift
//  Ink_Simulation
//
//  Created by Helen Huang on 4/30/23.
//

import MetalKit

let WATERGRID_X = 8
let WATERGRID_Y = 8
let WATERGRID_Z = 8

class System {
    var camera: Camera
    var particles: [Particle]
    var waterGrid: [Cell]
    
    init() {
        self.camera = Camera(position: [0, 0, -3], eulers: [0, 0, 0])
        self.particles = []
        self.waterGrid = []
        
        initParticles()
        initWaterGrid()
    }
    
    func initWaterGrid() {
        for _ in 0...WATERGRID_X-1 {
            for _ in 0...WATERGRID_Y-1 {
                for _ in 0...WATERGRID_Z-1 {
                    self.waterGrid.append(Cell(oldVelocity: [0, 0, 0], currVelocity: [0, 0, 0], curl: [0, 0, 0]))
                }
            }
        }
    }
    
    func initParticles() {
        self.particles = [
            Particle(position: [0, 0, 0], color: [0, 0, 0, 1]),
            Particle(position: [-1, -1, 3], color: [0, 0, 0, 1]),
            Particle(position: [1, 1, 1], color: [0, 0, 0, 1])
        ]
    }
    
    func update() {
        camera.updateVectors()
    }
    
    func get1DIndexFrom3DIndex(i: Int, j: Int, k: Int) -> Int {
        return i + WATERGRID_X * (j + WATERGRID_Y * j)
    }
}
