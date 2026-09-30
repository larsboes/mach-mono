//
//  DisplayActivityMonitor.swift
//  NotchUI
//
//  Tracks whether the screen is actually showing anything.
//
//  `TimelineView(.animation)` keeps firing while the display sleeps or the
//  session is locked — SwiftUI has no idea nobody is looking. The ambient
//  visualizer is the one always-on animation in the notch, so it reads this and
//  stops. Sleep and lock are used rather than window occlusion because both are
//  unambiguous: a wrong occlusion reading would freeze a visualizer that is
//  still on screen.
//

import AppKit
import SwiftUI

@MainActor
@Observable
public final class DisplayActivityMonitor {
    /// False while the display sleeps or the session is locked.
    public private(set) var isDisplayActive: Bool = true

    @ObservationIgnored private var observations: [(center: NotificationCenter, token: NSObjectProtocol)] = []

    public init() {
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.screensDidSleepNotification, active: false)
        observe(workspace, NSWorkspace.screensDidWakeNotification, active: true)

        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked"), active: false)
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked"), active: true)
    }

    nonisolated deinit {
        MainActor.assumeIsolated {
            for observation in observations {
                observation.center.removeObserver(observation.token)
            }
        }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, active: Bool) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.isDisplayActive = active }
        }
        observations.append((center, token))
    }
}
