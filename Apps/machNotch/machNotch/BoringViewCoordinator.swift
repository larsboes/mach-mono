//
//  BoringViewCoordinator.swift
//  boringNotch
//
//  Created by Alexander on 2024-11-20.
//

import AppKit
import Combine
import Defaults
import SwiftUI

@MainActor
@Observable class BoringViewCoordinator: ViewCoordinating {
    var currentView: NotchViews = .home
    var isScrollableViewPresented: Bool = false
    var helloAnimationRunning: Bool = false
    var hudEnableTask: Task<Void, Never>?

    var settings: any CoordinatorSettings

    var selectedScreenUUID: String = NSScreen.main?.displayUUID ?? ""

    var optionKeyPressed: Bool = true
    private var accessibilityObserver: Any?
    var hudReplacementCancellable: AnyCancellable?
    var musicSneakPeekCancellable: AnyCancellable?

    // Injected service
    var shelfService: ShelfServiceProtocol?
    var mediaKeyInterceptor: MediaKeyInterceptor?
    var xpcHelper: any XPCHelperServiceProtocol

    var sneakPeekDuration: TimeInterval
    var sneakPeekTask: Task<Void, Never>?

    var sneakPeek: SneakPeekState = .init() {
        didSet {
            if sneakPeek.show {
                scheduleSneakPeekHide(after: sneakPeekDuration)
            } else {
                sneakPeekTask?.cancel()
            }
        }
    }

    var expandingViewTask: Task<Void, Never>?

    var expandingView: ExpandedItem = .init() {
        didSet {
            guard expandingView.show != oldValue.show else { return }
            if expandingView.show {
                expandingViewTask?.cancel()
                let duration: TimeInterval = (expandingView.type == .download ? 2 : 3)
                expandingViewTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(duration))
                    guard let self, !Task.isCancelled else { return }
                    withAnimation(.smooth) {
                        self.expandingView.show = false
                    }
                }
            } else {
                expandingViewTask?.cancel()
            }
        }
    }

    nonisolated deinit {
        MainActor.assumeIsolated {
            sneakPeekTask?.cancel()
            expandingViewTask?.cancel()
            hudEnableTask?.cancel()
            if let accessibilityObserver {
                NotificationCenter.default.removeObserver(accessibilityObserver)
            }
        }
    }

    init(settings: any CoordinatorSettings, xpcHelper: any XPCHelperServiceProtocol) {
        self.settings = settings
        self.xpcHelper = xpcHelper
        self.sneakPeekDuration = settings.sneakPeakDuration

        // Perform migration from name-based to UUID-based storage
        let legacyName = UserDefaults.standard.string(forKey: "preferred_screen_name")

        if settings.preferredScreenUUID == nil, let legacyName = legacyName {
            if let screen = NSScreen.screens.first(where: { $0.localizedName == legacyName }),
               let uuid = screen.displayUUID {
                self.settings.preferredScreenUUID = uuid
                NSLog("Migrated display preference from name '\(legacyName)' to UUID '\(uuid)'")
            } else {
                self.settings.preferredScreenUUID = NSScreen.main?.displayUUID
                NSLog("Could not find display named '\(legacyName)', falling back to main screen")
            }
            UserDefaults.standard.removeObject(forKey: "preferred_screen_name")
        } else if self.settings.preferredScreenUUID == nil {
            self.settings.preferredScreenUUID = NSScreen.main?.displayUUID
        }

        selectedScreenUUID = settings.preferredScreenUUID ?? NSScreen.main?.displayUUID ?? ""

        setupObservers()
        setupInitialState()
    }

    private func setupObservers() {
        // Observe changes to accessibility authorization
        accessibilityObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.accessibilityAuthorizationChanged,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                if self.settings.hudReplacement {
                    await self.mediaKeyInterceptor?.start(promptIfNeeded: false)
                }
            }
        }

        // NOTE: Defaults.publisher/updates is required here because DefaultsNotchSettings
        // uses @Observable with computed properties. The @Observable macro only instruments
        // stored properties, so withObservationTracking won't fire for Defaults-backed
        // computed properties. This is an accepted architectural exception.

        // Observe changes to hudReplacement
        hudReplacementCancellable = Defaults.publisher(.hudReplacement)
            .sink { [weak self] change in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.hudEnableTask?.cancel()
                    self.hudEnableTask = nil

                    if change.newValue {
                        self.hudEnableTask = Task { @MainActor in
                            let granted = await self.xpcHelper.ensureAccessibilityAuthorization(promptIfNeeded: true)
                            if Task.isCancelled { return }
                            if granted {
                                await self.mediaKeyInterceptor?.start()
                            } else {
                                self.settings.hudReplacement = false
                            }
                        }
                    } else {
                        self.mediaKeyInterceptor?.stop()
                    }
                }
            }

        // Observe changes to alwaysShowTabs (settings mutation only;
        // currentView reset is now per-screen in BoringViewModel.setupTabResetObserver)
        Task { @MainActor in
            for await value in Defaults.updates(.alwaysShowTabs) {
                if !value {
                    self.settings.openLastTabByDefault = false
                }
            }
        }

        // Observe changes to openLastTabByDefault
        Task { @MainActor in
            for await value in Defaults.updates(.openLastTabByDefault) {
                if value {
                    self.settings.alwaysShowTabs = true
                }
            }
        }

        // Observe changes to preferredScreenUUID
        Task { @MainActor in
            for await uuid in Defaults.updates(.preferredScreenUUID) {
                if let uuid = uuid {
                    selectedScreenUUID = uuid
                }
                NotificationCenter.default.post(name: Notification.Name.selectedScreenChanged, object: nil)
            }
        }
    }

    private func setupInitialState() {
        Task { @MainActor in
            helloAnimationRunning = settings.firstLaunch

            if helloAnimationRunning {
                try? await Task.sleep(for: .seconds(10))
                if helloAnimationRunning {
                    helloAnimationRunning = false
                }
            }

            if settings.hudReplacement {
                let authorized = await xpcHelper.isAccessibilityAuthorized()
                if !authorized {
                    settings.hudReplacement = false
                } else {
                    await mediaKeyInterceptor?.start(promptIfNeeded: false)
                }
            }
        }
    }

    // MARK: - Forwarding Properties (for external callers)

    var firstLaunch: Bool {
        get { settings.firstLaunch }
        set { settings.firstLaunch = newValue }
    }

    var alwaysShowTabs: Bool {
        get { settings.alwaysShowTabs }
        set { settings.alwaysShowTabs = newValue }
    }

    var openLastTabByDefault: Bool {
        get { settings.openLastTabByDefault }
        set { settings.openLastTabByDefault = newValue }
    }

    var preferredScreenUUID: String? {
        get { settings.preferredScreenUUID }
        set { settings.preferredScreenUUID = newValue }
    }

    // showEmpty() removed — currentView is now per-screen on BoringViewModel
}
