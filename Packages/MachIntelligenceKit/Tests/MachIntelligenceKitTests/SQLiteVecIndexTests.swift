import XCTest

@testable import MachIntelligenceKit

/// Covers the M4 acceptance criteria from #76, which shipped without tests.
final class SQLiteVecIndexTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("machintel-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeIndex(_ name: String = "index.sqlite") throws -> SQLiteVecIndex {
        try SQLiteVecIndex(databaseURL: directory.appendingPathComponent(name))
    }

    /// Deterministic pseudo-random vector, so a failure reproduces.
    private func vector(seed: Int, dimension: Int = 384) -> [Float] {
        var state = UInt64(truncatingIfNeeded: seed &* 6_364_136_223_846_793_005 &+ 1)
        return (0..<dimension).map { _ in
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Float(Double(state >> 11) / Double(UInt64(1) << 53)) * 2 - 1
        }
    }

    // MARK: - Acceptance: 10k items return top-5 in under 50ms

    func testTopFiveAcrossTenThousandItemsStaysUnderFiftyMilliseconds() throws {
        let index = try makeIndex()

        for i in 0..<10_000 {
            try index.upsert(VectorRecord(id: "item-\(i)", vector: vector(seed: i)))
        }

        let probe = vector(seed: 4_242)

        // Warm the read path so the measurement is steady-state, not first-touch.
        _ = try index.query(probe, topK: 5)

        var slowest: Double = 0
        for _ in 0..<5 {
            let start = DispatchTime.now().uptimeNanoseconds
            let matches = try index.query(probe, topK: 5)
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
            slowest = max(slowest, elapsed)
            XCTAssertEqual(matches.count, 5)
        }

        print("[perf] top-5 over 10k x 384 vectors: \(String(format: "%.2f", slowest))ms worst of 5")
        XCTAssertLessThan(
            slowest, 50,
            "top-5 over 10k items took \(String(format: "%.1f", slowest))ms, budget is 50ms"
        )
    }

    func testQueryRanksTheNearestVectorFirst() throws {
        let index = try makeIndex()
        for i in 0..<200 {
            try index.upsert(VectorRecord(id: "item-\(i)", vector: vector(seed: i)))
        }

        let target = vector(seed: 77)
        let matches = try index.query(target, topK: 3)

        XCTAssertEqual(matches.first?.id, "item-77")
        XCTAssertEqual(matches.count, 3)
        XCTAssertGreaterThan(matches[0].score, matches[1].score)
    }

    // MARK: - Acceptance: the index persists across restarts

    func testIndexSurvivesReopen() throws {
        let name = "persistent.sqlite"
        do {
            let index = try makeIndex(name)
            try index.upsert(VectorRecord(id: "a", vector: vector(seed: 1), metadata: ["kind": "note"]))
            try index.upsert(VectorRecord(id: "b", vector: vector(seed: 2)))
        }

        // A new instance on the same file is what an app restart looks like.
        let reopened = try makeIndex(name)

        XCTAssertEqual(reopened.dimension, 384, "dimension must be recovered from stored rows")
        XCTAssertEqual(Set(try reopened.entries().map(\.id)), ["a", "b"])

        let matches = try reopened.query(vector(seed: 1), topK: 1)
        XCTAssertEqual(matches.first?.id, "a")
        XCTAssertEqual(matches.first?.metadata["kind"], "note")
    }

    func testUpsertUpdatesInPlaceRatherThanDuplicating() throws {
        let index = try makeIndex()
        try index.upsert(VectorRecord(id: "a", vector: vector(seed: 1), metadata: ["v": "1"]))
        try index.upsert(VectorRecord(id: "a", vector: vector(seed: 9), metadata: ["v": "2"]))

        let entries = try index.entries()
        XCTAssertEqual(entries.count, 1, "re-indexing an id must replace it, not append")
        XCTAssertEqual(entries.first?.metadata["v"], "2")
    }

    func testRemoveAndClearKeepDimensionConsistent() throws {
        let index = try makeIndex()
        try index.upsert(VectorRecord(id: "a", vector: vector(seed: 1)))
        try index.upsert(VectorRecord(id: "b", vector: vector(seed: 2)))

        try index.remove("a")
        XCTAssertEqual(try index.entries().count, 1)
        XCTAssertEqual(index.dimension, 384, "removing one row must not reset the dimension")

        try index.clear()
        XCTAssertEqual(try index.entries().count, 0)
        XCTAssertEqual(index.dimension, 0)
        XCTAssertEqual(try index.query(vector(seed: 1), topK: 5), [], "an empty index returns no matches")
    }

    func testRejectsAVectorOfTheWrongDimension() throws {
        let index = try makeIndex()
        try index.upsert(VectorRecord(id: "a", vector: vector(seed: 1)))

        XCTAssertThrowsError(try index.upsert(VectorRecord(id: "b", vector: [1, 2, 3]))) { error in
            guard case VectorIndexError.invalidDimension(let expected, let actual) = error else {
                return XCTFail("expected .invalidDimension, got \(error)")
            }
            XCTAssertEqual(expected, 384)
            XCTAssertEqual(actual, 3)
        }
    }
}
