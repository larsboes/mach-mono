import Foundation

/// Versioned LAN export contract consumed by machSound and future apps.
/// Current schema shape is tracked in-code and via GitHub issue discussions.
public enum HealthExportSchema {
    public static let current = 1
}

public struct HealthExportPayload: Codable, Sendable, Equatable {
    public let schema: Int
    public let device: String
    public let sentAt: Date
    public let samples: [HealthSample]

    public init(schema: Int = HealthExportSchema.current,
                device: String,
                sentAt: Date = .now,
                samples: [HealthSample]) {
        self.schema = schema
        self.device = device
        self.sentAt = sentAt
        self.samples = samples
    }
}

public struct HealthSample: Codable, Sendable, Equatable, Identifiable {
    public let uuid: String
    public let type: HealthMetricType
    public let value: String
    public let unit: String
    public let start: Date
    public let end: Date
    public let source: String?
    public let meta: [String: String]

    public var id: String { uuid }

    public init(uuid: String,
                type: HealthMetricType,
                value: String,
                unit: String,
                start: Date,
                end: Date,
                source: String? = nil,
                meta: [String: String] = [:]) {
        self.uuid = uuid
        self.type = type
        self.value = value
        self.unit = unit
        self.start = start
        self.end = end
        self.source = source
        self.meta = meta
    }
}

public enum HealthMetricType: String, Codable, Sendable, CaseIterable {
    case heartRate
    case hrvSDNN
    case restingHeartRate
    case sleepStage
    case steps
    case activeEnergy
    case workout
    case mindfulMinutes
}
