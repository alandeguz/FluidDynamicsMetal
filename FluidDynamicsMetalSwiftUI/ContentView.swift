//
//  ContentView.swift
//  FluidDynamicsMetalSwiftUI
//
//  Created by Alan DeGuzman on 3/10/25.
//  Copyright © 2025 Kidlat Tech. All rights reserved.
//

import SwiftUI
import MetalKit

struct ContentView: View {
    var body: some View {
        MetalView()
            .ignoresSafeArea() 
    }
}

#Preview {
    ContentView()
}
