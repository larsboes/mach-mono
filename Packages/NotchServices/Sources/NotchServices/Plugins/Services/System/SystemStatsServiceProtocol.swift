//
//  SystemStatsServiceProtocol.swift
//  machNotch
//

import Darwin
import Foundation
import Observation

public struct SystemStats: Equatable, Sendable {
    public let cpuUsage: Double
    public let cpuUserPercent: Double
    public let cpuSystemPercent: Double
    /// Busiest accelerator, 0...1. Stays 0 on hardware that publishes no reading.
    public let gpuUsage: Double
    public let ramUsage: Double
    public let ramUsedBytes: Double
    public let ramTotalBytes: Double
    public let diskUsage: Double
    public let diskUsedBytes: Double
    public let diskTotalBytes: Double
    public let networkDownBytesPerSecond: Double
    public let networkUpBytesPerSecond: Double

    public static let zero = SystemStats(
        cpuUsage: 0, cpuUserPercent: 0, cpuSystemPercent: 0, gpuUsage: 0,
        ramUsage: 0, ramUsedBytes: 0, ramTotalBytes: 0,
        diskUsage: 0, diskUsedBytes: 0, diskTotalBytes: 0,
        networkDownBytesPerSecond: 0, networkUpBytesPerSecond: 0
    )

    public init(
        cpuUsage: Double,
        cpuUserPercent: Double,
        cpuSystemPercent: Double,
        gpuUsage: Double = 0,
        ramUsage: Double,
        ramUsedBytes: Double,
        ramTotalBytes: Double,
        diskUsage: Double,
        diskUsedBytes: Double,
        diskTotalBytes: Double,
        networkDownBytesPerSecond: Double,
        networkUpBytesPerSecond: Double
    ) {
        self.cpuUsage = cpuUsage
        self.cpuUserPercent = cpuUserPercent
        self.cpuSystemPercent = cpuSystemPercent
        self.gpuUsage = gpuUsage
        self.ramUsage = ramUsage
        self.ramUsedBytes = ramUsedBytes
        self.ramTotalBytes = ramTotalBytes
        self.diskUsage = diskUsage
        self.diskUsedBytes = diskUsedBytes
        self.diskTotalBytes = diskTotalBytes
        self.networkDownBytesPerSecond = networkDownBytesPerSecond
        self.networkUpBytesPerSecond = networkUpBytesPerSecond
    }
}

@MainActor
public protocol SystemStatsServiceProtocol: Observable {
    var stats: SystemStats { get }
    var history: [SystemStats] { get }
    var refreshInterval: TimeInterval { get set }

    func startMonitoring()
    func stopMonitoring()
    func refresh()
}

@MainActor
@Observable
public final class SystemStatsService: SystemStatsServiceProtocol {
    private static let historyLimit = 120

    public var stats: SystemStats = .zero
    public private(set) var history: [SystemStats] = []

    public var refreshInterval: TimeInterval {
        get { storedRefreshInterval }
        set {
            let clamped = min(max(newValue, 1), 5)
            guard clamped != storedRefreshInterval else { return }
            storedRefreshInterval = clamped
            if isMonitoring {
                restartMonitoring()
            }
        }
    }

    private var pollingTask: Task<Void, Never>?
    private var sampler = SystemStatsSampler()
    private var storedRefreshInterval: TimeInterval

    private var isMonitoring: Bool {
        pollingTask != nil
    }

    public init(refreshInterval: TimeInterval = 3) {
        self.storedRefreshInterval = min(max(refreshInterval, 1), 5)
        refresh()
    }

    public func startMonitoring() {
        guard pollingTask == nil else { return }
        refresh()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                try? await Task.sleep(for: .seconds(self.refreshInterval))
                guard !Task.isCancelled else { return }
                self.refresh()
            }
        }
    }

    public func stopMonitoring() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    public func refresh() {
        // A nil read means the source had no answer this tick, so the previous
        // value is kept rather than rendering a metric as zero.
        let cpu = sampler.sampleCPU()
        let gpu = sampler.sampleGPU()
        let ram = sampler.sampleRAM()
        let disk = sampler.sampleDisk()
        let net = sampler.sampleNetwork()

        let latest = SystemStats(
            cpuUsage: cpu?.total ?? stats.cpuUsage,
            cpuUserPercent: cpu?.user ?? stats.cpuUserPercent,
            cpuSystemPercent: cpu?.system ?? stats.cpuSystemPercent,
            gpuUsage: gpu ?? stats.gpuUsage,
            ramUsage: ram?.usage ?? stats.ramUsage,
            ramUsedBytes: ram?.usedBytes ?? stats.ramUsedBytes,
            ramTotalBytes: ram?.totalBytes ?? stats.ramTotalBytes,
            diskUsage: disk?.usage ?? stats.diskUsage,
            diskUsedBytes: disk?.usedBytes ?? stats.diskUsedBytes,
            diskTotalBytes: disk?.totalBytes ?? stats.diskTotalBytes,
            networkDownBytesPerSecond: net?.down ?? stats.networkDownBytesPerSecond,
            networkUpBytesPerSecond: net?.up ?? stats.networkUpBytesPerSecond
        )
        stats = latest
        appendHistory(latest)
    }

    private func restartMonitoring() {
        stopMonitoring()
        startMonitoring()
    }

    private func appendHistory(_ sample: SystemStats) {
        history.append(sample)
        if history.count > Self.historyLimit {
            history.removeFirst(history.count - Self.historyLimit)
        }
    }

}
