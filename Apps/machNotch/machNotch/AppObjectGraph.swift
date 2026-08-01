//
//  AppObjectGraph.swift
//  machNotch
//
//  Central DI root — constructs all services, coordinators, and wires dependencies.
//

import Combine
import Defaults
import Foundation
import SwiftUI

#if MACH_NOTCH_SOUNDSCAPE
    import NotchPluginsWithSoundscape
#endif

@MainActor
final class AppObjectGraph {

    // MARK: - Core Services

    let eventBus = PluginEventBus()
    let settings = DefaultsNotchSettings()
    let spaceManager = NotchSpaceManager()
    let permissionStore = PermissionStateStore()
    let settingsWindowController = SettingsWindowController()
    lazy var coordinator = NotchViewCoordinator(settings: settings, xpcHelper: XPCHelperClient.shared)
    lazy var localAPIServerController = LocalAPIServerController(
        eventBus: eventBus,
        pluginManager: pluginManager,
        // [unowned self] is safe: AppObjectGraph owns LocalAPIServerController via lazy
        // var, so the controller cannot outlive the graph.
        viewModelProvider: { [unowned self] in self.vm }
    )

    init() {
        // One-time legacy URL cache migration
        if settings.consumeLegacyCacheCleanupFlag() {
            URLCache.shared.removeAllCachedResponses()
        }

        // Subscribe to HUD value change events from the Presentation layer
        setupHUDEventHandler()
    }

    private var hudEventCancellable: AnyCancellable?

    private func setupHUDEventHandler() {
        hudEventCancellable = eventBus.subscribe(to: HUDValueChangeEvent.self) { [weak self] event in
            guard let self = self else { return }
            let services = self.pluginManager.services
            switch event.hudType {
            case .volume:
                services.volume.setAbsolute(Float32(event.newValue))
            case .brightness:
                services.brightness.setAbsolute(value: Float32(event.newValue))
            default:
                break
            }
        }
    }

    lazy var pluginManager: PluginManager = {
        PluginManager(
            services: ServiceContainer(eventBus: eventBus, settings: settings, xpcHelper: XPCHelperClient.shared),
            eventBus: eventBus,
            appState: NotchAppState(),
            mediaSettings: settings,
            coordinator: coordinator,
            builtInDescriptors: Self.makeBuiltInPluginDescriptors()
        )
    }()

    private static func makeBuiltInPluginDescriptors() -> [PluginDescriptor] {
        #if MACH_NOTCH_SOUNDSCAPE
            SoundscapePluginRegistry.makeBuiltInDescriptors()
        #else
            PluginRegistry.makeBuiltInDescriptors()
        #endif
    }

    // MARK: - View Model

    lazy var vm: NotchViewModel = {
        NotchViewModel(
            coordinator: coordinator,
            detector: fullscreenDetector,
            services: pluginManager.services,
            settings: DefaultNotchViewModelSettings(source: settings),
            displaySettings: settings
        )
    }()

    // MARK: - Coordinators

    lazy var fullscreenDetector: FullscreenMediaDetector = {
        FullscreenMediaDetector(musicService: pluginManager.services.music, settings: settings)
    }()

    lazy var mediaKeyInterceptor: MediaKeyInterceptor = {
        MediaKeyInterceptor(
            volumeService: pluginManager.services.volume,
            brightnessService: pluginManager.services.brightness,
            keyboardBacklightService: pluginManager.services.keyboardBacklight,
            eventBus: eventBus,
            settings: settings,
            xpcHelper: XPCHelperClient.shared
        )
    }()

    lazy var windowCoordinator: WindowCoordinator = {
        let wc = WindowCoordinator(
            primaryViewModel: vm,
            coordinator: coordinator,
            settings: settings,
            pluginManager: pluginManager,
            detector: fullscreenDetector,
            spaceManager: spaceManager
        )
        wc.onDragDetectorsNeedSetup = { [weak self] in
            self?.dragDetectionCoordinator.setupDragDetectors()
        }
        wc.showSettingsWindow = { [weak self] in
            self?.settingsWindowController.showWindow()
        }
        return wc
    }()

    lazy var keyboardShortcutCoordinator: KeyboardShortcutCoordinator = {
        KeyboardShortcutCoordinator(
            coordinator: coordinator, eventBus: eventBus, windowCoordinator: windowCoordinator, settings: settings)
    }()

    lazy var dragDetectionCoordinator: DragDetectionCoordinator = {
        DragDetectionCoordinator(windowCoordinator: windowCoordinator, coordinator: coordinator, settings: settings)
    }()

    // MARK: - Convenience Accessors

    var window: NSWindow? { windowCoordinator.window }
    var windows: [String: NSWindow] { windowCoordinator.windows }
    var viewModels: [String: NotchViewModel] { windowCoordinator.viewModels }

