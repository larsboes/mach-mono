//
//  ContentRevealModifier.swift
//  boringNotch
//
//  Choreographed content reveal tied to continuous animation progress.
//  Content grows out of the notch center with staggered timing.
//

import SwiftUI

// MARK: - Content Reveal Modifier

struct ContentRevealModifier: ViewModifier {
    /// Continuous progress from 0 (closed) to 1 (fully open)
    let progress: CGFloat
    /// Stagger index — higher indices appear later
    let staggerIndex: Int
    /// Whether to apply blur (disable for camera to avoid render errors)
    let useBlur: Bool

    @Environment(\.isNotchClosing) private var isClosing

    /// Per-element stagger offset (each index delays the start by this amount of progress)
    private let staggerStep: CGFloat = 0.06

    /// This element's effective progress, accounting for stagger.
    /// On close (progress going 1→0), higher-index elements reach 0 first — natural reverse stagger.
    private var elementProgress: CGFloat {
        // Subtle stagger during both open and close for a choreographed feel.
        // Higher-index elements reach 0 first on close — natural reverse stagger.
        let offset = CGFloat(staggerIndex) * staggerStep
        let adjusted = (progress - offset) / (1.0 - offset)
        return max(0, min(1, adjusted))
    }

    /// Smooth Hermite interpolation
    private func smoothstep(_ t: CGFloat) -> CGFloat {
        let c = max(0, min(1, t))
        return c * c * (3 - 2 * c)
    }

    func body(content: Content) -> some View {
        let smooth = smoothstep(elementProgress)

        // Asymmetric open vs close:
        // Open: gentle grow from 0.94, slide down from notch, blur clears
        // Close: aggressive fade out, compress to 0.70, yank up into notch — "absorbed" feel
        let opacity = isClosing ? pow(smooth, 2.0) : smooth
        let scale = isClosing
            ? 0.70 + 0.30 * smooth     // Close: 1.0 → 0.70 (30% compress, much more aggressive)
            : 0.94 + 0.06 * smooth     // Open: 0.94 → 1.0 (gentle grow)
        let yOffset = isClosing
            ? (1.0 - smooth) * -20.0   // Close: pull significantly up into notch for absorption
            : (1.0 - smooth) * -4.0    // Open: slide down from notch

        let blurRadius = useBlur ? (1.0 - elementProgress) * (isClosing ? 1.0 : 6.0) : 0

        content
            .opacity(opacity)
            .scaleEffect(scale, anchor: isClosing ? .top : .center)
            .offset(y: yOffset)
            .blur(radius: blurRadius)
    }
}

// MARK: - View Extension

extension View {
    /// Choreographed content reveal tied to animation progress.
    /// - Parameters:
    ///   - progress: Continuous 0→1 from contentProgress environment value
    ///   - staggerIndex: Element order (0 = first to appear)
    ///   - useBlur: Set false for camera views to avoid render errors
    func contentReveal(progress: CGFloat, staggerIndex: Int, useBlur: Bool = true) -> some View {
        modifier(ContentRevealModifier(progress: progress, staggerIndex: staggerIndex, useBlur: useBlur))
    }
}
