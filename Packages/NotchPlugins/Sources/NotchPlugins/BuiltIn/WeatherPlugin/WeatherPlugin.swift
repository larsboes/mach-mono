//
//  WeatherPlugin.swift
//  machNotch
//
//  Built-in weather plugin.
//  Wraps WeatherService to provide weather updates.
//

import SwiftUI

@MainActor
@Observable
public final class WeatherPlugin: NotchPlugin, PositionedPlugin {

    // MARK: - NotchPlugin

    public let id = PluginID.weather

    public let metadata = PluginMetadata(
        name: "Weather",
        description: "View current weather conditions",
        icon: "cloud.sun.fill",
        version: "1.0.0",
        author: "machNotch",
        category: .utilities
    )

    public var isEnabled: Bool = true

    public private(set) var state: PluginState = .inactive

    // MARK: - PositionedPlugin

    public var closedNotchPosition: ClosedNotchPosition { .right }

    // MARK: - Dependencies

    public var weatherService: (any WeatherServiceProtocol)?
    private var settings: PluginSettings?

    // MARK: - Initialization

    public init() {}

    // MARK: - Lifecycle

    public func activate(context: PluginContext) async throws {
        state = .activating

        self.weatherService = context.pluginExtensionServices.weather
        self.settings = context.settings

        // Always start updates — UI gating in NotchHomeView handles visibility
        self.weatherService?.startUpdatingWeather()

        state = .active
    }

    public func deactivate() async {
        weatherService?.stopUpdatingWeather()
        weatherService = nil
        settings = nil
        state = .inactive
    }

    // MARK: - UI Slots

    public var displayRequest: DisplayRequest? {
        guard isEnabled, state.isActive, weatherService?.currentWeather != nil else { return nil }
        return DisplayRequest(priority: .background, category: DisplayRequest.utility)
    }

    @ViewBuilder
    public func closedNotchContent() -> some View {
        if isEnabled, state.isActive, let weather = weatherService?.currentWeather {
            WeatherClosedPill(weather: weather)
        }
    }

    @ViewBuilder
    public func expandedPanelContent() -> some View {
        if isEnabled, state.isActive {
            WeatherView()
        }
    }

    @ViewBuilder
    public func settingsContent() -> some View {
        WeatherSettings()
    }

    @ViewBuilder
    public func menuBarView() -> some View {
        if isEnabled, state.isActive, let weather = weatherService?.currentWeather {
            WeatherMenuBarSummary(weather: weather)
        }
    }
}
