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
#endif

#if os(macOS)
typealias PlatformViewRepresentable = NSViewRepresentable
#endif

// MARK: - Cross-platform MetalView

struct MetalView: PlatformViewRepresentable {
    
    class Coordinator: NSObject {
        var renderer: Renderer?
        var metalView: MTKView?
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    // MARK: - Platform-specific makeView
#if os(iOS)
    func makeUIView(context: Context) -> MTKView {
        let v = genericView(context: context)
        addGestures(to: v, context: context)
        return v
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {}
#endif

#if os(macOS)
    func makeNSView(context: Context) -> MTKView {
        let v = genericView(context: context)
        // Automatically focus to receive key events
        DispatchQueue.main.async {
            v.window?.makeFirstResponder(v)
        }
        return v
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {}
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
        context.coordinator.metalView = metalView
        (metalView as? UserMTKView)?.renderer = renderer
    }
    
#if os(iOS)
    /// Add gesture recognizers similar to RenderViewController on iOS
    private func addGestures(to metalView: MTKView, context: Context) {
        // Single-finger double tap: toggle pause
        let singleDoubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.doubleTap)
        )
        singleDoubleTap.numberOfTapsRequired = 2
        singleDoubleTap.numberOfTouchesRequired = 1
        metalView.addGestureRecognizer(singleDoubleTap)
        
        // Two-finger double tap: change source
        let twoFingerDoubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.changeSource)
        )
        twoFingerDoubleTap.numberOfTapsRequired = 2
        twoFingerDoubleTap.numberOfTouchesRequired = 2
        metalView.addGestureRecognizer(twoFingerDoubleTap)
    }
#endif
}

// MARK: - Gesture actions for iOS
#if os(iOS)
extension MetalView.Coordinator {
    @objc func doubleTap() {
        metalView?.isPaused.toggle()
    }
    
    @objc func changeSource() {
        renderer?.nextSlab()
    }
}
#endif

class UserMTKView: MTKView {

    weak var renderer: Renderer?
    
#if os(iOS)
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

#endif

#if os(macOS)

    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 0x31: // Spacebar
            isPaused.toggle()
        case 0x01: // "S"
            renderer?.nextSlab()
        default:
            super.keyDown(with: event)
        }
    }
    
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
    
#endif
}

#Preview {
    MetalView()
        .ignoresSafeArea()
}
