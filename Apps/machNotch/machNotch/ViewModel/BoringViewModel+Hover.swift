//
//  BoringViewModel+Hover.swift
//  boringNotch
//
//  Hover zone management and heartbeat integration for BoringViewModel.
//

import Foundation
import AppKit

extension BoringViewModel {
    // MARK: - Hover Zone Management

    func setHoverWindow(_ window: NSWindow?) {
        self.window = window
    }

    func updateHoverZone() {
        hoverController.updateHoverZone(screenUUID: screenUUID)
    }

    // MARK: - Heartbeat Lifecycle

    func configureHoverCallbacks() {
        hoverController.isShelfActive = { [weak self] in
            self?.currentView == .shelf
        }
        hoverController.onShouldOpen = { [weak self] in
            guard let self else { return }
            guard self.settings.openNotchOnHover else { return }
            guard !self.coordinator.sneakPeek.show else { return }
            self.open()
        }
        hoverController.onShouldClose = { [weak self] in
            self?.close(force: true)
        }
    }

    func startHoverHeartbeat() {
        hoverController.startHeartbeat()
    }

    func stopHoverHeartbeat() {
        hoverController.stopHeartbeat()
    }

    // MARK: - Hover Signal (TrackingArea hint)

    func handleHoverSignal(_ signal: HoverSignal) {
        hoverController.handleHoverHint(signal)
    }

    // MARK: - Legacy Compatibility

    func mouseEntered() {
        handleHoverSignal(.entered)
    }

    func mouseExited() {
        handleHoverSignal(.exited)
    }

    func scheduleClose() {
        // Heartbeat handles close scheduling via tick().
        // Trigger an immediate tick in case heartbeat isn't running yet.
        hoverController.tick()
    }

    func setupHoverController() {
        // No-op: hover logic is in hoverController heartbeat
    }

    func cancelPendingClose() {
        hoverController.cancelPendingClose()
    }
}
