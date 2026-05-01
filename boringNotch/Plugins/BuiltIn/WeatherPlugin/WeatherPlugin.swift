//
//  WeatherPlugin.swift
//  boringNotch
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
        author: "boringNotch",
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

        self.weatherService = context.services.weather
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

    @ViewBuilder
    func closedNotchContent() -> some View {
        if isEnabled, state.isActive, let weather = weatherService?.currentWeather {
            HStack(spacing: 4) {
                Image(systemName: weather.systemIconName)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.8))
                Text(weather.temperatureString)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
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
}
