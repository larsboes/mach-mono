import XCTest
@testable import NotchServices

@MainActor
final class SystemStatsServiceTests: XCTestCase {
    func testRefreshIntervalClampsOnInitialization() {
        let service = SystemStatsService(refreshInterval: 0.2)

        XCTAssertEqual(service.refreshInterval, 1)
    }

    func testRefreshIntervalClampsOnMutation() {
        let service = SystemStatsService(refreshInterval: 3)

        service.refreshInterval = 20

        XCTAssertEqual(service.refreshInterval, 5)
    }

    func testRefreshProducesBoundedUsageValues() {
        let service = SystemStatsService(refreshInterval: 3)

        service.refresh()

        XCTAssert((0...1).contains(service.stats.cpuUsage))
        XCTAssert((0...1).contains(service.stats.ramUsage))
        XCTAssert((0...1).contains(service.stats.diskUsage))
        XCTAssertGreaterThanOrEqual(service.stats.networkDownBytesPerSecond, 0)
        XCTAssertGreaterThanOrEqual(service.stats.networkUpBytesPerSecond, 0)
    }

    func testRefreshAppendsHistory() {
        let service = SystemStatsService(refreshInterval: 3)
        let initialCount = service.history.count

        service.refresh()

        XCTAssertEqual(service.history.count, initialCount + 1)
        XCTAssertEqual(service.history.last, service.stats)
    }

    func testHistoryKeepsLastOneHundredTwentySamples() {
        let service = SystemStatsService(refreshInterval: 3)

        for _ in 0..<130 {
            service.refresh()
        }

        XCTAssertEqual(service.history.count, 120)
    }
}
