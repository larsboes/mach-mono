//
//  LottieView.swift
//  machNotch
//
//  Created by Alexander on 2025-11-14.
//

import Lottie
import ObjectiveC
import SwiftUI

public struct LottieView: NSViewRepresentable {
    public let url: URL
    public let speed: Double
    public let loopMode: LottieLoopMode

    private static var associatedURLKey: UInt8 = 0

    public init(url: URL, speed: Double, loopMode: LottieLoopMode) {
        self.url = url
        self.speed = speed
        self.loopMode = loopMode
    }

    public func makeNSView(context: Context) -> NSView {
        let animationView = LottieAnimationView()
        animationView.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: container.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        guard let animationView = nsView.subviews.first as? LottieAnimationView else { return }
        let lastURL = objc_getAssociatedObject(animationView, &Self.associatedURLKey) as? URL
        if lastURL != url {
            LottieAnimation.loadedFrom(url: url) { animation in
                animationView.animation = animation
                animationView.loopMode = loopMode
                animationView.animationSpeed = CGFloat(speed)
                animationView.play()
                objc_setAssociatedObject(animationView, &Self.associatedURLKey, url, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        } else {
            animationView.loopMode = loopMode
            animationView.animationSpeed = CGFloat(speed)
            if !animationView.isAnimationPlaying {
                animationView.play()
            }
        }
    }
}
