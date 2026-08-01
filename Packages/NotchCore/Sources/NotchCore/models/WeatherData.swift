import Foundation

public enum WeatherDataSource: String, Sendable, Equatable {
    case weatherKit = "WeatherKit"
    case openWeatherMap = "OpenWeatherMap"
}

public struct WeatherData: Sendable, Equatable {
    public let temperature: Double
    public let condition: String
    public let symbolName: String
    public let humidity: Double
    public let windSpeed: Double
    public let feelsLike: Double
    public let high: Double
    public let low: Double
    public let precipitationChance: Double?
    public let precipitationAmount: Double?
    public let uvIndex: Int?
    public let location: String
    public let lastUpdated: Date
    public let source: WeatherDataSource

    public init(
        temperature: Double,
        condition: String,
        symbolName: String,
        humidity: Double,
        windSpeed: Double,
        feelsLike: Double,
        high: Double,
        low: Double,
        precipitationChance: Double? = nil,
        precipitationAmount: Double? = nil,
        uvIndex: Int? = nil,
        location: String,
        lastUpdated: Date,
        source: WeatherDataSource
    ) {
        self.temperature = temperature
        self.condition = condition
        self.symbolName = symbolName
        self.humidity = humidity
        self.windSpeed = windSpeed
        self.feelsLike = feelsLike
        self.high = high
        self.low = low
        self.precipitationChance = precipitationChance
        self.precipitationAmount = precipitationAmount
        self.uvIndex = uvIndex
        self.location = location
        self.lastUpdated = lastUpdated
        self.source = source
    }

    public var temperatureString: String {
        return String(format: "%.0f°", temperature)
    }

    public var systemIconName: String {
        return symbolName
    }

    public var humidityInt: Int {
        return Int(humidity * 100)
    }

    public var feelsLikeString: String {
        String(format: "%.0f°", feelsLike)
    }

    public var highLowString: String {
        "\(String(format: "%.0f°", high)) / \(String(format: "%.0f°", low))"
    }

    public var windSpeedString: String {
        String(format: "%.0f km/h", windSpeed)
    }

    public var precipitationChanceString: String? {
        guard let precipitationChance else { return nil }
        return "\(Int((precipitationChance * 100).rounded()))%"
    }

    public var precipitationAmountString: String? {
        guard let precipitationAmount else { return nil }
        return String(format: "%.1f mm", precipitationAmount)
    }
}
