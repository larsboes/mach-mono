//
//  NotchViewModel+Hover.swift
//  machNotch — mach-mono
//
//  Hover zone sizing and heartbeat-driven open/close hints bridged into NotchHoverController.
//

import AppKit
import Foundation

extension NotchViewModel {

    // MARK: - Hover window binding

    func setHoverWindow(_ window: NSWindow?) {
        self.window = window
    }

    func updateHoverZone() {
        hoverController.updateHoverZone(screenUUID: screenUUID)
    }

    // MARK: - Heartbeat wiring

    func configureHoverCallbacks() {
        hoverController.isShelfActive = { [weak self] in
            self?.currentView == .shelf
        }

        hoverController.onShouldOpen = { [weak self] in
            guard let self else { return }
            guard settings.openNotchOnHover else { return }
            guard !coordinator.sneakPeek.show else { return }
            open()
        }

        hoverController.onShouldClose = { [weak self] in
            self?.close(force: true)
        }
    }

    // MARK: - Tracking-area hints

    func handleHoverSignal(_ signal: HoverSignal) {
        hoverController.handleHoverHint(signal)
    }

    // MARK: - Legacy entry points (tests / older call sites)

    func mouseEntered() {
        handleHoverSignal(.entered)
    }

    func mouseExited() {
        handleHoverSignal(.exited)
    }

    func scheduleClose() {
        hoverController.tick()
    }

    func setupHoverController() {}

    func cancelPendingClose() {
        hoverController.cancelPendingClose()
    }

    func cancelPendingOpen() {
        hoverController.cancelPendingOpen()
    }
}
