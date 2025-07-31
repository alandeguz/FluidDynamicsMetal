//
//  RenderViewController.swift
//  FluidDynamicsMetalOSX
//
//  Created by Andrei-Sergiu Pițiș on 16/12/2017.
//  Copyright © 2017 Andrei-Sergiu Pițiș. All rights reserved.
//

import AppKit
import MetalKit

import Cocoa
import MetalKit

class RenderViewController: NSViewController {
    var renderer: Renderer!
    
    // Strongly type the view as RenderMTKView
    var metalView: RenderMTKView {
        print(view)
        return view as! RenderMTKView
    }
    
    var eventMonitor: Any?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up Renderer
        renderer = try? Renderer(metalView: metalView)
        metalView.delegate = renderer
        metalView.renderer = renderer
        
        // Metal view settings
        metalView.enableSetNeedsDisplay = false
        metalView.isPaused = false
        metalView.framebufferOnly = true
        metalView.colorPixelFormat = .bgra8Unorm
        
        // Keyboard event monitor
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            self.keyDown(with: $0)
            return $0
        }
    }
    
    deinit {
        NSEvent.removeMonitor(eventMonitor as Any)
    }
    
    // Keyboard input
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 0x31: // Spacebar
            changePauseState()
        case 0x01: // 'S'
            changeSource()
        default:
            break
        }
    }
    
    private func changeSource() {
        renderer.nextSlab()
    }
    
    private func changePauseState() {
        metalView.isPaused.toggle()
    }
}
