//
//  AxonPlugin.swift
//  NotchAxonPlugin
//
//  Built-in Axon Personal Operating System ambient surface plugin.
//  Bridges local loopback services to the MacBook notch.
//

import Combine
import Foundation
import NotchCore
import NotchPluginCore
import NotchServices
import NotchUI
import SwiftUI

@MainActor
@Observable
public final class AxonPlugin: NotchPlugin, PositionedPlugin {

    // MARK: - NotchPlugin Conformance

    public let id = PluginID.axon

    public let metadata = PluginMetadata(
        name: "Axon",
        description: "Ambient Horizon and Decision Triage for Axon OS",
        icon: "circle.hexagongrid.fill",
        version: "1.0.0",
        author: "Axon",
        category: .productivity
    )

    public var isEnabled: Bool = true
    public private(set) var state: PluginState = .inactive

    // MARK: - PositionedPlugin Conformance

    public var closedNotchPosition: ClosedNotchPosition { .right }

    // MARK: - Observable States

    public var isAxonOnline: Bool = false
    public var commitments: [AxonCommitment] = []
    public var upcomingCommitment: AxonCommitment?

    public var statusPort: Int = 8082 {
        didSet {
            client.statusPort = statusPort
            settings?.set("statusPort", value: statusPort)
        }
    }

    public var pollIntervalSeconds: Int = 15 {
        didSet {
            settings?.set("pollIntervalSeconds", value: pollIntervalSeconds)
            restartPolling()
        }
    }

    public var showInClosedNotch: Bool = true {
        didSet {
            settings?.set("showInClosedNotch", value: showInClosedNotch)
        }
    }

    public var enableSneakPeek: Bool = true {
        didSet {
            settings?.set("enableSneakPeek", value: enableSneakPeek)
        }
    }

    // MARK: - Internal Dependencies

    public let client = AxonClient()
    @ObservationIgnored var settings: PluginSettings?
    @ObservationIgnored var eventBus: PluginEventBus?
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored private var notifiedCommitmentIDs = Set<String>()

    // MARK: - Initialization

    public init() {}

    // MARK: - Lifecycle

    public func activate(context: PluginContext) async throws {
        state = .activating
        self.settings = context.settings
        self.eventBus = context.eventBus

        // Load persisted settings
        self.statusPort = settings?.get("statusPort", default: 8082) ?? 8082
        self.pollIntervalSeconds = settings?.get("pollIntervalSeconds", default: 15) ?? 15
        self.showInClosedNotch = settings?.get("showInClosedNotch", default: true) ?? true
        self.enableSneakPeek = settings?.get("enableSneakPeek", default: true) ?? true

        client.statusPort = self.statusPort

        // Initial fetch and start continuous polling
        await refreshData()
        restartPolling()

        state = .active
    }

    public func deactivate() async {
        pollTask?.cancel()
        pollTask = nil
        cancellables.removeAll()
        settings = nil
        eventBus = nil
        commitments = []
        upcomingCommitment = nil
        isAxonOnline = false
        state = .inactive
    }

    // MARK: - Polling & Synchronization

    private func restartPolling() {
        pollTask?.cancel()
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                let interval = UInt64(max(5, self.pollIntervalSeconds))
                try? await Task.sleep(nanoseconds: interval * 1_000_000_000)
                guard !Task.isCancelled else { break }
                await self.refreshData()
            }
        }
    }

    public func refreshData() async {
        // Check health
        let health = await client.fetchHealth()
        self.isAxonOnline = health?.isHealthy ?? false

        // Fetch calendar commitments
        let fetched = await client.fetchCommitments()
        self.commitments = fetched

        // Determine next upcoming commitment
        let now = Date()
        self.upcomingCommitment = fetched.first(where: { $0.end > now })

        // Check for imminent sneak peek trigger
        if enableSneakPeek, let upcoming = self.upcomingCommitment, upcoming.isImminent {
            if !notifiedCommitmentIDs.contains(upcoming.id) {
                notifiedCommitmentIDs.insert(upcoming.id)
                triggerImminentSneakPeek()
            }
        }
    }

    private func triggerImminentSneakPeek() {
        let request = SneakPeekRequest(style: .inline, type: .music, value: 1.0)
        let event = SneakPeekRequestedEvent(sourcePluginId: self.id, request: request)
        eventBus?.emit(event)
    }

    // MARK: - UI Slots Conformance

    public var displayRequest: DisplayRequest? {
        guard isEnabled, state.isActive, showInClosedNotch else { return nil }
        // If an event is imminent, boost display request priority
        if let upcoming = upcomingCommitment, upcoming.isImminent {
            return DisplayRequest(priority: .high, category: .utility)
        }
        return DisplayRequest(priority: .background, category: .utility)
    }

    @ViewBuilder
    public func closedNotchContent() -> some View {
        if isEnabled, state.isActive, showInClosedNotch {
            AxonClosedView(plugin: self)
        }
    }

    @ViewBuilder
    public func expandedPanelContent() -> some View {
        if isEnabled, state.isActive {
            AxonExpandedView(plugin: self)
        }
    }

    @ViewBuilder
    public func settingsContent() -> some View {
        AxonSettingsView(plugin: self)
    }
}
