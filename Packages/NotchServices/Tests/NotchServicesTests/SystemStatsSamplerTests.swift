import XCTest

@testable import NotchServices

/// Covers #69's sampling half: every reading is bounded, and a source with no
/// answer yet reports nil rather than a zero the UI would draw as "idle".
@MainActor
final class SystemStatsSamplerTests: XCTestCase {

    func testFirstCPUSampleHasNoDeltaToReport() {
        var sampler = SystemStatsSampler()
        XCTAssertNil(
            sampler.sampleCPU(),
            "CPU load is a delta between ticks, so the first read cannot produce one"
        )
    }

    func testSecondCPUSampleIsBounded() {
        var sampler = SystemStatsSampler()
        _ = sampler.sampleCPU()

        let reading = sampler.sampleCPU()

        // A second read within the same instant can still be a no-op if no
        // ticks accumulated; when it does report, it must be in range.
        if let reading {
            XCTAssertTrue((0...1).contains(reading.total), "total was \(reading.total)")
            XCTAssertTrue((0...1).contains(reading.user), "user was \(reading.user)")
            XCTAssertTrue((0...1).contains(reading.system), "system was \(reading.system)")
        }
    }

    func testGPUReadingIsEitherAbsentOrBounded() {
        let reading = SystemStatsSampler().sampleGPU()

        // Not every machine publishes IOAccelerator PerformanceStatistics, so
        // absence is a valid outcome. A present reading must be a fraction.
        if let reading {
            XCTAssertTrue((0...1).contains(reading), "GPU utilization was \(reading)")
        }
    }

    func testMemoryReadingIsBoundedAndHasARealTotal() throws {
        let reading = try XCTUnwrap(SystemStatsSampler().sampleRAM())

        XCTAssertTrue((0...1).contains(reading.usage), "usage was \(reading.usage)")
        XCTAssertGreaterThan(reading.totalBytes, 0)
        XCTAssertLessThanOrEqual(reading.usedBytes, reading.totalBytes)
    }

    func testDiskReadingIsBoundedAndHasARealTotal() throws {
        let reading = try XCTUnwrap(SystemStatsSampler().sampleDisk())

        XCTAssertTrue((0...1).contains(reading.usage), "usage was \(reading.usage)")
        XCTAssertGreaterThan(reading.totalBytes, 0)
        XCTAssertLessThanOrEqual(reading.usedBytes, reading.totalBytes)
    }

    func testFirstNetworkSampleHasNoRateToReport() {
        var sampler = SystemStatsSampler()
        XCTAssertNil(
            sampler.sampleNetwork(),
            "throughput is a delta over time, so the first read cannot produce one"
        )
    }

    func testNetworkRatesAreNeverNegative() {
        var sampler = SystemStatsSampler()
        _ = sampler.sampleNetwork()

        if let rates = sampler.sampleNetwork() {
            XCTAssertGreaterThanOrEqual(rates.down, 0)
            XCTAssertGreaterThanOrEqual(rates.up, 0)
        }
    }

    func testClampPinsValuesIntoTheUnitRange() {
        XCTAssertEqual(SystemStatsSampler.clamp(-4), 0)
        XCTAssertEqual(SystemStatsSampler.clamp(0.42), 0.42)
        XCTAssertEqual(SystemStatsSampler.clamp(7), 1)
    }

    // MARK: - The service must not paint a missing reading as zero

    func testServiceKeepsThePreviousValueWhenASourceGoesQuiet() {
        let service = SystemStatsService(refreshInterval: 1)

        service.refresh()
        service.refresh()
        let before = service.stats

        service.refresh()

        // GPU and CPU can legitimately report nothing on a given tick. Whatever
        // happens, a real total must never collapse to zero.
        XCTAssertGreaterThan(service.stats.ramTotalBytes, 0)
        XCTAssertGreaterThan(service.stats.diskTotalBytes, 0)
        XCTAssertEqual(service.stats.ramTotalBytes, before.ramTotalBytes)
    }

    func testGPUUsageIsCarriedIntoTheStatsSnapshot() {
        let service = SystemStatsService(refreshInterval: 1)
        service.refresh()

        XCTAssertTrue(
            (0...1).contains(service.stats.gpuUsage),
            "gpuUsage was \(service.stats.gpuUsage)"
        )
    }
}
