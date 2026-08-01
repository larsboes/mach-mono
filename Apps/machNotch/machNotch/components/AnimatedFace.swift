//
//  AnimatedFace.swift
//
// Created by Harsh Vardhan  Goswami  on  04/08/24.
//

import SwiftUI

struct MinimalFaceFeatures: View {
    @Environment(\.pluginManager) private var pluginManager

    var height: CGFloat = 20
    var width: CGFloat = 30

    var body: some View {
        if let pluginManager {
            pluginManager.faceView()
                .frame(width: width, height: height)
        }
    }
}

struct MinimalFaceFeatures_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
            MinimalFaceFeatures()
        }
        .previewLayout(.fixed(width: 60, height: 60))  // Adjusted preview size for better visibility
    }
}
