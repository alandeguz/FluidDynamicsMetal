//
//  ContentView.swift
//  FluidDynamicsMetalSwiftUI
//
//  Created by Alan DeGuzman on 3/10/25.
//

import MetalKit
import SwiftUI

struct ContentView: View {
    var body: some View {
        MetalView()
            .ignoresSafeArea() 
    }
}

#Preview {
    ContentView()
}
