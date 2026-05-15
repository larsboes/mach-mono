//
//  SystemStatsServiceProtocol.swift
//  machNotch
//

import Darwin
import Foundation
import Observation

struct SystemStats: Equatable, Sendable {
    let cpuUsage: Double
    let cpuUserPercent: Double
    let cpuSystemPercent: Double
    let ramUsage: Double
    let ramUsedBytes: Double
    let ramTotalBytes: Double
    let diskUsage: Double
    let diskUsedBytes: Double
    let diskTotalBytes: Double
    let networkDownBytesPerSecond: Double
    let networkUpBytesPerSecond: Double

    static let zero = SystemStats(
        cpuUsage: 0, cpuUserPercent: 0, cpuSystemPercent: 0,
        ramUsage: 0, ramUsedBytes: 0, ramTotalBytes: 0,
        diskUsage: 0, diskUsedBytes: 0, diskTotalBytes: 0,
        networkDownBytesPerSecond: 0, networkUpBytesPerSecond: 0
    )
}

@MainActor
protocol SystemStatsServiceProtocol: Observable {
    var stats: SystemStats { get }
    var history: [SystemStats] { get }
    var refreshInterval: TimeInterval { get set }

    func startMonitoring()
    func stopMonitoring()
    func refresh()
}

@MainActor
@Observable
final class SystemStatsService: SystemStatsServiceProtocol {
    private static let historyLimit = 120

    var stats: SystemStats = .zero
    private(set) var history: [SystemStats] = []

    var refreshInterval: TimeInterval {
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
    private var previousCPUTicks: CPUTicks?
    private var previousNetworkSample: NetworkSample?
    private var storedRefreshInterval: TimeInterval

    private var isMonitoring: Bool {
        pollingTask != nil
    }

    init(refreshInterval: TimeInterval = 3) {
        self.storedRefreshInterval = min(max(refreshInterval, 1), 5)
        refresh()
    }

    func startMonitoring() {
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

    func stopMonitoring() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refresh() {
        let cpu = readCPUStats()
        let ram = readRAMStats()
        let disk = readDiskStats()
        let net = readNetworkRates()
        let latest = SystemStats(
            cpuUsage: cpu.total,
            cpuUserPercent: cpu.user,
            cpuSystemPercent: cpu.system,
            ramUsage: ram.usage,
            ramUsedBytes: ram.usedBytes,
            ramTotalBytes: ram.totalBytes,
            diskUsage: disk.usage,
            diskUsedBytes: disk.usedBytes,
            diskTotalBytes: disk.totalBytes,
            networkDownBytesPerSecond: net.down,
            networkUpBytesPerSecond: net.up
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

    private func readCPUStats() -> (total: Double, user: Double, system: Double) {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return (stats.cpuUsage, stats.cpuUserPercent, stats.cpuSystemPercent)
        }

        let ticks = CPUTicks(
            user: UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle: UInt64(info.cpu_ticks.2),
            nice: UInt64(info.cpu_ticks.3)
        )

        guard let previous = previousCPUTicks else {
            previousCPUTicks = ticks
            return (stats.cpuUsage, stats.cpuUserPercent, stats.cpuSystemPercent)
        }

        previousCPUTicks = ticks

        let user = ticks.user - previous.user
        let system = ticks.system - previous.system
        let idle = ticks.idle - previous.idle
        let nice = ticks.nice - previous.nice
        let total = user + system + idle + nice

        guard total > 0 else { return (stats.cpuUsage, stats.cpuUserPercent, stats.cpuSystemPercent) }
        let dTotal = Double(total)
        return (
            clamp(Double(total - idle) / dTotal),
            clamp(Double(user) / dTotal),
            clamp(Double(system) / dTotal)
        )
    }

    private func readRAMStats() -> (usage: Double, usedBytes: Double, totalBytes: Double) {
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return (stats.ramUsage, stats.ramUsedBytes, stats.ramTotalBytes)
        }

        let pageSize = Double(getpagesize())
        let usedPages = Double(info.active_count + info.wire_count + info.compressor_page_count)
        let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)

        guard totalBytes > 0 else { return (stats.ramUsage, stats.ramUsedBytes, stats.ramTotalBytes) }
        let usedBytes = usedPages * pageSize
        return (clamp(usedBytes / totalBytes), usedBytes, totalBytes)
    }

    private func readDiskStats() -> (usage: Double, usedBytes: Double, totalBytes: Double) {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            guard
                let total = attributes[.systemSize] as? NSNumber,
                let free = attributes[.systemFreeSize] as? NSNumber,
                total.doubleValue > 0
            else {
                return (stats.diskUsage, stats.diskUsedBytes, stats.diskTotalBytes)
            }

            let totalBytes = total.doubleValue
            let usedBytes = totalBytes - free.doubleValue
            return (clamp(usedBytes / totalBytes), usedBytes, totalBytes)
        } catch {
            return (stats.diskUsage, stats.diskUsedBytes, stats.diskTotalBytes)
        }
    }

    private func readNetworkRates() -> (down: Double, up: Double) {
        let sample = readNetworkSample()

        guard let previous = previousNetworkSample, sample.timestamp > previous.timestamp else {
            previousNetworkSample = sample
            return (stats.networkDownBytesPerSecond, stats.networkUpBytesPerSecond)
        }

        previousNetworkSample = sample

        let elapsed = sample.timestamp.timeIntervalSince(previous.timestamp)
        guard elapsed > 0 else { return (0, 0) }

        // Guard against counter reset or interface change causing underflow
        guard sample.receivedBytes >= previous.receivedBytes,
            sample.sentBytes >= previous.sentBytes
        else {
            previousNetworkSample = sample
            return (0, 0)
        }
        let down = Double(sample.receivedBytes - previous.receivedBytes) / elapsed
        let up = Double(sample.sentBytes - previous.sentBytes) / elapsed
        return (max(0, down), max(0, up))
    }

    private func readNetworkSample() -> NetworkSample {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        var receivedBytes: UInt64 = 0
        var sentBytes: UInt64 = 0

        guard getifaddrs(&interfaces) == 0, let first = interfaces else {
            return NetworkSample(receivedBytes: 0, sentBytes: 0, timestamp: Date())
        }

        defer { freeifaddrs(interfaces) }

        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }

            let interface = current.pointee
            guard
                let address = interface.ifa_addr,
                address.pointee.sa_family == UInt8(AF_LINK),
                let name = interface.ifa_name.map({ String(cString: $0) }),
                !name.hasPrefix("lo"),
                let data = interface.ifa_data?.assumingMemoryBound(to: if_data.self).pointee
            else {
                continue
            }

            receivedBytes += UInt64(data.ifi_ibytes)
            sentBytes += UInt64(data.ifi_obytes)
        }

        return NetworkSample(receivedBytes: receivedBytes, sentBytes: sentBytes, timestamp: Date())
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

private struct CPUTicks {
    let user: UInt64
    let system: UInt64
    let idle: UInt64
    let nice: UInt64
}

private struct NetworkSample {
    let receivedBytes: UInt64
    let sentBytes: UInt64
    let timestamp: Date
}
