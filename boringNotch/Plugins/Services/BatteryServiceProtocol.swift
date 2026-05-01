import Foundation

@MainActor
protocol BatteryServiceProtocol: Observable {
    var levelBattery: Float { get }
    var isPluggedIn: Bool { get }
    var isCharging: Bool { get }
    var isInLowPowerMode: Bool { get }
    var timeToFullCharge: Int { get }
    var maxCapacity: Float { get }
    var statusText: String { get }
}
