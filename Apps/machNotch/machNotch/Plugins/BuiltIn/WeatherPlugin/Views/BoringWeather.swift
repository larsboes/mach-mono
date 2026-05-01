//
//  BoringWeather.swift
//  boringNotch
//
//  Created by Arsh Anwar on 26/12/25.
//

import SwiftUI

struct WeatherView: View {
    @Environment(BoringViewModel.self) var vm
    @Environment(\.pluginManager) var pluginManager
    @Environment(\.settings) var settings
    
    var body: some View {
        VStack(spacing: 8) {
            if let weatherService = pluginManager?.services.weather {
                if weatherService.isLoading {
                    loadingView
                } else if let error = weatherService.errorMessage {
                    errorView(message: error)
                } else if let weather = weatherService.currentWeather {
                    weatherContent(weather: weather)
                } else {
                    emptyStateView
                }
            } else {
                emptyStateView
            }
        }
        .frame(height: 120)
        .onAppear {
            pluginManager?.services.weather.checkLocationAuthorization()
        }
        .onChange(of: vm.notchState) { _, _ in
            if vm.notchState == .open {
                pluginManager?.services.weather.fetchWeather()
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
                .tint(.white)
            Text("Loading weather...")
                .font(.caption)
                .foregroundColor(Color(white: 0.65))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
                .foregroundColor(Color(white: 0.65))
                .multilineTextAlignment(.center)
            
            if pluginManager?.services.weather.locationAuthorizationStatus == .denied {
                Button("Open Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.effectiveAccent(from: settings))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "cloud.fill")
                .font(.title)
                .foregroundColor(Color(white: 0.65))
            Text("No weather data")
                .font(.subheadline)
                .foregroundColor(.white)
            Text("Enable location access")
                .font(.caption)
                .foregroundColor(Color(white: 0.65))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func weatherContent(weather: WeatherData) -> some View {
        VStack(spacing: 6) {
            // Location and main weather
            HStack(alignment: .center, spacing: 8) {
                // Weather icon
                Image(systemName: weather.systemIconName)
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                
                VStack(alignment: .leading, spacing: 1) {
                    // Location
                    Text(weather.location)
                        .font(.caption2)
                        .foregroundColor(Color(white: 0.65))
                        .lineLimit(1)
                    
                    // Temperature
                    Text(weather.temperatureString)
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(.white)
                }
                
                Spacer(minLength: 0)
                
                // Condition on the right
                VStack(alignment: .trailing, spacing: 1) {
                    Text(weather.condition)
                        .font(.caption2)
                        .foregroundColor(Color(white: 0.65))
                        .lineLimit(1)
                    
                    Text("Feels \(String(format: "%.0f°", weather.feelsLike))")
                        .font(.caption2)
                        .foregroundColor(Color(white: 0.5))
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            
            Divider()
                .background(Color(white: 0.3))
                .padding(.horizontal, 10)
            
            // Weather details
            HStack(spacing: 10) {
                WeatherDetailItem(
                    icon: "humidity.fill",
                    label: "Humidity",
                    value: "\(weather.humidityInt)%"
                )
                
                Divider()
                    .background(Color(white: 0.3))
                    .frame(height: 16)
                
                WeatherDetailItem(
                    icon: "wind",
                    label: "Wind",
                    value: String(format: "%.0f km/h", weather.windSpeed)
                )
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
    }
}

struct WeatherDetailItem: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(Color(white: 0.65))
            
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 11))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(Color(white: 0.5))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    WeatherView()
        .frame(width: 215, height: 130)
        .background(.black)
        .environment(BoringViewModel())
}
