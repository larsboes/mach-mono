import XCTest

@testable import HealthExportKit

final class HealthAnchorStoreTests: XCTestCase {

  private var fileURL: URL!

  override func setUpWithError() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("health-anchor-tests")
      .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    fileURL = directory.appendingPathComponent("anchors.json")
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
  }

  func testAnchorsAreScopedPerMetricType() throws {
    let store = try HealthAnchorStore(fileURL: fileURL)

    try store.setAnchor(Data([1, 2, 3]), for: .heartRate)
    try store.setAnchor(Data([9]), for: .steps)

    XCTAssertEqual(store.anchor(for: .heartRate), Data([1, 2, 3]))
    XCTAssertEqual(store.anchor(for: .steps), Data([9]))
    XCTAssertNil(store.anchor(for: .sleepStage))
  }

  func testAnchorsSurviveARestart() throws {
    let first = try HealthAnchorStore(fileURL: fileURL)
    try first.setAnchor(Data([4, 2]), for: .hrvSDNN)

    let second = try HealthAnchorStore(fileURL: fileURL)

    XCTAssertEqual(
      second.anchor(for: .hrvSDNN), Data([4, 2]),
      "a lost anchor either re-reads all history or silently skips what happened while closed"
    )
  }

  func testClearingAnAnchorForcesABackfill() throws {
    let store = try HealthAnchorStore(fileURL: fileURL)
    try store.setAnchor(Data([7]), for: .workout)

    try store.setAnchor(nil, for: .workout)

    XCTAssertNil(store.anchor(for: .workout))
    XCTAssertTrue(store.typesWithoutAnchor().contains(.workout))
  }

  func testEveryTypeIsUnanchoredOnAFirstRun() throws {
    let store = try HealthAnchorStore(fileURL: fileURL)

    XCTAssertEqual(
      Set(store.typesWithoutAnchor()), Set(HealthMetricType.allCases),
      "a first run must know the whole set needs backfilling"
    )
  }

  func testResetForgetsEverything() throws {
    let store = try HealthAnchorStore(fileURL: fileURL)
    try store.setAnchor(Data([1]), for: .steps)
    try store.setAnchor(Data([2]), for: .heartRate)

    try store.reset()

    XCTAssertEqual(Set(store.typesWithoutAnchor()), Set(HealthMetricType.allCases))
  }
}
