//
//  WindowCoordinator.swift
//  boringNotch
//
//  Created as part of Phase 3 architectural refactoring.
//  Extracted from AppDelegate - handles window creation, positioning, and multi-display support.
//

import AppKit
import Defaults
import SwiftUI

/// Coordinates window management for the notch across single and multiple displays.
@MainActor
final class WindowCoordinator {
    // MARK: - Properties
    var window: NSWindow?
    var windows: [String: NSWindow] = [:]
    var viewModels: [String: BoringViewModel] = [:]
    var stateMachines: [String: NotchStateMachine] = [:]
    let primaryViewModel: BoringViewModel
    lazy var primaryStateMachine: NotchStateMachine = NotchStateMachine(settings: settings)
    let coordinator: BoringViewCoordinator
    let settings: NotchSettings
    let pluginManager: PluginManager
    let detector: FullscreenMediaDetector
    let spaceManager: NotchSpaceManager
    var isScreenLocked: Bool = false
    private var windowScreenDidChangeObserver: Any?
    var onDragDetectorsNeedSetup: (() -> Void)?
    var showSettingsWindow: (() -> Void)?

    // Display Reconfiguration Callback
    private let displayCallback: CGDisplayReconfigurationCallBack = { display, flags, userInfo in
        guard let userInfo = userInfo else { return }
        let coordinator = Unmanaged<WindowCoordinator>.fromOpaque(userInfo).takeUnretainedValue()
        
        if flags.contains(.beginConfigurationFlag) {
            // Potential optimization: could pause layout during reconfiguration
        } else {
            // Reconfiguration finished - trigger update
            Task { @MainActor in
                coordinator.adjustWindowPosition()
                coordinator.onDragDetectorsNeedSetup?()
            }
        }
    }

    // MARK: - Initialization
    init(
        primaryViewModel: BoringViewModel,
        coordinator: BoringViewCoordinator,
        settings: NotchSettings,
        pluginManager: PluginManager,
        detector: FullscreenMediaDetector,
        spaceManager: NotchSpaceManager
    ) {
        self.primaryViewModel = primaryViewModel
        self.coordinator = coordinator
        self.settings = settings
        self.pluginManager = pluginManager
        self.detector = detector
        self.spaceManager = spaceManager
        
        // Register display reconfiguration callback
        CGDisplayRegisterReconfigurationCallback(displayCallback, Unmanaged.passUnretained(self).toOpaque())
    }
    
    deinit {
        CGDisplayRemoveReconfigurationCallback(displayCallback, Unmanaged.passUnretained(self).toOpaque())
    }

    // MARK: - Window Lifecycle
    func cleanupWindows(shouldInvert: Bool = false) {
        let shouldCleanupMulti = shouldInvert ? !settings.showOnAllDisplays : settings.showOnAllDisplays

        if shouldCleanupMulti {
            windows.values.forEach { window in
                window.close()
                spaceManager.notchSpace.windows.remove(window)
            }
            windows.removeAll()
            viewModels.removeAll()
            stateMachines.removeAll()
        } else if let window = window {
            window.close()
            spaceManager.notchSpace.windows.remove(window)
            if let obs = windowScreenDidChangeObserver {
                NotificationCenter.default.removeObserver(obs)
                windowScreenDidChangeObserver = nil
            }
            self.window = nil
        }
    }

    // MARK: - Window Creation
    func createBoringNotchWindow(for screen: NSScreen, with viewModel: BoringViewModel, stateMachine: NotchStateMachine) -> NSWindow {
        let rect = NSRect(x: 0, y: 0, width: windowSize.width, height: windowSize.height)
        let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow]

        let window = BoringNotchSkyLightWindow(
            contentRect: rect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false,
            settings: settings
        )

        if isScreenLocked {
            window.enableSkyLight()
        } else {
            window.disableSkyLight()
        }

        window.contentView = NSHostingView(
            rootView: ContentView()
                .environment(viewModel)
                .environment(coordinator)
                .environment(stateMachine)
                .environment(\.pluginManager, pluginManager as PluginManager?)
                .environment(\.settings, settings)
                .environment(\.bindableSettings, (settings as? DefaultsNotchSettings) ?? DefaultsNotchSettings.shared)
                .environment(\.xpcHelper, pluginManager.services.xpcHelper)
                .environment(\.showSettingsWindow, showSettingsWindow ?? {})
        )

        window.orderFrontRegardless()
        spaceManager.notchSpace.windows.insert(window)
        viewModel.setHoverWindow(window)
        viewModel.setupHoverController()

        windowScreenDidChangeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeScreenNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.onDragDetectorsNeedSetup?()
            }
        }

        return window
    }

    // MARK: - Window Positioning
    func positionWindow(_ window: NSWindow, on screen: NSScreen, changeAlpha: Bool = false) {
        if changeAlpha {
            window.alphaValue = 0
        }
        let screenFrame = screen.frame
        window.setFrameOrigin(
            NSPoint(
                x: screenFrame.origin.x + (screenFrame.width / 2) - window.frame.width / 2,
                y: screenFrame.origin.y + screenFrame.height - window.frame.height
            )
        )
        window.alphaValue = 1
    }

    func adjustWindowPosition(changeAlpha: Bool = false) {
        if settings.showOnAllDisplays {
            adjustMultiDisplayWindows(changeAlpha: changeAlpha)
        } else {
            adjustSingleDisplayWindow(changeAlpha: changeAlpha)
        }
    }

    // MARK: - ViewModel Access
    func viewModel(for screenUUID: String) -> BoringViewModel? {
        if settings.showOnAllDisplays {
            return viewModels[screenUUID]
        } else {
            return primaryViewModel
        }
    }

    func viewModel(at point: NSPoint) -> BoringViewModel {
        if settings.showOnAllDisplays {
            for screen in NSScreen.screens {
                if screen.frame.contains(point) {
                    if let uuid = screen.displayUUID, let screenViewModel = viewModels[uuid] {
                        return screenViewModel
                    }
                }
            }
        }
        return primaryViewModel
    }
}
