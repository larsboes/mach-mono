import XCTest

import MachIntelligenceKit
import NotchCore
import NotchServices

@testable import NotchShelfPlugin

/// Covers "the index rebuilds incrementally" from #76. Each miss is one
/// embedding call against the local model, so a full rebuild per search is the
/// difference between a shelf that is usable and one that is not.
@MainActor
final class ShelfSemanticSearchTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("shelf-semantic-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testFirstSearchEmbedsEveryItemPlusTheQuery() async throws {
        let (service, shelf, embedder) = try makeService()
        shelf.items = [item("alpha notes"), item("beta notes")]

        _ = await service.search("notes")

        XCTAssertEqual(embedder.callCount, 3, "two items plus the query itself")
    }

    func testRepeatedSearchDoesNotReEmbedUnchangedItems() async throws {
        let (service, shelf, embedder) = try makeService()
        shelf.items = [item("alpha notes"), item("beta notes")]

        _ = await service.search("notes")
        embedder.callCount = 0

        service.markNeedsRebuild()
        _ = await service.search("notes")

        XCTAssertEqual(
            embedder.callCount, 1,
            "only the query should be embedded — the shelf did not change"
        )
    }

    func testOnlyTheChangedItemIsReEmbedded() async throws {
        let (service, shelf, embedder) = try makeService()
        let keep = item("alpha notes")
        shelf.items = [keep, item("beta notes")]

        _ = await service.search("notes")
        embedder.callCount = 0

        shelf.items = [keep, item("gamma notes")]
        service.markNeedsRebuild()
        _ = await service.search("notes")

        XCTAssertEqual(
            embedder.callCount, 2,
            "one new item plus the query; the unchanged item must be skipped"
        )
    }

    func testItemRemovedFromTheShelfLeavesTheIndex() async throws {
        let (service, shelf, _) = try makeService()
        let keep = item("alpha notes")
        let drop = item("beta notes")
        shelf.items = [keep, drop]

        _ = await service.search("notes")

        shelf.items = [keep]
        service.markNeedsRebuild()
        let results = await service.search("notes")

        XCTAssertFalse(
            results.contains(where: { $0.id == drop.id }),
            "a deleted shelf item must not come back as a search hit"
        )
    }

    func testIndexSurvivesANewServiceInstance() async throws {
        let shelf = makeShelf()
        let embedder = CountingEmbeddingService()
        let url = directory.appendingPathComponent("shelf.sqlite")
        shelf.items = [item("alpha notes"), item("beta notes")]

        let first = try XCTUnwrap(
            ShelfSemanticSearchService(shelfService: shelf, embeddingService: embedder, databaseURL: url)
        )
        _ = await first.search("notes")
        embedder.callCount = 0

        // A fresh instance on the same file is what an app restart looks like.
        let second = try XCTUnwrap(
            ShelfSemanticSearchService(shelfService: shelf, embeddingService: embedder, databaseURL: url)
        )
        _ = await second.search("notes")

        XCTAssertEqual(
            embedder.callCount, 1,
            "a restart must reuse the stored vectors, not re-embed the shelf"
        )
    }

    // MARK: - Helpers

    private func makeShelf() -> StubShelfService {
        StubShelfService(
            imageProcessor: StubShelfImageProcessor(),
            fileHandler: StubShelfFileHandler(tempStorage: StubTemporaryStorage())
        )
    }

    private func makeService() throws -> (ShelfSemanticSearchService, StubShelfService, CountingEmbeddingService) {
        let shelf = makeShelf()
        let embedder = CountingEmbeddingService()
        let service = try XCTUnwrap(
            ShelfSemanticSearchService(
                shelfService: shelf,
                embeddingService: embedder,
                databaseURL: directory.appendingPathComponent("shelf.sqlite")
            )
        )
        return (service, shelf, embedder)
    }

    private func item(_ text: String) -> ShelfItem {
        ShelfItem(kind: .text(string: text))
    }
}

/// Deterministic embedding derived from the text, so equal text gives equal
/// vectors and the count of calls is the thing under test.
private final class CountingEmbeddingService: AIEmbeddingService, @unchecked Sendable {
    var callCount = 0

    func embedding(for text: String) async throws -> [Float] {
        callCount += 1
        var vector = [Float](repeating: 0, count: 16)
        for (offset, byte) in Array(text.utf8).enumerated() {
            vector[offset % 16] += Float(byte) / 255
        }
        if vector.allSatisfy({ $0 == 0 }) { vector[0] = 1 }
        return vector
    }
}
