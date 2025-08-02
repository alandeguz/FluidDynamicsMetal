//
//  MetalView.swift
//  FluidDynamicsMetal
//
//  Created by DeGuzman, Alan on 7/30/25.
//

import FluidDynamicsMetal
import MetalKit
import SwiftUI

#if os(iOS)
typealias PlatformViewRepresentable = UIViewRepresentable
typealias UserMTKView = TouchMTKView
#else
typealias PlatformViewRepresentable = NSViewRepresentable
typealias UserMTKView = ClickMTKView
#endif

// MARK: - Cross-platform MetalView

struct MetalView: PlatformViewRepresentable {
    class Coordinator {
        var renderer: Renderer?
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    // MARK: - Platform-specific makeView
#if os(iOS)
    func makeUIView(context: Context) -> MTKView { return genericView(context: context) }
    func updateUIView(_ uiView: MTKView, context: Context) { }
#else
    func makeNSView(context: Context) -> MTKView { return genericView(context: context) }
    func updateNSView(_ nsView: MTKView, context: Context) { }
#endif
    
    private func genericView(context: Context) -> MTKView {
        let metalView = UserMTKView()
        setup(metalView, context: context)
        return metalView
    }
    
    private func setup(_ metalView: MTKView, context: Context) {
        let renderer = try? Renderer(metalView: metalView)
        metalView.delegate = renderer
        context.coordinator.renderer = renderer
        
        // Assign renderer to custom subclass
#if os(iOS)
        if let touchView = metalView as? TouchMTKView {
            touchView.renderer = renderer
        }
#else
        if let clickView = metalView as? ClickMTKView {
            clickView.renderer = renderer
        }
#endif
    }
    
}

// MARK: - iOS TouchMTKView

#if os(iOS)
class TouchMTKView: MTKView {
    weak var renderer: Renderer?
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        sendTouches(touches)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        sendTouches(touches)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        renderer?.updateInteraction(points: nil, in: self)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        renderer?.updateInteraction(points: nil, in: self)
    }
    
    private func sendTouches(_ touches: Set<UITouch>) {
        guard let renderer = renderer else { return }
        
        let scale = contentScaleFactor
        
        let positions: [SIMD2<Float>] = touches.map { touch in
            let loc = touch.location(in: self)
            let x = Float(loc.x * scale)
            let y = Float(loc.y * scale)  // No Y flip on iOS
            return SIMD2<Float>(x, y)
        }
        
        let tupleSize = MemoryLayout<FloatTuple>.size
        let arraySize = MemoryLayout<SIMD2<Float>>.size * positions.count
        let tuple = malloc(tupleSize).assumingMemoryBound(to: FloatTuple.self)
        memset(tuple, 0, tupleSize)
        memcpy(tuple, positions, arraySize)
        
        renderer.updateInteraction(points: tuple.pointee, in: self)
    }
}
#endif

// MARK: - macOS ClickMTKView

#if os(macOS)
class ClickMTKView: MTKView {
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
        let loc = convert(event.locationInWindow, from: nil)
        let h = bounds.height
        let x = Float(loc.x * scale)
        let y = Float((h - loc.y) * scale)  // Flip Y on macOS
        let pos = SIMD2<Float>(x, y)
        
        let points: FloatTuple = (pos, pos, pos, pos, pos)
        renderer.updateInteraction(points: points, in: self)
    }
}
#endif

#Preview {
    MetalView()
        .ignoresSafeArea()
}
