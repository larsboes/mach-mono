//
//  SystemStatsServiceProtocol.swift
//  machNotch
//

import Foundation

public struct SystemStats: Sendable {
    public let cpuUsage: Double
    public let ramUsage: Double
    public let diskUsage: Double
}

public protocol SystemStatsServiceProtocol: Sendable {
    var stats: SystemStats { get async }
}
