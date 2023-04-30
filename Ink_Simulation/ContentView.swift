//
//  ContentView.swift
//  Ink_Simulation
//
//  Created by Helen Huang on 4/30/23.
//
//  Based on the tutorial: https://www.youtube.com/watch?v=H2ufvcNvVmA
//

import SwiftUI
import MetalKit

struct ContentView: NSViewRepresentable {
    
    func makeCoordinator() -> Renderer {
        Renderer(self)
    }
    
    func makeNSView(context: NSViewRepresentableContext<ContentView>) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator // What's responsible for rendering the MTKView
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = true
        
        if let metalDevice = MTLCreateSystemDefaultDevice() { // Set the GPU device of the view
            mtkView.device = metalDevice
        }
        
        mtkView.framebufferOnly = false
        mtkView.drawableSize = mtkView.frame.size
        
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: NSViewRepresentableContext<ContentView>) {
        // TODO
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
