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
final class WeatherPlugin: NotchPlugin, PositionedPlugin {

    // MARK: - NotchPlugin

    let id = PluginID.weather

    let metadata = PluginMetadata(
        name: "Weather",
        description: "View current weather conditions",
        icon: "cloud.sun.fill",
        version: "1.0.0",
        author: "machNotch",
        category: .utilities
    )

    var isEnabled: Bool = true

    private(set) var state: PluginState = .inactive

    // MARK: - PositionedPlugin

    var closedNotchPosition: ClosedNotchPosition { .right }

    // MARK: - Dependencies

    var weatherService: (any WeatherServiceProtocol)?
    private var settings: PluginSettings?

    // MARK: - Initialization

    init() {}

    // MARK: - Lifecycle

    func activate(context: PluginContext) async throws {
        state = .activating

        self.weatherService = context.pluginExtensionServices.weather
        self.settings = context.settings

        // Always start updates — UI gating in NotchHomeView handles visibility
        self.weatherService?.startUpdatingWeather()

        state = .active
    }

    func deactivate() async {
        weatherService?.stopUpdatingWeather()
        weatherService = nil
        settings = nil
        state = .inactive
    }

    // MARK: - UI Slots

    var displayRequest: DisplayRequest? {
        guard isEnabled, state.isActive, weatherService?.currentWeather != nil else { return nil }
        return DisplayRequest(priority: .background, category: DisplayRequest.utility)
    }

    @ViewBuilder
    func closedNotchContent() -> some View {
        if isEnabled, state.isActive, let weather = weatherService?.currentWeather {
            WeatherClosedPill(weather: weather)
        }
    }

    @ViewBuilder
    func expandedPanelContent() -> some View {
        if isEnabled, state.isActive {
            WeatherView()
        }
    }

    @ViewBuilder
    func settingsContent() -> some View {
        WeatherSettings()
    }

    @ViewBuilder
    func menuBarView() -> some View {
        if isEnabled, state.isActive, let weather = weatherService?.currentWeather {
            WeatherMenuBarSummary(weather: weather)
        }
    }
}
