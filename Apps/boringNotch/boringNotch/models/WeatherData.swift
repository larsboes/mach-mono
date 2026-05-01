//
//  WeatherData.swift
//  boringNotch
//
//  Created by Agent on 01/01/26.
//

import Foundation

struct WeatherData {
    let temperature: Double
    let condition: String
    let symbolName: String
    let humidity: Double
    let windSpeed: Double
    let feelsLike: Double
    let high: Double
    let low: Double
    let location: String
    let lastUpdated: Date
    
    var temperatureString: String {
        return String(format: "%.0f°", temperature)
    }
    
    var systemIconName: String {
        return symbolName
    }
    
    var humidityInt: Int {
        return Int(humidity * 100)
    }
}
