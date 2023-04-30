//
//  Renderer.swift
//  Ink_Simulation
//
//  Created by Helen Huang on 4/30/23.
//

import MetalKit

class Renderer: NSObject, MTKViewDelegate {
    
    var parent: ContentView
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    let renderPipeline: MTLRenderPipelineState
    let vertexBuffer: MTLBuffer
    
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
        
        // Dummy data to fill vertex MTLBuffer
        let particles = [
            Particle(position: [-0.5, -0.5], color: [1, 0, 0, 1], size: 7),
            Particle(position: [0.5, -0.5], color: [0, 1, 0, 1], size: 7),
            Particle(position: [0, 0.5], color: [0, 0, 1, 1], size: 7),
        ]
        self.vertexBuffer = self.device.makeBuffer(bytes: particles, length: particles.count * MemoryLayout<Particle>.stride, options: [])!
        
        // Init parent
        super.init()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // TODO
    }
    
    func draw(in view: MTKView) {
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
        renderEncoder?.setVertexBuffer(self.vertexBuffer, offset: 0, index: 0)
        renderEncoder?.drawPrimitives(type: .point, vertexStart: 0, vertexCount: 3)
        
        // Finished encoding
        renderEncoder?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
    
}
