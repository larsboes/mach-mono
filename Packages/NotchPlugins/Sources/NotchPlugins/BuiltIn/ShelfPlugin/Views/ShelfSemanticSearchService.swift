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

    init?(shelfService: any ShelfServiceProtocol, embeddingService: any AIEmbeddingService) {
        self.shelfService = shelfService
        self.embeddingService = embeddingService

        do {
            index = try SQLiteVecIndex(databaseURL: Self.defaultDatabaseURL(), tableName: "shelf_semantic_vectors")
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

    private func rebuildIndex() async throws {
        guard let index else { return }

        try index.clear()
        itemByID.removeAll()

        for item in shelfService.items {
            let indexText = Self.searchText(for: item)
            guard !indexText.isEmpty else { continue }

            let vector = try await embeddingService.embedding(for: indexText)
            let metadata = [
                "displayName": item.displayName
            ]
            try index.upsert(
                VectorRecord(
                    id: item.id.uuidString,
                    vector: vector,
                    metadata: metadata
                )
            )
            itemByID[item.id.uuidString] = item
        }

        needsRebuild = false
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
