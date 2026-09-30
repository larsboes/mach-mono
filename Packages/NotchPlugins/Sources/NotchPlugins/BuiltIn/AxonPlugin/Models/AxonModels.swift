//
//  AxonModels.swift
//  NotchAxonPlugin
//
//  Data models for Axon capability services consumed over loopback HTTP.
//

import Foundation

public struct AxonHealthStatus: Codable, Sendable {
    public let status: String
    public let version: String?
    public let capabilities: [String]?
    public let uptimeSeconds: Double?

    public var isHealthy: Bool {
        status.lowercased() == "ok" || status.lowercased() == "healthy"
    }

    public init(status: String = "ok", version: String? = nil, capabilities: [String]? = nil, uptimeSeconds: Double? = nil) {
        self.status = status
        self.version = version
        self.capabilities = capabilities
        self.uptimeSeconds = uptimeSeconds
    }
}

public struct AxonCommitment: Codable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let location: String?
    public let isAllDay: Bool
    public let category: String?

    public init(
        id: String = UUID().uuidString,
        title: String,
        start: Date,
        end: Date,
        location: String? = nil,
        isAllDay: Bool = false,
        category: String? = nil
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.location = location
        self.isAllDay = isAllDay
        self.category = category
    }

    public var minutesUntilStart: Int {
        let diff = start.timeIntervalSince(Date())
        return max(0, Int(diff / 60))
    }

    public var isImminent: Bool {
        let diff = start.timeIntervalSince(Date())
        return diff > 0 && diff <= 1800 // Within 30 minutes
    }

    public var isNow: Bool {
        let now = Date()
        return start <= now && end >= now
    }

    public var relativeTimeText: String {
        if isNow {
            return "Now"
        }
        let mins = minutesUntilStart
        if mins < 60 {
            return "in \(mins)m"
        } else if mins < 1440 {
            let hours = mins / 60
            let remainderMins = mins % 60
            return remainderMins > 0 ? "in \(hours)h \(remainderMins)m" : "in \(hours)h"
        } else {
            let days = mins / 1440
            return "in \(days)d"
        }
    }
}

public struct AxonTriageItem: Codable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let source: String
    public let timestamp: Date

    public init(id: String = UUID().uuidString, title: String, detail: String, source: String, timestamp: Date = Date()) {
        self.id = id
        self.title = title
        self.detail = detail
        self.source = source
        self.timestamp = timestamp
    }
}

public struct AxonTransitAlert: Codable, Identifiable, Sendable {
    public let id: String
    public let line: String
    public let destination: String
    public let plannedDeparture: Date
    public let delayMinutes: Int

    public var isDelayed: Bool {
        delayMinutes > 0
    }

    public init(id: String = UUID().uuidString, line: String, destination: String, plannedDeparture: Date, delayMinutes: Int = 0) {
        self.id = id
        self.line = line
        self.destination = destination
        self.plannedDeparture = plannedDeparture
        self.delayMinutes = delayMinutes
    }
}
