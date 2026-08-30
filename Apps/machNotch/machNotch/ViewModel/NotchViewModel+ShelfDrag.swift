//
//  NotchViewModel+ShelfDrag.swift
//  machNotch — mach-mono
//
//  Drag-to-shelf wiring for one notch window.
//
//  `DragDropService` installs system-wide mouse monitors while at least one
//  observer is registered, so registration is the on/off switch for that cost.
//  Each window registers its own screen region, which is why a second display
//  no longer overwrites the first one's handlers.
//

import Defaults
import SwiftUI

extension NotchViewModel {

    /// The open-notch rectangle on this window's screen. Empty when the screen
    /// is unknown, which keeps the observer registered but never triggering.
    func shelfDragRegion() -> CGRect {
        guard let screenFrame = getScreenFrame(screenUUID) else { return .zero }
        let width = openNotchSize.width
        let height = openNotchSize.height
        return CGRect(
            x: screenFrame.midX - width / 2,
            y: screenFrame.maxY - height,
            width: width,
            height: height
        )
    }

    /// Registers this window's drag observer, or removes it, to match the shelf
    /// setting. Turning the shelf off takes the mouse monitors down with it.
    func syncShelfDragBehavior() {
        guard settings.shelfEnabled else {
            detachShelfDragBehavior()
            return
        }
        guard shelfDragToken == nil else { return }

        shelfDragToken = services.dragDrop.addObserver(
            region: shelfDragRegion(),
            onEnter: { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    self.dragDetectorTargeting = true
                    self.open()
                    self.currentView = .shelf
                }
            },
            onExit: { [weak self] in
                Task { @MainActor in
                    self?.dragDetectorTargeting = false
                }
            },
            onMove: nil
        )
    }

    /// Call before dropping a view model. `deinit` cannot do this: it is
    /// nonisolated, so it cannot reach the main-actor drag service, and an
    /// observer left behind keeps the system-wide monitors alive for a window
    /// that no longer exists.
    func teardownShelfDrag() {
        shelfDragSettingTask?.cancel()
        shelfDragSettingTask = nil
        detachShelfDragBehavior()
    }

    func detachShelfDragBehavior() {
        guard let token = shelfDragToken else { return }
        services.dragDrop.removeObserver(token)
        shelfDragToken = nil
        dragDetectorTargeting = false
    }

    /// Adds or removes this window's drag observer when the shelf setting flips.
    func beginShelfDragSettingObservation() {
        shelfDragSettingTask?.cancel()
        shelfDragSettingTask = Task { @MainActor [weak self] in
            for await _ in Defaults.updates(DefaultsNotchSettings.shelfEnabledKey, initial: false) {
                guard let self, !Task.isCancelled else { break }
                self.syncShelfDragBehavior()
            }
        }
    }
}
