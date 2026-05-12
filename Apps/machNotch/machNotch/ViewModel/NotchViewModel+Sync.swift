//
//  NotchViewModel+Sync.swift
//  machNotch
//
//  State synchronisation helpers — window state, animation state, and background-image utility.
//

import SwiftUI

extension NotchViewModel {
    func syncWindowState() {
        if let skyLightWindow = window as? NotchSkyLightWindow {
            skyLightWindow.isNotchOpen = phase.isInteractive
        }
    }

    func syncAnimationState(animated: Bool = false) {
        uiContext.phase = phase
        uiContext.notchState = notchState

        guard !phase.isTransitioning else { return }

        let targetProgress: CGFloat = phase.isVisible ? 1 : 0

        if animated {
            let curve = phase.isVisible ? StandardAnimations.open : StandardAnimations.close
            withAnimation(curve) {
                self.shellAnimationProgress = targetProgress
                self.contentRevealProgress = targetProgress
            }
        } else {
            shellAnimationProgress = targetProgress
            contentRevealProgress = targetProgress
        }
    }

    static func copyBackgroundImageToAppStorage(sourceURL: URL) -> URL? {
        NotchObserverManager.copyBackgroundImageToAppStorage(sourceURL: sourceURL)
    }
}
