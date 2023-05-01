//
//  Renderer.swift
//  Ink_Simulation
//
//  Created by Helen Huang on 4/30/23.
//

import MetalKit

class Renderer: NSObject, MTKViewDelegate {
    
    var parent: ContentView
    let system: System
    
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    let renderPipeline: MTLRenderPipelineState
    
    init(_ parent: ContentView) {
        // Get the GPU device and init a command queue
        self.parent = parent
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            self.device = metalDevice
        }
        self.commandQueue = self.device.makeCommandQueue()
        
        // Set up the Render pipeline and MTLLibrary
        let pipeDescriptor = MTLRenderPipelineDescriptor()
        let library = self.device.makeDefaultLibrary()
        pipeDescriptor.vertexFunction = library?.makeFunction(name: "vertexShader")
        pipeDescriptor.fragmentFunction = library?.makeFunction(name: "fragmentShader")
        pipeDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        do {
            try self.renderPipeline = self.device.makeRenderPipelineState(descriptor: pipeDescriptor)
        } catch {
            fatalError()
        }
        
        // Init system
        self.system = System()
        
        // Init parent
        super.init()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    func draw(in view: MTKView) {
        self.system.update()
        
        guard let drawable = view.currentDrawable else { return }
        
        // Create command buffer
        let commandBuffer = self.commandQueue.makeCommandBuffer()
        
        let renderPassDescriptor = view.currentRenderPassDescriptor
        renderPassDescriptor?.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, 1)
        renderPassDescriptor?.colorAttachments[0].loadAction = .clear
        renderPassDescriptor?.colorAttachments[0].storeAction = .store
        
        // Create command encoder for command buffer
        let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor!)
        renderEncoder?.setRenderPipelineState(self.renderPipeline)
        
        // Set up Camera stuff
        let viewMat: matrix_float4x4 = Matrix4x4.LookAt(eye: self.system.camera.position,
                                                        target: self.system.camera.position + self.system.camera.look,
                                                        up: self.system.camera.up)
        let projMat: matrix_float4x4 = Matrix4x4.Perspective(fovy: 45, aspect: 800/600, near: 0.1, far: 20)
        var viewProjMat = projMat * viewMat
        renderEncoder?.setVertexBytes(&viewProjMat, length: MemoryLayout<matrix_float4x4>.stride, index: 1)
        
        // Add particles to vertex buffer
        let vertexBuffer = self.device.makeBuffer(bytes: self.system.particles, length: self.system.particles.count * MemoryLayout<Particle>.stride, options: [])!
        renderEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder?.drawPrimitives(type: .point, vertexStart: 0, vertexCount: self.system.particles.count)
        
        // Finish encoding for command buffer
        renderEncoder?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
    
}
