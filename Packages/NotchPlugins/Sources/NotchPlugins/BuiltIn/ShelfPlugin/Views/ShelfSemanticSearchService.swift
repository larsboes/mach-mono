import CryptoKit
import Foundation

import MachIntelligenceKit
import NotchCore
import NotchServices

@MainActor
final class ShelfSemanticSearchService {
    private let shelfService: any ShelfServiceProtocol
    private let embeddingService: any AIEmbeddingService
    private let index: (any VectorIndex)?
    private var itemByID: [String: ShelfItem] = [:]
    private var needsRebuild = true

    private(set) var supportsSemanticSearch = true

    init?(
        shelfService: any ShelfServiceProtocol,
        embeddingService: any AIEmbeddingService,
        databaseURL: URL? = nil
    ) {
        self.shelfService = shelfService
        self.embeddingService = embeddingService

        do {
            index = try SQLiteVecIndex(
                databaseURL: databaseURL ?? Self.defaultDatabaseURL(),
                tableName: "shelf_semantic_vectors"
            )
        } catch {
            NSLog("Failed to initialize shelf semantic search index: \(error)")
            index = nil
        }
    }

    func markNeedsRebuild() {
        needsRebuild = true
    }

    func search(_ query: String, topK: Int = 24) async -> [ShelfItem] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return shelfService.items }

        guard let index else {
            return localSearch(normalized, topK: topK)
        }

        do {
            if needsRebuild {
                try await rebuildIndex()
            }
            let queryVector = try await embeddingService.embedding(for: normalized)
            guard !queryVector.isEmpty else { return localSearch(normalized, topK: topK) }

            let matches = try index.query(queryVector, topK: topK)
            supportsSemanticSearch = true
            let results = matches.compactMap { itemByID[$0.id] }
            if !results.isEmpty {
                return results
            }
            return localSearch(normalized, topK: topK)
        } catch {
            supportsSemanticSearch = false
            return localSearch(normalized, topK: topK)
        }
    }

    /// Re-embeds only what changed.
    ///
    /// Every item carries the hash of the text it was indexed from, stored in
    /// the record so it survives a restart. An item whose text still hashes the
    /// same is skipped, which matters because each miss is one embedding call
    /// against the local model. Items that left the shelf are dropped.
    private(set) var lastRebuildEmbeddingCount = 0

    private func rebuildIndex() async throws {
        guard let index else { return }

        var indexedHashes: [String: String] = [:]
        for record in try index.entries() {
            indexedHashes[record.id] = record.metadata[Self.textHashKey]
        }

        var present: Set<String> = []
        var embedded = 0

        for item in shelfService.items {
            let indexText = Self.searchText(for: item)
            guard !indexText.isEmpty else { continue }

            let id = item.id.uuidString
            present.insert(id)
            itemByID[id] = item

            let hash = Self.contentHash(indexText)
            if indexedHashes[id] == hash { continue }

            let vector = try await embeddingService.embedding(for: indexText)
            embedded += 1
            try index.upsert(
                VectorRecord(
                    id: id,
                    vector: vector,
                    metadata: [
                        "displayName": item.displayName,
                        Self.textHashKey: hash,
                    ]
                )
            )
        }

        for staleID in indexedHashes.keys where !present.contains(staleID) {
            try index.remove(staleID)
            itemByID.removeValue(forKey: staleID)
        }

        lastRebuildEmbeddingCount = embedded
        needsRebuild = false
    }

    private static let textHashKey = "textHash"

    private static func contentHash(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8))
            .prefix(16)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func localSearch(_ query: String, topK: Int) -> [ShelfItem] {
        let normalized = query.lowercased()
        let matches = shelfService.items
            .compactMap { item -> (ShelfItem, Int)? in
                let haystack = Self.searchText(for: item).lowercased()
                let contains = haystack.contains(normalized) ? 1 : 0
                if contains == 0 {
                    return nil
                }
                return (item, contains)
            }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.displayName.localizedCaseInsensitiveCompare(rhs.0.displayName) == .orderedAscending
                }
                return lhs.1 > rhs.1
            }

        return Array(matches.prefix(topK).map { $0.0 })
    }

    static func searchText(for item: ShelfItem) -> String {
        switch item.kind {
        case .text(let string):
            return string
        case .link(let url):
            return [item.displayName, url.absoluteString].joined(separator: " ")
        case .file(let bookmarkData):
            let bookmark = Bookmark(data: bookmarkData)
            if let url = bookmark.resolvedURL {
                return [item.displayName, url.path, url.pathComponents.joined(separator: " ")].joined(separator: " ")
            }
            return item.displayName
        }
    }

    private static func defaultDatabaseURL() -> URL {
        let cacheDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first

        return (cacheDirectory ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("machNotch", isDirectory: true)
            .appendingPathComponent("shelf", isDirectory: true)
            .appendingPathComponent("semantic-search.sqlite")
    }
}
