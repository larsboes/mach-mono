//
//  LottieAnimationContainer.swift
//  boringNotch
//
//  Created by Richard Kunkli on 2024. 10. 29..
//

import SwiftUI

struct LottieAnimationContainer: View {
    @Environment(\.settings) var settings
    var body: some View {
        if let url = settings.selectedVisualizerURL {
            LottieView(url: url, speed: settings.selectedVisualizerSpeed, loopMode: .loop)
        } else {
            LottieView(url: URL(string: "https://assets9.lottiefiles.com/packages/lf20_mniampqn.json")!, speed: 1.0, loopMode: .loop)
        }
    }
}

#Preview {
    LottieAnimationContainer()
}
