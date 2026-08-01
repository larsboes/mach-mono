import Foundation

public struct BatterySnapshot: Equatable, Sendable {
    public let level: Int
    public let isPluggedIn: Bool
    public let isCharging: Bool
    public let isInLowPowerMode: Bool
    public let timeToFullCharge: Int
    public let maxCapacity: Int
    public let statusText: String

    public init(
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

public enum BatteryAlertKind: String, Equatable, Sendable {
    case lowBattery = "Low Battery"
    case highBattery = "High Battery"
}

public struct BatteryAlertEvaluator: Sendable {
    public static func alert(
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
public protocol BatteryServiceProtocol: Observable {
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
