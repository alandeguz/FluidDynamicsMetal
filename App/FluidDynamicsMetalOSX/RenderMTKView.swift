//
//  RenderMTKView.swift
//  FluidDynamicsMetal
//
//  Created by DeGuzman, Alan on 7/30/25.
//  Copyright © 2025 Kidlat Tech. All rights reserved.
//

import FluidDynamicsMetal
import MetalKit

class RenderMTKView: MTKView {
    weak var renderer: Renderer?
    
    override func mouseDown(with event: NSEvent) {
        sendInteraction(for: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        sendInteraction(for: event)
    }
    
    override func mouseUp(with event: NSEvent) {
        renderer?.updateInteraction(points: nil, in: self)
    }
    
    private func sendInteraction(for event: NSEvent) {
        guard let renderer = renderer else { return }
        
        let scale = window?.backingScaleFactor ?? 1.0
        let location = convert(event.locationInWindow, from: nil)
        let h = bounds.height
        
        // Convert to pixel coordinates with bottom-left origin
        let x = Float(location.x * scale)
        let y = Float((h - location.y) * scale)
        let pos = SIMD2<Float>(x, y)
        
        // Create a tuple where all five points are the same
        let points: FloatTuple = (pos, pos, pos, pos, pos)
        
        renderer.updateInteraction(points: points, in: self)
    }
}
