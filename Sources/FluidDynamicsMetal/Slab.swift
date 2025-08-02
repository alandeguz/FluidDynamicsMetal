//
//  Slab.swift
//  FluidDynamicsMetal
//
//  Created by Andrei-Sergiu Pițiș on 15/08/2017.
//  Copyright © 2017 Andrei-Sergiu Pițiș. All rights reserved.
//

import Foundation
import Metal

public class Slab {
    var ping: MTLTexture!
    var pong: MTLTexture!
    
    init(width: Int, height: Int,
         format: MTLPixelFormat = .rgba16Float,
         usage: MTLTextureUsage = .unknown,
         name: String? = nil) {
        
        // Do not attempt to create textures with zero width or height
        guard width > 0, height > 0 else {
            print("Warning: Slab initialized with zero size (\(width)x\(height))")
            return
        }
        
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.pixelFormat = format
        textureDescriptor.usage = [.shaderRead, .renderTarget]
        textureDescriptor.width = width
        textureDescriptor.height = height
        
        guard let pingTex = MetalDevice.createTexture(descriptor: textureDescriptor) as MTLTexture?,
              let pongTex = MetalDevice.createTexture(descriptor: textureDescriptor) as MTLTexture? else {
            fatalError("Failed to create Metal textures with size \(width)x\(height)")
        }
        
        ping = pingTex
        pong = pongTex
        ping.label = name
        pong.label = name
    }
    
    func swap() {
        Swift.swap(&ping, &pong)
    }
}
