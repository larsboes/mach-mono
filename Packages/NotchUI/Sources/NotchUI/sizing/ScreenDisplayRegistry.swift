//
//  ScreenDisplayRegistry.swift
//  NotchUI
//
//  Centralized registry for multi-display UUID state and screen changes.
//

import AppKit
import SwiftUI

@MainActor
@Observable
public final class ScreenDisplayRegistry {
    public static let shared = ScreenDisplayRegistry()

    public private(set) var screensByUUID: [String: NSScreen] = [:]
    public private(set) var currentScreens: [NSScreen] = []

    public var onScreensChanged: (() -> Void)?

    @ObservationIgnored nonisolated(unsafe) private var observer: Any?

    private init() {
        rebuildCache()
        setupObserver()
    }

    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupObserver() {
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleScreenChange()
            }
        }
    }

    private func handleScreenChange() {
        let newScreens = NSScreen.screens

        let screensChanged =
            newScreens.count != currentScreens.count
            || Set(newScreens.compactMap { $0.displayUUID }) != Set(currentScreens.compactMap { $0.displayUUID })
            || Set(newScreens.map { $0.frame.debugDescription })
                != Set(currentScreens.map { $0.frame.debugDescription })

        if screensChanged {
            rebuildCache(with: newScreens)
            onScreensChanged?()
        }
    }

    private func rebuildCache(with screens: [NSScreen] = NSScreen.screens) {
        var newCache: [String: NSScreen] = [:]
        for screen in screens {
            if let uuid = screen.displayUUID {
                newCache[uuid] = screen
            }
        }
        self.screensByUUID = newCache
        self.currentScreens = screens
    }

    public func screen(forUUID uuid: String) -> NSScreen? {
        return screensByUUID[uuid]
    }
}
