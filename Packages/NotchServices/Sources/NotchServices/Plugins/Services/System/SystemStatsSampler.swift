//
//  SystemStatsSampler.swift
//  machNotch
//
//  Raw metric reads, split out of SystemStatsService so the service owns
//  scheduling and history and this owns the syscalls.
//
//  Every read returns nil rather than a zero when the underlying source has no
//  answer yet — a first CPU or network sample has no delta to report, and a
//  failed syscall must not be rendered as "0% busy". The caller keeps the
//  previous value in those cases.
//

import Darwin
import Foundation
import IOKit

struct SystemStatsSampler {
    private var previousCPUTicks: CPUTicks?
    private var previousNetworkSample: NetworkSample?

    // MARK: - CPU

    mutating func sampleCPU() -> (total: Double, user: Double, system: Double)? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }

        let ticks = CPUTicks(
            user: UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle: UInt64(info.cpu_ticks.2),
            nice: UInt64(info.cpu_ticks.3)
        )

        guard let previous = previousCPUTicks else {
            previousCPUTicks = ticks
            return nil
        }
        previousCPUTicks = ticks

        // Counters are monotonic; a wrap or a reset would underflow.
        guard ticks.user >= previous.user, ticks.system >= previous.system,
            ticks.idle >= previous.idle, ticks.nice >= previous.nice
        else { return nil }

        let user = ticks.user - previous.user
        let system = ticks.system - previous.system
        let idle = ticks.idle - previous.idle
        let nice = ticks.nice - previous.nice
        let total = user + system + idle + nice

        guard total > 0 else { return nil }
        let dTotal = Double(total)
        return (
            Self.clamp(Double(total - idle) / dTotal),
            Self.clamp(Double(user) / dTotal),
            Self.clamp(Double(system) / dTotal)
        )
    }

    // MARK: - GPU

    /// Busiest accelerator's utilization, 0...1.
    ///
    /// Read from the IOAccelerator registry entries' `PerformanceStatistics`.
    /// The key differs by generation, so both spellings are tried, and a
    /// machine that publishes neither simply has no GPU reading.
    func sampleGPU() -> Double? {
        var iterator: io_iterator_t = 0
        guard
            IOServiceGetMatchingServices(
                kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator
            ) == kIOReturnSuccess
        else { return nil }
        defer { IOObjectRelease(iterator) }

        var busiest: Double?
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }

            var unmanaged: Unmanaged<CFMutableDictionary>?
            guard
                IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0)
                    == kIOReturnSuccess,
                let properties = unmanaged?.takeRetainedValue() as? [String: Any],
                let performance = properties["PerformanceStatistics"] as? [String: Any]
            else { continue }

            let reading =
                performance["Device Utilization %"] as? NSNumber
                ?? performance["GPU Activity(%)"] as? NSNumber
            guard let reading else { continue }

            busiest = max(busiest ?? 0, Self.clamp(reading.doubleValue / 100))
        }

        return busiest
    }

    // MARK: - Memory

    func sampleRAM() -> (usage: Double, usedBytes: Double, totalBytes: Double)? {
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }

        let pageSize = Double(getpagesize())
        let usedPages = Double(info.active_count + info.wire_count + info.compressor_page_count)
        let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)

        guard totalBytes > 0 else { return nil }
        let usedBytes = usedPages * pageSize
        return (Self.clamp(usedBytes / totalBytes), usedBytes, totalBytes)
    }

    // MARK: - Disk

    func sampleDisk() -> (usage: Double, usedBytes: Double, totalBytes: Double)? {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            guard
                let total = attributes[.systemSize] as? NSNumber,
                let free = attributes[.systemFreeSize] as? NSNumber,
                total.doubleValue > 0
            else { return nil }

            let totalBytes = total.doubleValue
            let usedBytes = totalBytes - free.doubleValue
            return (Self.clamp(usedBytes / totalBytes), usedBytes, totalBytes)
        } catch {
            return nil
        }
    }

    // MARK: - Network

    mutating func sampleNetwork() -> (down: Double, up: Double)? {
        let sample = Self.readNetworkCounters()

        guard let previous = previousNetworkSample, sample.timestamp > previous.timestamp else {
            previousNetworkSample = sample
            return nil
        }
        previousNetworkSample = sample

        let elapsed = sample.timestamp.timeIntervalSince(previous.timestamp)
        guard elapsed > 0 else { return nil }

        // A counter reset or an interface change would underflow.
        guard sample.receivedBytes >= previous.receivedBytes,
            sample.sentBytes >= previous.sentBytes
        else { return (0, 0) }

        return (
            max(0, Double(sample.receivedBytes - previous.receivedBytes) / elapsed),
            max(0, Double(sample.sentBytes - previous.sentBytes) / elapsed)
        )
    }

    private static func readNetworkCounters() -> NetworkSample {
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
            else { continue }

            receivedBytes += UInt64(data.ifi_ibytes)
            sentBytes += UInt64(data.ifi_obytes)
        }

        return NetworkSample(receivedBytes: receivedBytes, sentBytes: sentBytes, timestamp: Date())
    }

    static func clamp(_ value: Double) -> Double {
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
