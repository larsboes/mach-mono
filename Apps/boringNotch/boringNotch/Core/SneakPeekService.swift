//
//  SneakPeekService.swift
//  boringNotch
//
//  Extracted from BoringViewCoordinator — handles sneak peek and expanding view state.
//

import Combine
import SwiftUI

// MARK: - Sneak Peek Service Protocol

@MainActor
protocol SneakPeekServiceProtocol: AnyObject {
    var sneakPeek: SneakPeekState { get set }
    var expandingView: ExpandedItem { get set }

    func toggleSneakPeek(
        status: Bool,
        type: SneakContentType,
        duration: TimeInterval,
        value: CGFloat,
        icon: String
    )

    func toggleExpandingView(
        status: Bool,
        type: SneakContentType,
        value: CGFloat,
        browser: BrowserType
    )

    func handleSneakPeekEvent(_ notification: Notification)
}

// MARK: - Sneak Peek Service

@MainActor
@Observable
final class SneakPeekService: SneakPeekServiceProtocol {

    // MARK: - Public State

    var sneakPeek: SneakPeekState = .init()
    var expandingView: ExpandedItem = .init()

    // MARK: - Dependencies

    private let eventBus: PluginEventBus
    private let settings: NotchSettings
    private let onMicStatusChange: ((Bool) -> Void)?

    // MARK: - Private State

    private var sneakPeekTask: Task<Void, Never>?
    private var expandingViewTask: Task<Void, Never>?
    private var sneakPeekDuration: TimeInterval
    private var eventSubscription: AnyCancellable?

    // MARK: - Init

    init(
        eventBus: PluginEventBus,
        settings: NotchSettings,
        onMicStatusChange: ((Bool) -> Void)? = nil
    ) {
        self.eventBus = eventBus
        self.settings = settings
        self.sneakPeekDuration = settings.sneakPeakDuration
        self.onMicStatusChange = onMicStatusChange

        // NOTE: Do NOT auto-subscribe here. The coordinator already subscribes
        // to SneakPeekRequestedEvent in BoringViewCoordinator+Plugins.swift.
        // Call subscribeToSneakPeekEvents() only when this service replaces the
        // coordinator as the single source of truth for sneak peek state.
    }

    nonisolated deinit {
        MainActor.assumeIsolated {
            sneakPeekTask?.cancel()
            expandingViewTask?.cancel()
            eventSubscription?.cancel()
        }
    }

    // MARK: - Event Subscription

    private func subscribeToSneakPeekEvents() {
        eventSubscription = eventBus.subscribe(to: SneakPeekRequestedEvent.self) { [weak self] event in
            guard let self = self else { return }
            let request = event.request
            if request.style == .standard {
                self.toggleSneakPeek(
                    status: true,
                    type: request.type,
                    value: request.value
                )
            } else {
                self.toggleExpandingView(
                    status: true,
                    type: request.type,
                    value: request.value
                )
            }
        }
    }

    // MARK: - Sneak Peek Control

    func toggleSneakPeek(
        status: Bool,
        type: SneakContentType,
        duration: TimeInterval = 1.5,
        value: CGFloat = 0,
        icon: String = ""
    ) {
        sneakPeekDuration = duration == 1.5 ? settings.sneakPeakDuration : duration

        // Music always shows, other types require HUD replacement enabled
        if type != .music && !settings.hudReplacement {
            return
        }

        withAnimation(.smooth) {
            sneakPeek.show = status
            sneakPeek.type = type
            sneakPeek.value = value
            sneakPeek.icon = icon
        }

        // Track mic status changes
        if type == .mic {
            onMicStatusChange?(value == 1)
        }

        // Schedule auto-hide
        if status {
            scheduleSneakPeekHide(after: sneakPeekDuration)
        } else {
            sneakPeekTask?.cancel()
        }
    }

    private func scheduleSneakPeekHide(after duration: TimeInterval) {
        sneakPeekTask?.cancel()

        sneakPeekTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard let self = self, !Task.isCancelled else { return }
            withAnimation {
                self.sneakPeek.show = false
                self.sneakPeekDuration = self.settings.sneakPeakDuration
            }
        }
    }

    // MARK: - Expanding View Control

    func toggleExpandingView(
        status: Bool,
        type: SneakContentType,
        value: CGFloat = 0,
        browser: BrowserType = .chromium
    ) {
        withAnimation(.smooth) {
            expandingView.show = status
            expandingView.type = type
            expandingView.value = value
            expandingView.browser = browser
        }

        // Schedule auto-hide
        if status {
            scheduleExpandingViewHide(type: type)
        } else {
            expandingViewTask?.cancel()
        }
    }

    private func scheduleExpandingViewHide(type: SneakContentType) {
        expandingViewTask?.cancel()

        let duration: TimeInterval = (type == .download ? 2 : 3)
        expandingViewTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard let self = self, !Task.isCancelled else { return }
            self.toggleExpandingView(status: false, type: type)
        }
    }

    // MARK: - Notification Handling (Legacy)

    func handleSneakPeekEvent(_ notification: Notification) {
        let decoder = JSONDecoder()
        guard let data = notification.userInfo?.first?.value as? Data,
              let decoded = try? decoder.decode(SharedSneakPeek.self, from: data) else {
            return
        }

        let contentType: SneakContentType = {
            switch decoded.type {
            case "brightness": return .brightness
            case "volume": return .volume
            case "backlight": return .backlight
            case "mic": return .mic
            default: return .brightness
            }
        }()

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        let value = CGFloat((formatter.number(from: decoded.value) ?? 0.0).floatValue)

        toggleSneakPeek(
            status: decoded.show,
            type: contentType,
            value: value,
            icon: decoded.icon
        )
    }
}
