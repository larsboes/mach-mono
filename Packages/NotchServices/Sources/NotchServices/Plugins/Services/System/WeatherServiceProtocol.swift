//
//  WeatherServiceProtocol.swift
//  machNotch
//
//  Created by Agent on 01/01/26.
//

import CoreLocation
import Foundation

/// Protocol defining the interface for weather data access.
/// Wraps the functionality of WeatherManager.
@MainActor
public protocol WeatherServiceProtocol: Observable {
    /// The current weather data
    var currentWeather: WeatherData? { get }

    /// Data source used for the latest successful fetch
    var activeSource: WeatherDataSource? { get }

    /// Whether data is currently being fetched
    var isLoading: Bool { get }

    /// Any error message from the last fetch attempt
    var errorMessage: String? { get }

    /// Current location authorization status
    var locationAuthorizationStatus: CLAuthorizationStatus { get }

    /// Checks and requests location authorization
    func checkLocationAuthorization()

    /// Starts periodic weather updates
    func startUpdatingWeather()

    /// Stops periodic weather updates
    func stopUpdatingWeather()

    /// Returns cached weather when fresh; otherwise triggers a weather fetch.
    func fetchWeather()

    /// Forces a provider fetch, bypassing the in-memory freshness window.
    func refreshWeather()
}

@MainActor
public protocol WeatherProvider {
    var source: WeatherDataSource { get }
    func fetchWeather(for location: CLLocation) async throws -> WeatherData
}

public enum WeatherProviderResolver {
    public static func orderedSources(for preference: WeatherSource, weatherKitAvailable: Bool) -> [WeatherDataSource] {
        switch preference {
        case .auto:
            return weatherKitAvailable ? [.openWeatherMap, .weatherKit] : [.openWeatherMap]
        case .weatherKit:
            return weatherKitAvailable ? [.weatherKit] : []
        case .openWeatherMap:
            return [.openWeatherMap]
        }
    }
}

enum WeatherProviderError: LocalizedError {
    case noProviderConfigured
    case weatherKitUnavailable

    var errorDescription: String? {
        switch self {
        case .noProviderConfigured:
            return "No weather provider is configured"
        case .weatherKitUnavailable:
            return "WeatherKit is not available in this build"
        }
    }
}

extension CLAuthorizationStatus {
    var grantsWeatherLocationAccess: Bool {
        #if os(macOS)
            return self == .authorizedAlways
        #else
            return self == .authorizedWhenInUse || self == .authorizedAlways
        #endif
    }
}

// MARK: - OpenWeatherMap Provider

private struct OpenWeatherErrorResponse: Codable {
    let cod: Int?
    let message: String?
}

private struct OpenWeatherResponse: Codable {
    let weather: [OpenWeatherCondition]
    let main: OpenWeatherMain
    let wind: OpenWeatherWind
    let name: String
    let dt: TimeInterval
}

private struct OpenWeatherCondition: Codable {
    let id: Int
    let main: String
    let description: String
    let icon: String
}

private struct OpenWeatherMain: Codable {
    let temp: Double
    let feels_like: Double
    let temp_min: Double
    let temp_max: Double
    let humidity: Double
}

private struct OpenWeatherWind: Codable {
    let speed: Double
}

@MainActor
final class OpenWeatherMapWeatherProvider: WeatherProvider {
    let source: WeatherDataSource = .openWeatherMap
    private let settings: any WidgetSettings

    init(settings: any WidgetSettings) {
        self.settings = settings
    }

    func fetchWeather(for location: CLLocation) async throws -> WeatherData {
        let apiKey = settings.openWeatherMapApiKey
        guard !apiKey.isEmpty else {
            throw NSError(
                domain: "OpenWeatherMap", code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Please add your OpenWeatherMap API key in Settings > Weather"])
        }

        let urlString =
            "https://api.openweathermap.org/data/2.5/weather?lat=\(location.coordinate.latitude)&lon=\(location.coordinate.longitude)&appid=\(apiKey)&units=metric"

        guard let url = URL(string: urlString) else {
            throw NSError(domain: "OpenWeatherMap", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "OpenWeatherMap", code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Failed to fetch weather data"])
        }

        guard httpResponse.statusCode == 200 else {
            let apiMessage = (try? JSONDecoder().decode(OpenWeatherErrorResponse.self, from: data))?.message
            let message: String
            switch httpResponse.statusCode {
            case 401:
                message = apiMessage ?? "Invalid API key — check Settings > Weather"
            case 429:
                message = "API rate limit exceeded — try again later"
            default:
                message = apiMessage ?? "Weather API error (\(httpResponse.statusCode))"
            }
            throw NSError(
                domain: "OpenWeatherMap", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }

        let decoded = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)

        return WeatherData(
            temperature: decoded.main.temp,
            condition: decoded.weather.first?.main ?? "Unknown",
            symbolName: mapIconToSFSymbol(icon: decoded.weather.first?.icon ?? ""),
            humidity: decoded.main.humidity / 100.0,
            windSpeed: decoded.wind.speed * 3.6,
            feelsLike: decoded.main.feels_like,
            high: decoded.main.temp_max,
            low: decoded.main.temp_min,
            precipitationChance: nil,
            precipitationAmount: nil,
            uvIndex: nil,
            location: decoded.name,
            lastUpdated: Date(timeIntervalSince1970: decoded.dt),
            source: source
        )
    }

    private func mapIconToSFSymbol(icon: String) -> String {
        switch icon {
        case "01d": return "sun.max.fill"
        case "01n": return "moon.stars.fill"
        case "02d": return "cloud.sun.fill"
        case "02n": return "cloud.moon.fill"
        case "03d", "03n": return "cloud.fill"
        case "04d", "04n": return "smoke.fill"
        case "09d", "09n": return "cloud.drizzle.fill"
        case "10d": return "cloud.sun.rain.fill"
        case "10n": return "cloud.moon.rain.fill"
        case "11d", "11n": return "cloud.bolt.fill"
        case "13d", "13n": return "snowflake"
        case "50d", "50n": return "cloud.fog.fill"
        default: return "cloud.fill"
        }
    }
}
