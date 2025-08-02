//
//  Renderer.swift
//  FluidDynamicsMetal
//
//  Created by Andrei-Sergiu Pițiș on 20/12/2017.
//  Copyright © 2017 Andrei-Sergiu Pițiș. All rights reserved.
//

import MetalKit

public typealias FloatTuple = (SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>)
fileprivate let pressureIterations = 40

// Operators
public func / (rhs: FloatTuple, lhs: Float) -> FloatTuple {
    (rhs.0 / lhs, rhs.1 / lhs, rhs.2 / lhs, rhs.3 / lhs, rhs.4 / lhs)
}
public func - (rhs: FloatTuple, lhs: FloatTuple) -> FloatTuple {
    (rhs.0 - lhs.0, rhs.1 - lhs.1, rhs.2 - lhs.2, rhs.3 - lhs.3, rhs.4 - lhs.4)
}

// Uniforms
public struct StaticData {
    var positions: FloatTuple
    var impulses: FloatTuple
    var impulseScalar: SIMD2<Float>
    var offsets: SIMD2<Float>
    var screenSize: SIMD2<Float>
    var inkRadius: simd_float1
}

public struct VertexData {
    let position: SIMD2<Float>
    let texCoord: SIMD2<Float>
}

public class Renderer: NSObject {
    static let MaxBuffers = 3
    static let ScreenScaleAdjustment: Float = 1.0
    
    // Quad data
    static let vertexData: [VertexData] = [
        VertexData(position: [-1, -1], texCoord: [0, 1]),
        VertexData(position: [ 1, -1], texCoord: [1, 1]),
        VertexData(position: [-1,  1], texCoord: [0, 0]),
        VertexData(position: [ 1,  1], texCoord: [1, 0])
    ]
    static let indices: [UInt16] = [2, 1, 0, 1, 2, 3]
    
    private let vertData = MetalDevice.sharedInstance.buffer(array: Renderer.vertexData, storageMode: [.storageModeShared])
    private let indexData = MetalDevice.sharedInstance.buffer(array: Renderer.indices, storageMode: [.storageModeShared])
    
    // Shaders
    private var applyForceVectorShader: RenderShader!
    private var applyForceScalarShader: RenderShader!
    private var advectShader: RenderShader!
    private var divergenceShader: RenderShader!
    private var jacobiShader: RenderShader!
    private var vorticityShader: RenderShader!
    private var vorticityConfinementShader: RenderShader!
    private var gradientShader: RenderShader!
    private var renderVector: RenderShader!
    private var renderScalar: RenderShader!
    
    // State
    private var positions: FloatTuple?
    private var directions: FloatTuple?
    
    private var velocity: Slab!
    private var density: Slab!
    private var velocityDivergence: Slab!
    private var velocityVorticity: Slab!
    private var pressure: Slab!
    
    private var uniformsBuffers: [MTLBuffer] = []
    private var avaliableBufferIndex: Int = 0
    
    private let semaphore = DispatchSemaphore(value: MaxBuffers)
    private var initializedSize: CGSize = .zero
    private var currentIndex = 0
    
    // MARK: - Init
    public init(metalView: MTKView) throws {
        super.init()
        setupShaders()
        configure(metalView: metalView)
    }
    
    func update(metalView: MTKView) throws {
        configure(metalView: metalView)
    }
    
    public func nextSlab() {
        currentIndex = (currentIndex + 1) % 4
    }
    
    public func updateInteraction(points: FloatTuple?, in view: MTKView) {
        positions = points
    }
    
    private func configure(metalView: MTKView) {
        metalView.device = MetalDevice.sharedInstance.device
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.framebufferOnly = true
        metalView.preferredFramesPerSecond = 60
        mtkView(metalView, drawableSizeWillChange: metalView.drawableSize)
    }
    
