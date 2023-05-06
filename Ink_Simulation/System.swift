//
//  System.swift
//  Ink_Simulation
//
//  Created by Helen Huang on 4/30/23.
//

import MetalKit

let WATERGRID_X = 15
let WATERGRID_Y = 15
let WATERGRID_Z = 15
let TOTAL_PARTICLES = 10000

class System {
    var camera: Camera
    var particles: [Particle]
    var waterGrid: [Cell]
    
    init() {
        self.camera = Camera(position: [Float(WATERGRID_X/2), Float(WATERGRID_Y/2), Float(-WATERGRID_Z)], eulers: [0, 0, 0])
        self.particles = []
        self.waterGrid = []
        
        initParticles()
        initWaterGrid()
    }
    
    func initWaterGrid() {
        let totalCells = WATERGRID_X * WATERGRID_Y * WATERGRID_Z
        for _ in 0..<totalCells {
            self.waterGrid.append(Cell(oldVelocity: [0, 0, 0], currVelocity: [0, 0, 0], curl: [0, 0, 0]))
        }
    }
    
    func getRandPosInRange(minX: Float, maxX: Float, minY: Float, maxY: Float, minZ: Float, maxZ: Float) -> vector_float3 {
        let randX = Float.random(in: minX...maxX)
        let randY = Float.random(in: minY...maxY)
        let randZ = Float.random(in: minZ...maxZ)
        return vector_float3(randX, randY, randZ)
    }
    
    func initParticles() {
        for _ in 0..<TOTAL_PARTICLES {
            let randPos = getRandPosInRange(minX: Float(WATERGRID_X/2)-1, maxX: Float(WATERGRID_X/2)+1,
                                            minY: Float(WATERGRID_Y)-0.1, maxY: Float(WATERGRID_Y)-0.1,
                                            minZ: Float(WATERGRID_Z/2)-1, maxZ: Float(WATERGRID_Z/2)+1)
            self.particles.append(Particle(position: randPos, color: vector_float4(0, 0, 0, 1)))
        }
    }
    
    func update() {
        camera.updateVectors()
    }
    
    func get1DIndexFrom3DIndex(i: Int, j: Int, k: Int) -> Int {
        return i + WATERGRID_X * (j + WATERGRID_Y * j)
    }
}
