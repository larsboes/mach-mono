import XCTest
@testable import NotchServices

final class BatteryServiceTests: XCTestCase {
    func testSnapshotClampsPercentageValues() {
        let snapshot = BatterySnapshot(
            levelBattery: 125.4,
            isPluggedIn: true,
            isCharging: false,
            isInLowPowerMode: false,
            timeToFullCharge: -10,
            maxCapacity: 101.8,
            statusText: "Full charge"
        )

        XCTAssertEqual(snapshot.level, 100)
        XCTAssertEqual(snapshot.maxCapacity, 100)
        XCTAssertEqual(snapshot.timeToFullCharge, 0)
    }

    func testInitialLowBatteryAlertTriggersBelowThreshold() {
        let snapshot = makeSnapshot(level: 12, isCharging: false)

        let alert = BatteryAlertEvaluator.alert(
            for: snapshot,
            lowThreshold: 20,
            highThreshold: 80,
            initial: true
        )

        XCTAssertEqual(alert, .lowBattery)
    }

    func testNonInitialLowBatteryAlertTriggersAtThresholdOnly() {
        let belowThreshold = makeSnapshot(level: 12, isCharging: false)
        let atThreshold = makeSnapshot(level: 20, isCharging: false)

        XCTAssertNil(BatteryAlertEvaluator.alert(
            for: belowThreshold,
            lowThreshold: 20,
            highThreshold: 80,
            initial: false
        ))
        XCTAssertEqual(BatteryAlertEvaluator.alert(
            for: atThreshold,
            lowThreshold: 20,
            highThreshold: 80,
            initial: false
        ), .lowBattery)
    }

    func testHighBatteryAlertRequiresCharging() {
        let unplugged = makeSnapshot(level: 90, isCharging: false)
        let charging = makeSnapshot(level: 90, isCharging: true)

        XCTAssertNil(BatteryAlertEvaluator.alert(
            for: unplugged,
            lowThreshold: 20,
            highThreshold: 80,
            initial: true
        ))
        XCTAssertEqual(BatteryAlertEvaluator.alert(
            for: charging,
            lowThreshold: 20,
            highThreshold: 80,
            initial: true
        ), .highBattery)
    }

    func testNonInitialHighBatteryAlertTriggersAtThresholdOnly() {
        let aboveThreshold = makeSnapshot(level: 95, isCharging: true)
        let atThreshold = makeSnapshot(level: 80, isCharging: true)

        XCTAssertNil(BatteryAlertEvaluator.alert(
            for: aboveThreshold,
            lowThreshold: 20,
            highThreshold: 80,
            initial: false
        ))
        XCTAssertEqual(BatteryAlertEvaluator.alert(
            for: atThreshold,
            lowThreshold: 20,
            highThreshold: 80,
            initial: false
        ), .highBattery)
    }

    func testDisabledThresholdsDoNotAlert() {
        let low = makeSnapshot(level: 5, isCharging: false)
        let high = makeSnapshot(level: 100, isCharging: true)

        XCTAssertNil(BatteryAlertEvaluator.alert(
            for: low,
            lowThreshold: 0,
            highThreshold: 0,
            initial: true
        ))
        XCTAssertNil(BatteryAlertEvaluator.alert(
            for: high,
            lowThreshold: 0,
            highThreshold: 0,
            initial: true
        ))
    }

    func testWeatherProviderResolverPrefersOpenWeatherMapInAutoMode() {
        XCTAssertEqual(
            WeatherProviderResolver.orderedSources(for: .auto, weatherKitAvailable: true),
            [.openWeatherMap, .weatherKit]
        )
        XCTAssertEqual(
            WeatherProviderResolver.orderedSources(for: .auto, weatherKitAvailable: false),
            [.openWeatherMap]
        )
    }

    func testWeatherProviderResolverHonorsExplicitProvider() {
        XCTAssertEqual(
            WeatherProviderResolver.orderedSources(for: .weatherKit, weatherKitAvailable: true),
            [.weatherKit]
        )
        XCTAssertEqual(
            WeatherProviderResolver.orderedSources(for: .weatherKit, weatherKitAvailable: false),
            []
        )
        XCTAssertEqual(
            WeatherProviderResolver.orderedSources(for: .openWeatherMap, weatherKitAvailable: true),
            [.openWeatherMap]
        )
    }

    func testWeatherDataFormatsOptionalMetrics() {
        let weather = WeatherData(
            temperature: 21.4,
            condition: "Cloudy",
            symbolName: "cloud.fill",
            humidity: 0.72,
            windSpeed: 8.6,
            feelsLike: 20.8,
            high: 24.2,
            low: 14.1,
            precipitationChance: 0.42,
            precipitationAmount: 1.25,
            uvIndex: 4,
            location: "Berlin",
            lastUpdated: Date(timeIntervalSince1970: 0),
            source: .weatherKit
        )

        XCTAssertEqual(weather.temperatureString, "21°")
        XCTAssertEqual(weather.feelsLikeString, "21°")
        XCTAssertEqual(weather.highLowString, "24° / 14°")
        XCTAssertEqual(weather.windSpeedString, "9 km/h")
        XCTAssertEqual(weather.precipitationChanceString, "42%")
        XCTAssertEqual(weather.precipitationAmountString, "1.2 mm")
    }

    private func makeSnapshot(level: Float, isCharging: Bool) -> BatterySnapshot {
        BatterySnapshot(
            levelBattery: level,
            isPluggedIn: isCharging,
            isCharging: isCharging,
            isInLowPowerMode: false,
            timeToFullCharge: 0,
            maxCapacity: 100,
            statusText: isCharging ? "Charging battery" : "Unplugged"
        )
    }
}
