//
//  Renderer.swift
//  Ink_Simulation
//
//  Created by Helen Huang on 4/30/23.
//

import MetalKit

class Renderer: NSObject, MTKViewDelegate {
    
    // Data
    var parent: ContentView
    let system: System
    var particleBuffer: MTLBuffer!
    var waterGridBuffer: MTLBuffer!
    
    // GPU
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
        
    // Compute Pipelines
    let computeConvectionPipeline: MTLComputePipelineState
    let computeExternalForcesPipeline: MTLComputePipelineState
    let computeViscosityPipeline: MTLComputePipelineState
    let computeVorticityConfinementPipeline: MTLComputePipelineState
    
    let computeParticlePipeline: MTLComputePipelineState
    
    // Render Pipeline
    let renderPipeline: MTLRenderPipelineState
    
    init(_ parent: ContentView) {
        // Get the GPU device and init a command queue
        self.parent = parent
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            self.device = metalDevice
        }
        self.commandQueue = self.device.makeCommandQueue()
        
        // Create the MTL library
        let library = self.device.makeDefaultLibrary()
        
        // Set up the Compute pipelines
        do {
            // Convection
            let applyConvectionFunc = library?.makeFunction(name: "applyConvection")
            try self.computeConvectionPipeline = self.device.makeComputePipelineState(function: applyConvectionFunc!, options: [], reflection: nil)
            
            // External Forces
            let applyExternalForcesFunc = library?.makeFunction(name: "applyExternalForces")
            try self.computeExternalForcesPipeline = self.device.makeComputePipelineState(function: applyExternalForcesFunc!, options: [], reflection: nil)
            
            // Viscosity
            let applyViscosityFunc = library?.makeFunction(name: "applyViscosity")
            try self.computeViscosityPipeline = self.device.makeComputePipelineState(function: applyViscosityFunc!, options: [], reflection: nil)
            
            // Vorticity Confinement
            let applyVorticityConfinementFunc = library?.makeFunction(name: "applyVorticityConfinement")
            try self.computeVorticityConfinementPipeline = self.device.makeComputePipelineState(function: applyVorticityConfinementFunc!, options: [], reflection: nil)
        } catch {
            fatalError()
        }
        do {
            let updateParticlesFunc = library?.makeFunction(name: "updateParticles")
            try self.computeParticlePipeline = self.device.makeComputePipelineState(function: updateParticlesFunc!, options: [], reflection: nil)
        } catch {
            fatalError()
        }
        
        // Set up the Render pipeline
        let renderPipeDescriptor = MTLRenderPipelineDescriptor()
        renderPipeDescriptor.vertexFunction = library?.makeFunction(name: "vertexShader")
        renderPipeDescriptor.fragmentFunction = library?.makeFunction(name: "fragmentShader")
        renderPipeDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        do {
            try self.renderPipeline = self.device.makeRenderPipelineState(descriptor: renderPipeDescriptor)
        } catch {
            fatalError()
        }
        
        // Init system, create the particle buffer, and create the water buffer
        self.system = System()
        self.particleBuffer = self.device.makeBuffer(bytes: self.system.particles, length: self.system.particles.count * MemoryLayout<Particle>.stride, options: .storageModeShared)!
        self.waterGridBuffer = self.device.makeBuffer(bytes: self.system.waterGrid, length: self.system.waterGrid.count * MemoryLayout<Cell>.stride, options: .storageModeShared)!
        
        // Init parent
        super.init()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    func draw(in view: MTKView) {
        self.system.update() // Don't see a separate update() function I could most this to...
        
        guard let drawable = view.currentDrawable else { return }
        
        // Create command buffer
        let commandBuffer = self.commandQueue.makeCommandBuffer()
        
        // =================== COMPUTE PIPELINE ===================
        
        // Create command encoder for computations
        let computeEncoder = commandBuffer?.makeComputeCommandEncoder()
        
        // Apply Convection
        computeEncoder?.setComputePipelineState(self.computeConvectionPipeline)
        computeEncoder?.setBuffer(self.waterGridBuffer, offset: 0, index: 2)
        var threadsPerGrid = MTLSize(width: WATERGRID_X, height: WATERGRID_Y, depth: WATERGRID_Z)
        var threadsPerThreadGroup = MTLSize(width: 10, height: 10, depth: 10)
        computeEncoder?.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadGroup)
        
        // Apply External Forces
        computeEncoder?.setComputePipelineState(self.computeExternalForcesPipeline)
        computeEncoder?.setBuffer(self.waterGridBuffer, offset: 0, index: 2)
        computeEncoder?.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadGroup)
        
        // Apply Viscosity
        computeEncoder?.setComputePipelineState(self.computeViscosityPipeline)
        computeEncoder?.setBuffer(self.waterGridBuffer, offset: 0, index: 2)
        computeEncoder?.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadGroup)
        
        // Apply Vorticity Confinement
        computeEncoder?.setComputePipelineState(self.computeVorticityConfinementPipeline)
        computeEncoder?.setBuffer(self.waterGridBuffer, offset: 0, index: 2)
        computeEncoder?.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadGroup)
        
        // Update Particles
        computeEncoder?.setComputePipelineState(self.computeParticlePipeline)
        computeEncoder?.setBuffer(self.particleBuffer, offset: 0, index: 0)
        computeEncoder?.setBuffer(self.waterGridBuffer, offset: 0, index: 2)
        threadsPerGrid = MTLSize(width: self.system.particles.count, height: 1, depth: 1)
        let maxThreadsPerThreadGroup = self.computeParticlePipeline.maxTotalThreadsPerThreadgroup
        threadsPerThreadGroup = MTLSize(width: maxThreadsPerThreadGroup, height: 1, depth: 1)
        computeEncoder?.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadGroup)
        
        // Finished encoding
        computeEncoder?.endEncoding()
        
        // ===================== RENDER PIPELINE =====================
        
        // Set up renderPassDescriptor stuff for rendering
        let renderPassDescriptor = view.currentRenderPassDescriptor
        renderPassDescriptor?.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, 1)
        renderPassDescriptor?.colorAttachments[0].loadAction = .clear
        renderPassDescriptor?.colorAttachments[0].storeAction = .store
        
        // Create command encoder for rendering
        let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor!)
        renderEncoder?.setRenderPipelineState(self.renderPipeline)
        
        // Set up Camera stuff
        let viewMat: matrix_float4x4 = Matrix4x4.LookAt(eye: self.system.camera.position,
                                                        target: self.system.camera.position + self.system.camera.look,
                                                        up: self.system.camera.up)
        let projMat: matrix_float4x4 = Matrix4x4.Perspective(fovy: 45, aspect: 800/600, near: 0.1, far: 50)
        var viewProjMat = projMat * viewMat
        renderEncoder?.setVertexBytes(&viewProjMat, length: MemoryLayout<matrix_float4x4>.stride, index: 1)
        
        // Add particles to particle buffer
        renderEncoder?.setVertexBuffer(self.particleBuffer, offset: 0, index: 0)
        renderEncoder?.drawPrimitives(type: .point, vertexStart: 0, vertexCount: self.system.particles.count)
        
        // Finished encoding
        renderEncoder?.endEncoding()
        commandBuffer?.present(drawable)
        
        // ===========================================================
        
        // Done with encoding everything; commit command buffer
        commandBuffer?.commit()
    }
    
}