    private func setupShaders() {
        applyForceVectorShader = RenderShader(fragmentShader: "applyForceVector", vertexShader: "vertexShader", pixelFormat: .rg16Float)
        applyForceScalarShader = RenderShader(fragmentShader: "applyForceScalar", vertexShader: "vertexShader", pixelFormat: .rg16Float)
        advectShader = RenderShader(fragmentShader: "advect", vertexShader: "vertexShader", pixelFormat: .rg16Float)
        divergenceShader = RenderShader(fragmentShader: "divergence", vertexShader: "vertexShader", pixelFormat: .rg16Float)
        jacobiShader = RenderShader(fragmentShader: "jacobi", vertexShader: "vertexShader", pixelFormat: .rg16Float)
        vorticityShader = RenderShader(fragmentShader: "vorticity", vertexShader: "vertexShader", pixelFormat: .rg16Float)
        vorticityConfinementShader = RenderShader(fragmentShader: "vorticityConfinement", vertexShader: "vertexShader", pixelFormat: .rg16Float)
        gradientShader = RenderShader(fragmentShader: "gradient", vertexShader: "vertexShader", pixelFormat: .rg16Float)
        
        renderVector = RenderShader(fragmentShader: "visualizeVector", vertexShader: "vertexShader")
        renderScalar = RenderShader(fragmentShader: "visualizeScalar", vertexShader: "vertexShader")
    }
    
    private func initSurfaces(width: Int, height: Int) {
        velocity = Slab(width: width, height: height, format: .rg16Float, name: "Velocity")
        density = Slab(width: width, height: height, format: .rg16Float, name: "Density")
        velocityDivergence = Slab(width: width, height: height, format: .rg16Float, name: "Divergence")
        velocityVorticity = Slab(width: width, height: height, format: .rg16Float, name: "Vorticity")
        pressure = Slab(width: width, height: height, format: .rg16Float, name: "Pressure")
    }
    
    private func initBuffers(width: Int, height: Int) {
        let bufferSize = MemoryLayout<StaticData>.stride
        var staticData = StaticData(
            positions: (.zero, .zero, .zero, .zero, .zero),
            impulses: (.zero, .zero, .zero, .zero, .zero),
            impulseScalar: .zero,
            offsets: SIMD2<Float>(1.0/Float(width), 1.0/Float(height)),
            screenSize: SIMD2<Float>(Float(width), Float(height)),
            inkRadius: 150 / Renderer.ScreenScaleAdjustment
        )
        
        uniformsBuffers = (0..<Renderer.MaxBuffers).map {
            let buffer = MetalDevice.sharedInstance.device.makeBuffer(bytes: &staticData, length: bufferSize, options: .storageModeShared)!
            buffer.label = "UniformsBuffer_\($0)"
            return buffer
        }
    }
    
    private func nextBuffer(positions: FloatTuple?, directions: FloatTuple?) -> MTLBuffer {
        let buffer = uniformsBuffers[avaliableBufferIndex]
        if let positions = positions, let directions = directions {
            let bufferData = buffer.contents().bindMemory(to: StaticData.self, capacity: 1)
            bufferData.pointee.positions = positions / Renderer.ScreenScaleAdjustment
            bufferData.pointee.impulses = (positions - directions) / Renderer.ScreenScaleAdjustment
            bufferData.pointee.impulseScalar = SIMD2<Float>(0.8, 0.0)
        }
        avaliableBufferIndex = (avaliableBufferIndex + 1) % Renderer.MaxBuffers
        return buffer
    }
    
    private func drawSlab() -> Slab {
        switch currentIndex {
        case 1: return pressure
        case 2: return velocity
        case 3: return velocityVorticity
        default: return density
        }
    }
    
}

// MARK: - MTKViewDelegate
extension Renderer: MTKViewDelegate {
    
    public func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable else { return }
        
        let size = view.drawableSize
        let width = Int(size.width / CGFloat(Renderer.ScreenScaleAdjustment))
        let height = Int(size.height / CGFloat(Renderer.ScreenScaleAdjustment))
        
        if width > 0, height > 0,
           (density == nil || Int(initializedSize.width) != Int(size.width) || Int(initializedSize.height) != Int(size.height)) {
            initSurfaces(width: width, height: height)
            initBuffers(width: width, height: height)
            initializedSize = size
        }
        guard density != nil else { return }
        
