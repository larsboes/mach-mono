//
//  AppObjectGraph.swift
//  machNotch
//
//  Central DI root — constructs all services, coordinators, and wires dependencies.
//

import Combine
import Foundation
import SwiftUI

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
            builtInPlugins: PluginRegistry.makeBuiltInPlugins()
        )
    }()

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
        // System event — not settings-driven, stays as notification
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.adjustWindowPosition() }
        }

        // Screen lock/unlock via distributed notifications — no @Observable equivalent
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

        // showOnAllDisplays → full window layout reset
        observerTasks.append(
            Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                        withObservationTracking {
                            _ = self?.settings.showOnAllDisplays
                        } onChange: {
                            c.resume()
                        }
                    }
                    guard let self, !Task.isCancelled else { return }
                    self.cleanupWindows(shouldInvert: true)
                    self.adjustWindowPosition(changeAlpha: true)
                    self.setupDragDetectors()
                }
            })

        // automaticallySwitchDisplay → window alpha for multi-display
        observerTasks.append(
            Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                        withObservationTracking {
                            _ = self?.settings.automaticallySwitchDisplay
                        } onChange: {
                            c.resume()
                        }
                    }
                    guard let self, !Task.isCancelled else { return }
                    guard let window = self.window else { continue }
                    window.alphaValue =
                        self.coordinator.selectedScreenUUID == self.coordinator.preferredScreenUUID ? 1 : 0
                }
            })

        // Sizing properties → window position + drag detector geometry
        observerTasks.append(
            Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                        withObservationTracking {
                            _ = self?.settings.notchHeight
                            _ = self?.settings.notchHeightMode
                            _ = self?.settings.nonNotchHeight
                            _ = self?.settings.nonNotchHeightMode
                            _ = self?.settings.inactiveNotchHeight
                            _ = self?.settings.useInactiveNotchHeight
                        } onChange: {
                            c.resume()
                        }
                    }
                    guard let self, !Task.isCancelled else { return }
                    self.adjustWindowPosition()
                    self.setupDragDetectors()
                }
            })

        // expandedDragDetection → drag detector rebuild
        observerTasks.append(
            Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                        withObservationTracking {
                            _ = self?.settings.expandedDragDetection
                        } onChange: {
                            c.resume()
                        }
                    }
                    guard let self, !Task.isCancelled else { return }
                    self.setupDragDetectors()
                }
            })

        // coordinator.selectedScreenUUID → window position after preferred screen change
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
