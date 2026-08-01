//
//  AppDelegate.swift
//  machNotch
//

import AppKit
import Sparkle

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let graph = AppObjectGraph()

    /// Set by DynamicNotchApp after init to wire up Sparkle updater.
    var updaterController: SPUStandardUpdaterController?

    var statusItem: NSStatusItem?
    var whatsNewWindow: NSWindow?
    var timer: Timer?
    var onboardingWindowController: NSWindowController?
    private var previousScreens: [NSScreen]?

    // MARK: - Legacy Accessors

    var pluginManager: PluginManager { graph.pluginManager }
    var coordinator: NotchViewCoordinator { graph.coordinator }
    var vm: NotchViewModel { graph.vm }
    var window: NSWindow? { graph.window }
    var windows: [String: NSWindow] { graph.windows }
    var viewModels: [String: NotchViewModel] { graph.viewModels }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
            let url = URL(string: urlString)
        else { return }
        URLSchemeHandler.handle(url, graph: graph)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return
        }

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        graph.localAPIServerController.start()

        if let updaterController {
            graph.settingsWindowController.setUpdaterController(updaterController)
        }

        graph.settingsWindowController.configure(
            coordinator: coordinator,
            pluginManager: pluginManager,
            settings: graph.settings
        )

        ScreenDisplayRegistry.shared.onScreensChanged = { [weak self] in
            self?.screenConfigurationDidChange()
        }

        graph.startObservationTracking()
        graph.keyboardShortcutCoordinator.setupKeyboardShortcuts()
        syncNotchHeightIfNeeded(settings: graph.settings)
        graph.adjustWindowPosition(changeAlpha: true)
        graph.setupDragDetectors()

        coordinator.configure(
            eventBus: pluginManager.eventBus,
            mediaKeyInterceptor: graph.mediaKeyInterceptor
        )

        Task {
            await pluginManager.activateEnabledPlugins()
        }

        if coordinator.firstLaunch {
            Task { @MainActor in
                self.showOnboardingWindow()
            }
        } else if pluginManager.services.music.isNowPlayingDeprecated
            && graph.settings.mediaController == .nowPlaying
        {
            Task { @MainActor in
                self.showOnboardingWindow(step: .musicPermission)
            }
        }

        graph.playWelcomeSound()
        previousScreens = NSScreen.screens
    }

    func applicationWillTerminate(_ notification: Notification) {
        pluginManager.services.shelf.flushSync()

        Task {
            await pluginManager.deactivateAllPlugins()
        }
        graph.localAPIServerController.stop()

        pluginManager.services.music.destroy()

        graph.cleanupDragDetectors()
        graph.cleanupWindows()
        graph.keyboardShortcutCoordinator.cancelPendingTasks()

        graph.pluginManager.services.xpcHelper.stopMonitoringAccessibilityAuthorization()
    }

    @objc func screenConfigurationDidChange() {
        let currentScreens = NSScreen.screens
        let screensChanged =
            currentScreens.count != previousScreens?.count
            || Set(currentScreens.compactMap { $0.displayUUID })
                != Set(previousScreens?.compactMap { $0.displayUUID } ?? [])
            || Set(currentScreens.map { $0.frame.debugDescription })
                != Set(previousScreens?.map { $0.frame.debugDescription } ?? [])

        previousScreens = currentScreens

        if screensChanged {
            Task { @MainActor [weak self] in
                guard let self else { return }
                syncNotchHeightIfNeeded(settings: self.graph.settings)
                self.graph.cleanupWindows()
                self.graph.adjustWindowPosition()
                self.graph.setupDragDetectors()
            }
        }
    }
}
