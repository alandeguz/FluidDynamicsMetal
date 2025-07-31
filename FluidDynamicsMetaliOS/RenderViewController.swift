//
//  RenderViewController.swift
//  FluidDynamicsMetal
//
//  Created by Andrei-Sergiu Pițiș on 19/08/2017.
//  Copyright © 2017 Andrei-Sergiu Pițiș. All rights reserved.
//

import UIKit
import MetalKit

let MaxBuffers = 3

class RenderViewController: UIViewController {

    var renderer: Renderer!
    var metalView: MTKView {
        return view as! MTKView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
//        view.addSubview({
//           let view = UIView(frame: .init(origin: .init(x: 20, y: 20), size: .init(width: 200, height: 200)))
//            view.backgroundColor = UIColor.clear
//            view.addSubview({
//                let label = UILabel(frame: .init(origin: .init(x: 0, y: 0), size: .init(width: 100, height: 30)))
//                label.textColor = .white
//                label.text = "test"
//                return label
//            }())
//            return view
//        }())

        renderer = try? Renderer(metalView: metalView)
        metalView.delegate = renderer

        metalView.isExclusiveTouch = true
        metalView.isOpaque = false

        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(doubleTap))
        doubleTapGesture.numberOfTapsRequired = 2
        doubleTapGesture.numberOfTouchesRequired = 1
        view.addGestureRecognizer(doubleTapGesture)

        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(changeSource))
        gestureRecognizer.numberOfTapsRequired = 2
        gestureRecognizer.numberOfTouchesRequired = 2
        view.addGestureRecognizer(gestureRecognizer)

        NotificationCenter.default.addObserver(self, selector: #selector(willResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()

        print("Got Memory Warning")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let metalView = view as? MTKView else { return }
        
        let scale = metalView.contentScaleFactor
        
        let positions: [SIMD2<Float>] = touches.map { touch in
            let location = touch.location(in: metalView)
            let x = Float(location.x * scale)
            // No Y flip on iOS
            let y = Float(location.y * scale)
            return SIMD2<Float>(x, y)
        }
        
        let tupleSize = MemoryLayout<FloatTuple>.size
        let arraySize = MemoryLayout<SIMD2<Float>>.size * positions.count
        let tuple = malloc(tupleSize).assumingMemoryBound(to: FloatTuple.self)
        
        memset(tuple, 0, tupleSize)
        memcpy(tuple, positions, arraySize)
        
        renderer.updateInteraction(points: tuple.pointee, in: metalView)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let metalView = view as? MTKView else { return }
        
        let scale = metalView.contentScaleFactor
        
        let positions: [SIMD2<Float>] = touches.map { touch in
            let location = touch.location(in: metalView)
            let x = Float(location.x * scale)
            let y = Float(location.y * scale)
            return SIMD2<Float>(x, y)
        }
        
        let tupleSize = MemoryLayout<FloatTuple>.size
        let arraySize = MemoryLayout<SIMD2<Float>>.size * positions.count
        let tuple = malloc(tupleSize).assumingMemoryBound(to: FloatTuple.self)
        
        memset(tuple, 0, tupleSize)
        memcpy(tuple, positions, arraySize)
        
        renderer.updateInteraction(points: tuple.pointee, in: metalView)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let metalView = view as? MTKView else { return }
        renderer.updateInteraction(points: nil, in: metalView)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let metalView = view as? MTKView else { return }
        renderer.updateInteraction(points: nil, in: metalView)
    }

    @objc func changeSource() {
        renderer.nextSlab()
    }

    @objc final func doubleTap() {
        metalView.isPaused = !metalView.isPaused
    }

    @objc final func willResignActive() {
        metalView.isPaused = true
    }

    @objc final func didBecomeActive() {
        metalView.isPaused = false
    }
}
