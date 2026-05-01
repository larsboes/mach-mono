//
//  WeatherService.swift
//  boringNotch
//
//  Created by Agent on 01/01/26.
//

import Foundation
import CoreLocation

/// Concrete implementation of WeatherServiceProtocol.
/// Wraps the legacy WeatherManager to provide a modern, testable interface.
@MainActor
@Observable
final class WeatherService: NSObject, WeatherServiceProtocol, CLLocationManagerDelegate {
    // MARK: - Properties
    
    var currentWeather: WeatherData?
    var isLoading: Bool = false
    var errorMessage: String?
    var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    
    private let locationManager = CLLocationManager()
    private var updateTask: Task<Void, Never>?
    private var isRequestingLocation = false
    
    // MARK: - Initialization
    
    private let weatherService: OpenWeatherMapService
    
    init(settings: any WidgetSettings) {
        self.weatherService = OpenWeatherMapService(settings: settings)
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    nonisolated deinit {
        MainActor.assumeIsolated {
            updateTask?.cancel()
        }
    }
    
    // MARK: - Methods
    
    func checkLocationAuthorization() {
        locationManager.requestWhenInUseAuthorization()
        locationAuthorizationStatus = locationManager.authorizationStatus
        
        switch locationAuthorizationStatus {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
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
            
            if locationAuthorizationStatus == .authorizedAlways {
                startUpdatingWeather()
            }
        }
    }
    
    func startUpdatingWeather() {
        fetchWeather()
        
        // Update weather every 30 minutes
        updateTask?.cancel()
        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1800 * 1_000_000_000) // 30 minutes
                if Task.isCancelled { break }
                self?.fetchWeather()
            }
        }
    }
    
    func stopUpdatingWeather() {
        updateTask?.cancel()
        updateTask = nil
    }
    
    func fetchWeather() {
        guard locationAuthorizationStatus == .authorizedAlways else {
            return
        }
        
        // Prevent multiple simultaneous location requests
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
                // Fetch weather using OpenWeatherMap (for local testing without Apple Developer Account)
                let weatherData = try await self.weatherService.fetchWeather(for: location)
                
                self.currentWeather = weatherData
                self.errorMessage = nil
                self.isLoading = false
                
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                
                // Silence the log for missing API key
                let nsError = error as NSError
                if !(nsError.domain == "OpenWeatherMap" && nsError.code == 401) {
                    print("Weather fetch error: \(error)")
                }
            }
        }
    }
}

// MARK: - OpenWeatherMap Service

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
class OpenWeatherMapService {
    private let settings: any WidgetSettings

    init(settings: any WidgetSettings) {
        self.settings = settings
    }
    
    func fetchWeather(for location: CLLocation) async throws -> WeatherData {
        let apiKey = settings.openWeatherMapApiKey
        guard !apiKey.isEmpty else {
            throw NSError(domain: "OpenWeatherMap", code: 401, userInfo: [NSLocalizedDescriptionKey: "Please add your OpenWeatherMap API key in Settings > Weather"])
        }

        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(location.coordinate.latitude)&lon=\(location.coordinate.longitude)&appid=\(apiKey)&units=metric"

        guard let url = URL(string: urlString) else {
            throw NSError(domain: "OpenWeatherMap", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "OpenWeatherMap", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch weather data"])
        }

        guard httpResponse.statusCode == 200 else {
            // Try to extract API error message
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
            throw NSError(domain: "OpenWeatherMap", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
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
            location: decoded.name,
            lastUpdated: Date(timeIntervalSince1970: decoded.dt)
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
