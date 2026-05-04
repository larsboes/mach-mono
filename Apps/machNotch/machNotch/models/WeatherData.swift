//
//  WeatherData.swift
//  machNotch
//
//  Created by Agent on 01/01/26.
//

import Foundation

enum WeatherDataSource: String, Sendable, Equatable {
    case weatherKit = "WeatherKit"
    case openWeatherMap = "OpenWeatherMap"
}

struct WeatherData: Sendable, Equatable {
    let temperature: Double
    let condition: String
    let symbolName: String
    let humidity: Double
    let windSpeed: Double
    let feelsLike: Double
    let high: Double
    let low: Double
    let precipitationChance: Double?
    let precipitationAmount: Double?
    let uvIndex: Int?
    let location: String
    let lastUpdated: Date
    let source: WeatherDataSource
    
    var temperatureString: String {
        return String(format: "%.0f°", temperature)
    }
    
    var systemIconName: String {
        return symbolName
    }
    
    var humidityInt: Int {
        return Int(humidity * 100)
    }

    var feelsLikeString: String {
        String(format: "%.0f°", feelsLike)
    }

    var highLowString: String {
        "\(String(format: "%.0f°", high)) / \(String(format: "%.0f°", low))"
    }

    var windSpeedString: String {
        String(format: "%.0f km/h", windSpeed)
    }

    var precipitationChanceString: String? {
        guard let precipitationChance else { return nil }
        return "\(Int((precipitationChance * 100).rounded()))%"
    }

    var precipitationAmountString: String? {
        guard let precipitationAmount else { return nil }
        return String(format: "%.1f mm", precipitationAmount)
    }
}
