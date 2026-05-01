//
//  drop.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on  04/08/24.
//

import Foundation
import SwiftUI

// MARK: - Standardized Animations
/// Centralized animation definitions for consistent UI behavior across the app.
enum StandardAnimations {
    /// Interactive spring for responsive UI (used for notch interactions)
    /// Tight response with near-critical damping — confident tracking, no wobble
    static let interactive = Animation.interactiveSpring(
        response: 0.20,        // Snappy response for immediate feel
        dampingFraction: 0.94, // Near-critical damping — clean stop, zero overshoot
        blendDuration: 0
    )

    /// Spring animation for opening the notch
    /// Apple Dynamic Island feel — swift expansion with minimal overshoot
    static let open = Animation.spring(
        response: 0.32,
        dampingFraction: 0.92,
        blendDuration: 0.04
    )

    /// Velocity-aware open spring — fast flings overshoot more, slow opens settle gently.
    /// - Parameter velocity: Gesture velocity in pts/s. 0 = identical to `open`.
    static func openWithVelocity(_ velocity: CGFloat) -> Animation {
        let clamped = min(abs(velocity), 2000)
        let t = clamped / 2000  // 0→1 normalized
        let response = 0.32 - t * 0.18  // 0.32→0.14 (much snappier)
        let damping = 0.92 - t * 0.37   // 0.92→0.55 (visibly bouncier)
        return Animation.spring(response: response, dampingFraction: damping, blendDuration: 0.04)
    }
    /// Estimated settle duration for the open animation
    static let openDuration: Duration = .milliseconds(300)

    /// Spring animation for closing the notch (content dismiss, closeHello, etc.)
    /// Quick and decisive — near-critically damped for confident retraction
    static let close = Animation.spring(
        response: 0.22,        // Snappier transition
        dampingFraction: 0.95, // Slightly more damped for a solid "thud" into the edge
        blendDuration: 0.02
    )
    /// Shell close — must match content exit exactly for unified feel.
    static let closeShell = close
    /// Estimated settle duration for the close animation
    static let closeDuration: Duration = .milliseconds(230)

    /// Bouncy spring for playful animations
    @available(macOS 14.0, *)
    static var bouncy: Animation {
        Animation.spring(.bouncy(duration: 0.4))
    }

    /// Smooth animation for general transitions
    static let smooth = Animation.smooth

    /// Timing curve fallback for older macOS versions
    static let timingCurve = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.7)

    /// Organic timing curve for the hello animation
    static let hello = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 3.0)

    // MARK: - Content Transitions (decoupled from shell spring)

    /// Content reveal on open — shell leads, content follows with gentle delay
    static let contentReveal = Animation.easeOut(duration: 0.28).delay(0.08)

    /// Content exit on close — fast and decisive, content yanked back into notch.
    static let contentDismiss = close

    /// Staggered animation for sequential content reveals
    /// - Parameter index: The index of the element in the sequence (0 = first)
    /// - Returns: Animation with appropriate delay for perceptible stagger
    static func staggered(index: Int) -> Animation {
        Animation.spring(response: 0.30, dampingFraction: 0.88)
            .delay(Double(index) * 0.05)
    }
}

enum BoringAnimations {
    static var animation: Animation {
        if #available(macOS 14.0, *) {
            StandardAnimations.bouncy
        } else {
            StandardAnimations.timingCurve
        }
    }
}
