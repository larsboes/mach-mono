//
//  machNotchApp.swift
//  machNotchApp
//
//  Created by Harsh Vardhan  Goswami  on 02/08/24.
//

import AVFoundation
import KeyboardShortcuts
import Sparkle
import SwiftUI

/// Sparkle user driver delegate to handle gentle reminders for background updates
final class SparkleUserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool {
        return true
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        // No-op: Let Sparkle handle showing updates normally
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        // No-op: User has acknowledged the update
    }

    func standardUserDriverWillFinishUpdateSession() {
        // No-op: Update session is finishing
    }
}

@main
struct DynamicNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) var openWindow

    let updaterController: SPUStandardUpdaterController
    private let userDriverDelegate = SparkleUserDriverDelegate()

    init() {
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

        #if DEBUG
        let startUpdater = false
        #else
        let startUpdater = !isRunningTests
        #endif
        updaterController = SPUStandardUpdaterController(
            startingUpdater: startUpdater, updaterDelegate: nil, userDriverDelegate: userDriverDelegate)

        // Pass the updater controller to appDelegate for wiring in applicationDidFinishLaunching
        appDelegate.updaterController = updaterController
    }

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private var showMenuBarIconBinding: Binding<Bool> {
        Binding(
            get: { appDelegate.graph.settings.menubarIcon },
            set: { appDelegate.graph.settings.menubarIcon = $0 }
        )
    }

    var body: some Scene {
        MenuBarExtra("mach.notch", systemImage: "sparkle", isInserted: showMenuBarIconBinding) {
            PluginMenuBarItems()
            Button("Settings") {
                appDelegate.graph.settingsWindowController.showWindow()
            }
            .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
            CheckForUpdatesView(updater: updaterController.updater)
            Divider()
            Button("Restart machNotch") {
                ApplicationRelauncher.restart()
            }
            Button("Quit", role: .destructive) {
                NSApplication.shared.terminate(self)
            }
            .keyboardShortcut(KeyEquivalent("Q"), modifiers: .command)
        }
        .environment(\.pluginManager, appDelegate.graph.pluginManager)
    }
}

// MARK: - AppDelegate (Lifecycle Only)

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let graph = AppObjectGraph()

    /// Set by DynamicNotchApp after init to wire up Sparkle updater
    var updaterController: SPUStandardUpdaterController?

    var statusItem: NSStatusItem?
    var whatsNewWindow: NSWindow?
    var timer: Timer?
    private var previousScreens: [NSScreen]?
    private var onboardingWindowController: NSWindowController?

    // MARK: - Legacy Accessors

    var pluginManager: PluginManager { graph.pluginManager }
    var coordinator: NotchViewCoordinator { graph.coordinator }
    var vm: NotchViewModel { graph.vm }
    var window: NSWindow? { graph.window }
    var windows: [String: NSWindow] { graph.windows }
    var viewModels: [String: NotchViewModel] { graph.viewModels }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - URL Scheme Handling

    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else { return }
        URLSchemeHandler.handle(url, graph: graph)
    }

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return
        }

        // Register URL scheme handler
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        graph.localAPIServerController.start()

        if let updaterController = updaterController {
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

        // Subscribe to events AFTER the window is created so that plugin
        // activation events (music sneak peek, battery, etc.) don't set
        // expanding view state before the first render.
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
            && graph.settings.mediaController == .nowPlaying {
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

    // MARK: - Screen Configuration

    @objc func screenConfigurationDidChange() {
        let currentScreens = NSScreen.screens
        let screensChanged =
            currentScreens.count != previousScreens?.count
            || Set(currentScreens.compactMap { $0.displayUUID })
                != Set(previousScreens?.compactMap { $0.displayUUID } ?? [])
            || Set(currentScreens.map { $0.frame.debugDescription }) != Set(previousScreens?.map { $0.frame.debugDescription } ?? [])

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

    // MARK: - Onboarding

    private func showOnboardingWindow(step: OnboardingStep = .welcome) {
        if onboardingWindowController == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
                styleMask: [.titled, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Onboarding"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.contentView = NSHostingView(
                rootView: OnboardingView(
                    step: step,
                    permissionStore: self.graph.permissionStore,
                    onFinish: {
                        window.orderOut(nil)
                        window.close()
                        NSApp.deactivate()
                    },
                    onOpenSettings: { [weak self] in
                        window.close()
                        self?.graph.settingsWindowController.showWindow()
                    }
                )
                .environment(self.graph.coordinator)
                .environment(\.pluginManager, self.graph.pluginManager)
                .environment(\.settings, self.graph.settings)
                .environment(\.bindableSettings, self.graph.settings)
                .environment(\.xpcHelper, self.graph.pluginManager.services.xpcHelper))
            window.isRestorable = false
            window.identifier = NSUserInterfaceItemIdentifier("OnboardingWindow")
            onboardingWindowController = NSWindowController(window: window)
        }

        NSApp.activate(ignoringOtherApps: true)
        onboardingWindowController?.window?.makeKeyAndOrderFront(nil)
        onboardingWindowController?.window?.orderFrontRegardless()
    }
}