        _ = semaphore.wait(timeout: .distantFuture)
        let commandBuffer = MetalDevice.sharedInstance.newCommandBuffer()
        commandBuffer.addCompletedHandler { _ in self.semaphore.signal() }
        
        let hasInteraction = (positions != nil && directions != nil)
        let dataBuffer = nextBuffer(positions: positions, directions: directions)
        
        // --- Advect ---
        let advectTargets: [(Slab, Slab)] = [(velocity, velocity), (density, density)]
        for (src, dst) in advectTargets {
            executeShader(advectShader, commandBuffer, dataBuffer, destination: dst) { enc in
                enc.setFragmentTexture(self.velocity.ping, index: 0)
                enc.setFragmentTexture(src.ping, index: 1)
            }
        }
        
        // Apply forces only when interacting
        if hasInteraction {
            executeShader(applyForceVectorShader, commandBuffer, dataBuffer, destination: velocity) {
                $0.setFragmentTexture(self.velocity.ping, index: 0)
            }
            executeShader(applyForceScalarShader, commandBuffer, dataBuffer, destination: density) {
                $0.setFragmentTexture(self.density.ping, index: 0)
            }
        }
        
        // Vorticity
        executeShader(vorticityShader, commandBuffer, dataBuffer, destination: velocityVorticity) {
            $0.setFragmentTexture(self.velocity.ping, index: 0)
        }
        executeShader(vorticityConfinementShader, commandBuffer, dataBuffer, destination: velocity) {
            $0.setFragmentTexture(self.velocity.ping, index: 0)
            $0.setFragmentTexture(self.velocityVorticity.ping, index: 1)
        }
        
        // Divergence
        executeShader(divergenceShader, commandBuffer, dataBuffer, destination: velocityDivergence) {
            $0.setFragmentTexture(self.velocity.ping, index: 0)
        }
        
        // Pressure solve
        let iterations = hasInteraction ? pressureIterations : 10
        for _ in 0..<iterations {
            executeShader(jacobiShader, commandBuffer, dataBuffer, destination: pressure) {
                $0.setFragmentTexture(self.pressure.ping, index: 0)
                $0.setFragmentTexture(self.velocityDivergence.ping, index: 1)
            }
        }
        
        // Subtract gradient
        executeShader(gradientShader, commandBuffer, dataBuffer, destination: velocity) {
            $0.setFragmentTexture(self.pressure.ping, index: 0)
            $0.setFragmentTexture(self.velocity.ping, index: 1)
        }
        
        // Render to screen
        let shader = (currentIndex >= 2 ? renderVector : renderScalar)!
        executeShader(shader, commandBuffer, dataBuffer, destinationTexture: drawable.texture) {
            $0.setFragmentTexture(self.drawSlab().ping, index: 0)
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        directions = positions
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        initializedSize = size
    }
}

// MARK: - Unified draw helper
extension Renderer {
    private func executeShader(_ shader: RenderShader, _ commandBuffer: MTLCommandBuffer, _ dataBuffer: MTLBuffer, destination: Slab, configure: (MTLRenderCommandEncoder) -> Void) {
        shader.calculateWithCommandBuffer(buffer: commandBuffer, indices: indexData, count: Renderer.indices.count, texture: destination.pong) { encoder in
            encoder.setVertexBuffer(self.vertData, offset: 0, index: 0)
            configure(encoder)
            encoder.setFragmentBuffer(dataBuffer, offset: 0, index: 0)
        }
        destination.swap()
    }
    
    private func executeShader(_ shader: RenderShader, _ commandBuffer: MTLCommandBuffer, _ dataBuffer: MTLBuffer, destinationTexture: MTLTexture, configure: (MTLRenderCommandEncoder) -> Void) {
        shader.calculateWithCommandBuffer(buffer: commandBuffer, indices: indexData, count: Renderer.indices.count, texture: destinationTexture) { encoder in
            encoder.setVertexBuffer(self.vertData, offset: 0, index: 0)
            configure(encoder)
        }
    }
}
