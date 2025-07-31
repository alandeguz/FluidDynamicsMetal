//
//  RenderShader.swift
//  FluidDynamicsMetal
//
//  Created by Andrei-Sergiu Pițiș on 15/08/2017.
//  Copyright © 2017 Andrei-Sergiu Pițiș. All rights reserved.
//

import Foundation
import CoreMedia
import Metal

struct PipelineStateConfiguration {
    let pixelFormat: MTLPixelFormat
    let vertexShader: String
    let fragmentShader: String
    let computeShader: String
}

class RenderShader {
    private var pipelineState: PipelineStateConfiguration
    private var renderPipelineState: MTLRenderPipelineState?
    
    init(fragmentShader: String, vertexShader: String, pixelFormat: MTLPixelFormat = .bgra8Unorm) {
        pipelineState = PipelineStateConfiguration(pixelFormat: pixelFormat, vertexShader: vertexShader, fragmentShader: fragmentShader, computeShader: "")
        
        try? commonInit()
    }
    
    deinit {
        print("Deinit Filter")
    }
    
    final func calculateWithCommandBuffer(buffer: MTLCommandBuffer, texture: MTLTexture, configureEncoder: ((_ commandEncoder: MTLRenderCommandEncoder) -> Void)?) {
        guard let renderPipelineState = renderPipelineState else { return }
        let renderPassDescriptor = configureRenderPassDescriptor(texture: texture)
        guard let renderCommandEncoder = buffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        renderCommandEncoder.pushDebugGroup("Render Encoder \(pipelineState.fragmentShader)")
        configureEncoder?(renderCommandEncoder)
        renderCommandEncoder.setRenderPipelineState(renderPipelineState)
        renderCommandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderCommandEncoder.endEncoding()
        renderCommandEncoder.popDebugGroup()
    }
    
    final func calculateWithCommandBuffer(buffer: MTLCommandBuffer, indices: MTLBuffer, count: Int, texture: MTLTexture, configureEncoder: ((_ commandEncoder: MTLRenderCommandEncoder) -> Void)) {
        guard let renderPipelineState = renderPipelineState else { return }
        let renderPassDescriptor = configureRenderPassDescriptor(texture: texture)
        guard let renderCommandEncoder = buffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        renderCommandEncoder.pushDebugGroup("Render Encoder \(pipelineState.fragmentShader)")
        configureEncoder(renderCommandEncoder)
        renderCommandEncoder.setCullMode(.back)
        renderCommandEncoder.setRenderPipelineState(renderPipelineState)
        renderCommandEncoder.drawIndexedPrimitives(type: .triangle, indexCount: count, indexType: .uint16, indexBuffer: indices, indexBufferOffset: 0)
        renderCommandEncoder.endEncoding()
        renderCommandEncoder.popDebugGroup()
    }
    
    private func configureRenderPassDescriptor(texture: MTLTexture?) -> MTLRenderPassDescriptor {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        return renderPassDescriptor
    }
    
    private func configurePipeline() throws {
        guard
            pipelineState.vertexShader.count > 0 && pipelineState.fragmentShader.count > 0,
            renderPipelineState == nil
        else { return }

        do {
            renderPipelineState = try MetalDevice.createRenderPipeline(vertexFunctionName: pipelineState.vertexShader, fragmentFunctionName: pipelineState.fragmentShader, pixelFormat: pipelineState.pixelFormat)
        } catch {
            print("Could not create render pipeline state.")
        }

    }
    
    private func commonInit() throws {
        try configurePipeline()
    }
}
