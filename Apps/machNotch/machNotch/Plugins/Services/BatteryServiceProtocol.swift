import Foundation

struct BatterySnapshot: Equatable, Sendable {
    let level: Int
    let isPluggedIn: Bool
    let isCharging: Bool
    let isInLowPowerMode: Bool
    let timeToFullCharge: Int
    let maxCapacity: Int
    let statusText: String

    init(
        levelBattery: Float,
        isPluggedIn: Bool,
        isCharging: Bool,
        isInLowPowerMode: Bool,
        timeToFullCharge: Int,
        maxCapacity: Float,
        statusText: String
    ) {
        self.level = Int(levelBattery.rounded()).clamped(to: 0...100)
        self.isPluggedIn = isPluggedIn
        self.isCharging = isCharging
        self.isInLowPowerMode = isInLowPowerMode
        self.timeToFullCharge = max(timeToFullCharge, 0)
        self.maxCapacity = Int(maxCapacity.rounded()).clamped(to: 0...100)
        self.statusText = statusText
    }
}

enum BatteryAlertKind: String, Equatable, Sendable {
    case lowBattery = "Low Battery"
    case highBattery = "High Battery"
}

struct BatteryAlertEvaluator: Sendable {
    static func alert(
        for snapshot: BatterySnapshot,
        lowThreshold: Int,
        highThreshold: Int,
        initial: Bool
    ) -> BatteryAlertKind? {
        if shouldEmitLowBatteryAlert(snapshot: snapshot, threshold: lowThreshold, initial: initial) {
            return .lowBattery
        }

        if shouldEmitHighBatteryAlert(snapshot: snapshot, threshold: highThreshold, initial: initial) {
            return .highBattery
        }

        return nil
    }

    private static func shouldEmitLowBatteryAlert(
        snapshot: BatterySnapshot,
        threshold: Int,
        initial: Bool
    ) -> Bool {
        guard threshold > 0, !snapshot.isCharging else { return false }
        return snapshot.level == threshold || (initial && snapshot.level <= threshold)
    }

    private static func shouldEmitHighBatteryAlert(
        snapshot: BatterySnapshot,
        threshold: Int,
        initial: Bool
    ) -> Bool {
        guard threshold > 0, snapshot.isCharging else { return false }
        return snapshot.level == threshold || (initial && snapshot.level >= threshold)
    }
}

@MainActor
protocol BatteryServiceProtocol: Observable {
    var levelBattery: Float { get }
    var isPluggedIn: Bool { get }
    var isCharging: Bool { get }
    var isInLowPowerMode: Bool { get }
    var timeToFullCharge: Int { get }
    var maxCapacity: Float { get }
    var statusText: String { get }
    var snapshot: BatterySnapshot { get }

    func alertKind(initial: Bool) -> BatteryAlertKind?
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
