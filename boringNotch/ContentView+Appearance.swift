//
//  ContentView+Appearance.swift
//  boringNotch
//
//  Extracted from ContentView — appearance calculations and view builders.
//

import SwiftUI

// MARK: - Appearance Calculations

extension ContentView {
    var isNotchHeightZero: Bool { vm.effectiveClosedNotchHeight == 0 }

    var displayClosedNotchHeight: CGFloat {
        let targetHeight = vm.effectiveClosedNotchHeight
        return targetHeight == 0 ? 10 : targetHeight
    }

    var animationProgress: CGFloat {
        // In the terminal closed state, progress is definitively 0.
        // This prevents a stale vm.notchSize.height (e.g. 38 physical vs 32 inactive)
        // from producing a phantom non-zero progress that inflates width/corners.
        if vm.phase == .closed {
            return 0
        }

        // During transitions and open state, prefer shellProgress but use height-based
        // fallback to catch stuck animations (e.g. shellProgress stuck at 0 while notch
        // is visually tall → ensures corners stay rounded).
        let currentHeight = vm.notchSize.height
        let openHeight = openNotchSize.height
        let closedHeight = displayClosedNotchHeight
        
        let heightProgress = max(0, min(1, (currentHeight - closedHeight) / (openHeight - closedHeight)))
        
        return max(vm.shellAnimationProgress, heightProgress)
    }

    func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    /// Smooth Hermite interpolation — maps progress from edge0→edge1 to 0→1 with ease-in/out.
    /// Use for content that should start appearing partway through the animation.
    /// Example: `smoothstep(0.3, 0.8, animationProgress)` → content fades 0→1 between 30-80% of shell animation.
    func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ x: CGFloat) -> CGFloat {
        let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }

    /// Content-specific progress — decoupled from shell spring.
    /// Driven by vm.contentRevealProgress which has independent animation curves:
    /// - Open: easeOut(0.28s) with 0.08s delay — shell leads, content follows
    /// - Close: easeIn(0.15s) — content exits before shell finishes contracting
    /// Apple Dynamic Island pattern: shape morphs alone, then content reveals.
    var contentProgress: CGFloat {
        vm.contentRevealProgress
    }

    var cornerRadiusScaleFactor: CGFloat? {
        guard settings.cornerRadiusScaling else { return nil }
        let effectiveHeight = displayClosedNotchHeight
        guard effectiveHeight > 0 else { return nil }
        return effectiveHeight / 38.0
    }

    var topCornerRadius: CGFloat {
        interpolatedRadius(closed: cornerRadiusInsets.closed.top, opened: cornerRadiusInsets.opened.top)
    }

    var bottomCornerRadius: CGFloat {
        interpolatedRadius(closed: cornerRadiusInsets.closed.bottom, opened: cornerRadiusInsets.opened.bottom)
    }

    private func interpolatedRadius(closed base: CGFloat, opened: CGFloat) -> CGFloat {
        let closedRadius: CGFloat
        if let scaleFactor = cornerRadiusScaleFactor {
            closedRadius = max(0, base * scaleFactor)
        } else {
            closedRadius = displayClosedNotchHeight > 0 ? base : 0
        }
        return lerp(closedRadius, opened, animationProgress)
    }

    var currentNotchShape: NotchShape {
        NotchShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: bottomCornerRadius
        )
    }

    var computedChinWidth: CGFloat {
        switch vm.phase {
        case .opening, .closing:
            vm.notchSize.width
        case .open:
            openNotchSize.width
        case .closed:
            vm.effectiveClosedNotchSize.width
        }
    }
}

// MARK: - Gesture Handling

extension ContentView {
    func handleDownGesture(translation: CGFloat, phase: NSEvent.Phase) {
        let result = vm.gestureCoordinator.handleDown(
            translation: translation, phase: phase, notchState: vm.notchState,
            sensitivity: settings.gestureSensitivity
        )
        applyGestureResult(result, openAction: { velocity in doOpen(velocity: velocity) })
    }

    func handleUpGesture(translation: CGFloat, phase: NSEvent.Phase) {
        let result = vm.gestureCoordinator.handleUp(
            translation: translation, phase: phase,
            notchState: vm.notchState,
            isHoveringCalendar: vm.isHoveringCalendar,
            preventClose: pluginManager?.services.sharing.preventNotchClose ?? false,
            sensitivity: settings.gestureSensitivity
        )
        applyGestureResult(result, closeAction: { vm.close(force: true) })
    }

    func applyGestureResult(
        _ result: NotchGestureCoordinator.GestureResult,
        openAction: ((_ velocity: CGFloat) -> Void)? = nil,
        closeAction: (() -> Void)? = nil
    ) {
        switch result {
        case .progress(let value):
            // Scrub the phase coordinator directly
            if openAction != nil {
                vm.interactiveScrub(progress: value)
            } else {
                // For close gesture, we just use a simple scale/offset or trigger close.
                // Reverting to the existing logic just for visual feedback until close is scrubbed too.
                withAnimation(StandardAnimations.interactive) { gestureProgress = value * -20 } // Restore scale for close
            }
        case .reset:
            if openAction != nil {
                vm.cancelInteractiveScrub()
            } else {
                withAnimation(StandardAnimations.interactive) { gestureProgress = .zero }
            }
        case .triggerOpen(let velocity):
            if settings.enableHaptics { haptics.toggle() }
            openAction?(velocity)
        case .triggerClose:
            gestureProgress = .zero
            closeAction?()
            if settings.enableHaptics { haptics.toggle() }
        }
    }
}
