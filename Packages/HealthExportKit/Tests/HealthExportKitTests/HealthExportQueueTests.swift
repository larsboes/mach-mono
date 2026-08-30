import XCTest

@testable import HealthExportKit

/// Covers the at-least-once delivery gate from #51.
final class HealthExportQueueTests: XCTestCase {

  private var directory: URL!

  override func setUpWithError() throws {
    directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("health-queue-tests")
      .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: directory)
  }

  private func makeQueue(maxAttempts: Int = 5, file: String = "queue.json") throws -> HealthExportQueue {
    try HealthExportQueue(
      fileURL: directory.appendingPathComponent(file), maxAttempts: maxAttempts)
  }

  private func payload(_ device: String = "iPhone") -> HealthExportPayload {
    HealthExportPayload(
      device: device,
      sentAt: Date(timeIntervalSince1970: 1_700_000_000),
      samples: [
        HealthSample(
          uuid: UUID().uuidString,
          type: .heartRate,
          value: "62",
          unit: "count/min",
          start: Date(timeIntervalSince1970: 1_700_000_000),
          end: Date(timeIntervalSince1970: 1_700_000_060)
        )
      ]
    )
  }

  // MARK: - At-least-once

  func testAFailedSendKeepsThePayloadQueued() async throws {
    let queue = try makeQueue()
    try queue.enqueue(payload())

    let summary = await queue.flush { _ in throw MacReceiverError.unauthorized }

    XCTAssertEqual(summary.delivered, 0)
    XCTAssertEqual(summary.failed, 1)
    XCTAssertEqual(queue.pendingCount, 1, "a payload that did not land must not be dropped")
  }

  func testASuccessfulSendRemovesThePayload() async throws {
    let queue = try makeQueue()
    try queue.enqueue(payload())

    let summary = await queue.flush { _ in }

    XCTAssertEqual(summary.delivered, 1)
    XCTAssertEqual(queue.pendingCount, 0)
  }

  func testAPayloadIsRetriedUntilItLands() async throws {
    let queue = try makeQueue()
    try queue.enqueue(payload())

    var attempt = 0
    var now = Date(timeIntervalSince1970: 1_700_000_000)

    // Fail twice, then succeed. Time is advanced past the backoff each round.
    for _ in 0..<3 {
      _ = await queue.flush(now: now) { _ in
        attempt += 1
        if attempt < 3 { throw MacReceiverError.unauthorized }
      }
      now = now.addingTimeInterval(600)
    }

    XCTAssertEqual(attempt, 3)
    XCTAssertEqual(queue.pendingCount, 0, "the third attempt landed, so nothing is left")
  }

  func testQueueSurvivesAProcessRestart() async throws {
    let first = try makeQueue()
    try first.enqueue(payload("iPhone"))
    try first.enqueue(payload("iPad"))
    _ = await first.flush { _ in throw MacReceiverError.unauthorized }

    // A new instance on the same file is what a relaunch looks like.
    let second = try makeQueue()

    XCTAssertEqual(second.pendingCount, 2, "a crash between send and ack must resume, not drop")
    XCTAssertEqual(Set(second.allEntries.map(\.payload.device)), ["iPhone", "iPad"])
    XCTAssertTrue(
      second.allEntries.allSatisfy { $0.attempts == 1 },
      "attempt counts must survive too, or backoff restarts on every launch"
    )
  }

  // MARK: - Backoff

  func testAnEntryIsSkippedWhileItsBackoffIsUnexpired() async throws {
    let queue = try makeQueue()
    try queue.enqueue(payload())
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    _ = await queue.flush(now: now) { _ in throw MacReceiverError.unauthorized }

    var sends = 0
    let summary = await queue.flush(now: now.addingTimeInterval(1)) { _ in sends += 1 }

    XCTAssertEqual(sends, 0, "retrying one second after a failure would hammer the receiver")
    XCTAssertEqual(summary.skipped, 1)
  }

  func testBackoffGrowsAndIsCapped() throws {
    let queue = try makeQueue()

    XCTAssertEqual(queue.retryDelay(forAttempt: 0), 0)
    XCTAssertEqual(queue.retryDelay(forAttempt: 1), 2)
    XCTAssertEqual(queue.retryDelay(forAttempt: 3), 8)
    XCTAssertEqual(queue.retryDelay(forAttempt: 40), 300, "backoff must not grow without bound")
  }

  // MARK: - Exhaustion

  func testAnExhaustedEntryIsKeptRatherThanDeleted() async throws {
    let queue = try makeQueue(maxAttempts: 2)
    try queue.enqueue(payload())
    var now = Date(timeIntervalSince1970: 1_700_000_000)

    for _ in 0..<4 {
      _ = await queue.flush(now: now) { _ in throw MacReceiverError.unauthorized }
      now = now.addingTimeInterval(600)
    }

    XCTAssertEqual(queue.pendingCount, 0, "it stops being retried")
    XCTAssertEqual(queue.exhaustedCount, 1, "but losing health data silently is worse")
  }

  func testDrainingExhaustedEntriesHandsThemBack() async throws {
    let queue = try makeQueue(maxAttempts: 1)
    try queue.enqueue(payload("iPhone"))
    _ = await queue.flush { _ in throw MacReceiverError.unauthorized }

    let drained = try queue.drainExhausted()

    XCTAssertEqual(drained.count, 1)
    XCTAssertEqual(drained.first?.payload.device, "iPhone")
    XCTAssertEqual(queue.exhaustedCount, 0)
  }

  func testDeliveredPayloadDecodesToWhatWasEnqueued() async throws {
    let queue = try makeQueue()
    let original = payload("iPhone")
    try queue.enqueue(original)

    var received: HealthExportPayload?
    _ = await queue.flush { received = $0 }

    let delivered = try XCTUnwrap(received)
    XCTAssertEqual(delivered, original)
    XCTAssertEqual(delivered.schema, HealthExportSchema.current)
  }
}
