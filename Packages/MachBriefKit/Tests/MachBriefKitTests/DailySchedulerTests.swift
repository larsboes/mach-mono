import XCTest
@testable import MachBriefKit

final class DailySchedulerTests: XCTestCase {
    func testStableSeedIsDeterministic() {
        let scheduler = DailyScheduler(calendar: Calendar(identifier: .gregorian))
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let first = scheduler.stableSeed(for: date, slot: .midday, sourceID: "quote")
        let second = scheduler.stableSeed(for: date, slot: .midday, sourceID: "quote")
        XCTAssertEqual(first, second)
    }

    func testQuoteSourceDeterministicForSlotAndDate() async {
        let scheduler = DailyScheduler(calendar: Calendar(identifier: .gregorian))
        let source = QuoteSource(scheduler: scheduler)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let first = await source.entry(for: .morning, date: date)
        let second = await source.entry(for: .morning, date: date)
        XCTAssertEqual(first.title, second.title)
        XCTAssertEqual(first.subtitle, second.subtitle)
    }
}