    var isScreenLocked: Bool {
        get { windowCoordinator.isScreenLocked }
        set { windowCoordinator.isScreenLocked = newValue }
    }

    // MARK: - Delegation Methods

    func adjustWindowPosition(changeAlpha: Bool = false) {
        windowCoordinator.adjustWindowPosition(changeAlpha: changeAlpha)
    }

    func cleanupWindows(shouldInvert: Bool = false) {
        windowCoordinator.cleanupWindows(shouldInvert: shouldInvert)
    }

    func setupDragDetectors() {
        dragDetectionCoordinator.setupDragDetectors()
    }

    func cleanupDragDetectors() {
        dragDetectionCoordinator.cleanupDragDetectors()
    }

    func playWelcomeSound() {
        pluginManager.services.sound.play(.welcome)
    }

    func deviceHasNotch() -> Bool {
        for screen in NSScreen.screens {
            if screen.safeAreaInsets.top > 0 {
                return true
            }
        }
        return false
    }

    // MARK: - Screen Lock/Unlock

    func onScreenLocked() {
        isScreenLocked = true
        if !settings.showOnLockScreen {
            cleanupWindows()
        } else {
            windowCoordinator.enableSkyLightOnAllWindows()
        }
    }

    func onScreenUnlocked() {
        isScreenLocked = false
        if !settings.showOnLockScreen {
            adjustWindowPosition(changeAlpha: true)
        } else {
            windowCoordinator.disableSkyLightOnAllWindows()
        }
    }

    // MARK: - Observation Tracking

    private var observerTasks: [Task<Void, Never>] = []
    private var screenLockedObserver: Any?
    private var screenUnlockedObserver: Any?

    func startObservationTracking() {
        // System events — not settings-driven, stay as notification observers
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.adjustWindowPosition() }
        }

        screenLockedObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(rawValue: "com.apple.screenIsLocked"),
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.onScreenLocked() }
        }
        screenUnlockedObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(rawValue: "com.apple.screenIsUnlocked"),
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.onScreenUnlocked() }
        }

        // ─── Merged Defaults-backed observations ─────────────────────────────
        // Replaced 5 separate withObservationTracking+withCheckedContinuation loops
        // with 2 streamlined tasks using Defaults.updates (async sequences).
        // Defaults.updates uses lightweight KVO internally — no continuation overhead.

        // Group A: showOnAllDisplays → full window layout reset (separate because
        // it calls cleanupWindows which is expensive and should not run on every
        // sizing property change).
        observerTasks.append(
            Task { @MainActor [weak self] in
                for await _ in Defaults.updates(DefaultsNotchSettings.showOnAllDisplaysKey) {
                    guard let self, !Task.isCancelled else { break }
                    self.cleanupWindows(shouldInvert: true)
                    self.adjustWindowPosition(changeAlpha: true)
                    self.setupDragDetectors()
                }
            })

        // Group B: All other Defaults-backed properties → window position &
        // drag detector geometry. Uses Defaults.updates with an array of keys
        // to watch sizing, drag, and auto-switch properties in a single task.
        // Duplicate calls to adjustWindowPosition/setupDragDetectors are harmless
        // (they're idempotent).
        observerTasks.append(
            Task { @MainActor [weak self] in
                for await _ in Defaults.updates([
                    DefaultsNotchSettings.automaticallySwitchDisplayKey,
                    DefaultsNotchSettings.notchHeightKey,
                    DefaultsNotchSettings.notchHeightModeKey,
                    DefaultsNotchSettings.nonNotchHeightKey,
                    DefaultsNotchSettings.nonNotchHeightModeKey,
                    DefaultsNotchSettings.inactiveNotchHeightKey,
                    DefaultsNotchSettings.useInactiveNotchHeightKey,
                    DefaultsNotchSettings.expandedDragDetectionKey,
                ]) {
                    guard let self, !Task.isCancelled else { break }

                    // Update alpha for auto-switch (no-op if feature is off)
                    if let window = self.window {
                        window.alphaValue =
                            self.coordinator.selectedScreenUUID == self.coordinator.preferredScreenUUID ? 1 : 0
                    }

                    self.adjustWindowPosition()
                    self.setupDragDetectors()
                }
            })

        // ─── @Observable property ────────────────────────────────────────────
        // coordinator.selectedScreenUUID is @Observable, not Defaults-backed.
        // This is the single remaining withObservationTracking task (reduced from 6).
        observerTasks.append(
            Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                        withObservationTracking {
                            _ = self?.coordinator.selectedScreenUUID
                        } onChange: {
                            c.resume()
                        }
                    }
                    guard let self, !Task.isCancelled else { return }
                    self.adjustWindowPosition(changeAlpha: true)
                    self.setupDragDetectors()
                }
            })
    }
}
