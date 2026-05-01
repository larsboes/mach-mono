//
//  WeatherServiceProtocol.swift
//  boringNotch
//
//  Created by Agent on 01/01/26.
//

import Foundation
import CoreLocation

/// Protocol defining the interface for weather data access.
/// Wraps the functionality of WeatherManager.
@MainActor
protocol WeatherServiceProtocol: Observable {
    /// The current weather data
    var currentWeather: WeatherData? { get }
    
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
    
    /// Manually triggers a weather fetch
    func fetchWeather()
}
