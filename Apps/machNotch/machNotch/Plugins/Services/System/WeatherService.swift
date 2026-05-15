//
//  WeatherService.swift
//  machNotch
//
//  Created by Agent on 01/01/26.
//

import CoreLocation
import Foundation

#if canImport(WeatherKit)
    import WeatherKit
#endif

/// Concrete implementation of WeatherServiceProtocol.
/// Fetches through a provider boundary so native WeatherKit and OpenWeatherMap can coexist.
@MainActor
@Observable
final class WeatherService: NSObject, WeatherServiceProtocol, CLLocationManagerDelegate {
    // MARK: - Properties

    var currentWeather: WeatherData?
    var activeSource: WeatherDataSource?
    var isLoading: Bool = false
    var errorMessage: String?
    var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined

    private let locationManager = CLLocationManager()
    private var updateTask: Task<Void, Never>?
    private var isRequestingLocation = false
    private var lastFetchDate: Date?
    private let cacheDuration: TimeInterval = 30 * 60

    private let settings: any WidgetSettings
    private let openWeatherMapProvider: OpenWeatherMapWeatherProvider

    #if canImport(WeatherKit)
        private let weatherKitProvider: WeatherKitWeatherProvider?
    #endif

    init(settings: any WidgetSettings) {
        self.settings = settings
        self.openWeatherMapProvider = OpenWeatherMapWeatherProvider(settings: settings)
        #if canImport(WeatherKit)
            self.weatherKitProvider = WeatherKitWeatherProvider()
        #endif
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationAuthorizationStatus = locationManager.authorizationStatus
    }

    nonisolated deinit {
        MainActor.assumeIsolated {
            updateTask?.cancel()
        }
    }

    // MARK: - Methods

    func checkLocationAuthorization() {
        locationAuthorizationStatus = locationManager.authorizationStatus

        switch locationAuthorizationStatus {
        case .notDetermined:
            #if os(macOS)
                locationManager.requestAlwaysAuthorization()
            #else
                locationManager.requestWhenInUseAuthorization()
            #endif
        case _ where locationAuthorizationStatus.grantsWeatherLocationAccess:
            startUpdatingWeather()
        case .authorizedAlways:
            startUpdatingWeather()
        case .denied, .restricted:
            errorMessage = "Location access denied"
        @unknown default:
            break
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            locationAuthorizationStatus = manager.authorizationStatus

            if locationAuthorizationStatus.grantsWeatherLocationAccess {
                startUpdatingWeather()
            }
        }
    }

    func startUpdatingWeather() {
        fetchWeather()

        // Update weather every 30 minutes.
        updateTask?.cancel()
        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1800 * 1_000_000_000)
                if Task.isCancelled { break }
                self?.refreshWeather()
            }
        }
    }

    func stopUpdatingWeather() {
        updateTask?.cancel()
        updateTask = nil
    }

    func fetchWeather() {
        fetchWeather(forceRefresh: false)
    }

    func refreshWeather() {
        fetchWeather(forceRefresh: true)
    }

    private func fetchWeather(forceRefresh: Bool) {
        guard locationAuthorizationStatus.grantsWeatherLocationAccess else {
            return
        }

        if !forceRefresh, isCachedWeatherFresh {
            return
        }

        guard !isRequestingLocation else {
            return
        }

        isRequestingLocation = true
        locationManager.requestLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        Task { @MainActor in
            isRequestingLocation = false
            fetchWeatherData(for: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            isRequestingLocation = false
            errorMessage = "Failed to get location: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func fetchWeatherData(for location: CLLocation) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let weatherData = try await fetchWithConfiguredProviders(for: location)
                currentWeather = weatherData
                activeSource = weatherData.source
                lastFetchDate = Date()
                errorMessage = nil
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false

                let nsError = error as NSError
                if !(nsError.domain == "OpenWeatherMap" && nsError.code == 401) {
                    print("Weather fetch error: \(error)")
                }
            }
        }
    }

    private var isCachedWeatherFresh: Bool {
        guard currentWeather != nil, let lastFetchDate else { return false }
        return Date().timeIntervalSince(lastFetchDate) < cacheDuration
    }

    private func fetchWithConfiguredProviders(for location: CLLocation) async throws -> WeatherData {
        let providers = providers(for: settings.weatherSource)
        guard !providers.isEmpty else {
            throw WeatherProviderError.weatherKitUnavailable
        }

        var lastError: Error?
        for provider in providers {
            do {
                return try await provider.fetchWeather(for: location)
            } catch {
                lastError = error
                if settings.weatherSource != .auto {
                    break
                }
            }
        }

        throw lastError ?? WeatherProviderError.noProviderConfigured
    }

    private func providers(for preference: WeatherSource) -> [any WeatherProvider] {
        WeatherProviderResolver
            .orderedSources(for: preference, weatherKitAvailable: isWeatherKitAvailable)
            .compactMap(provider(for:))
    }

    private var isWeatherKitAvailable: Bool {
        return false
    }

    private func provider(for source: WeatherDataSource) -> (any WeatherProvider)? {
        switch source {
        case .openWeatherMap:
            return openWeatherMapProvider
        case .weatherKit:
            #if canImport(WeatherKit)
                return weatherKitProvider
            #else
                return nil
            #endif
        }
    }
}

#if canImport(WeatherKit)
    @MainActor
    private struct WeatherKitWeatherProvider: WeatherProvider {
        let source: WeatherDataSource = .weatherKit

        func fetchWeather(for location: CLLocation) async throws -> WeatherData {
            let weather = try await WeatherKit.WeatherService.shared.weather(for: location)
            let current = weather.currentWeather
            let daily = weather.dailyForecast.forecast.first

            return WeatherData(
                temperature: current.temperature.converted(to: .celsius).value,
                condition: String(describing: current.condition).capitalized,
                symbolName: current.symbolName,
                humidity: current.humidity,
                windSpeed: current.wind.speed.converted(to: .kilometersPerHour).value,
                feelsLike: current.apparentTemperature.converted(to: .celsius).value,
                high: daily?.highTemperature.converted(to: .celsius).value
                    ?? current.temperature.converted(to: .celsius).value,
                low: daily?.lowTemperature.converted(to: .celsius).value
                    ?? current.temperature.converted(to: .celsius).value,
                precipitationChance: daily?.precipitationChance,
                precipitationAmount: daily?.precipitationAmountByType.precipitation.converted(to: .millimeters).value,
                uvIndex: current.uvIndex.value,
                location: "Current Location",
                lastUpdated: current.date,
                source: source
            )
        }
    }
#endif
