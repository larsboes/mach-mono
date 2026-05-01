//
//  ShelfService.swift
//  boringNotch
//
//  Created by Agent on 01/01/26.
//

import Foundation
import AppKit

/// Concrete implementation of ShelfServiceProtocol.
/// Manages the state and persistence of shelf items.
@MainActor
@Observable
final class ShelfService: ShelfServiceProtocol {
    // MARK: - Properties
    
    private(set) var items: [ShelfItem] = [] {
        didSet { schedulePersistence() }
    }
    
    let selection = ShelfSelectionModel()
    
    var isLoading: Bool = false
    
    var isEmpty: Bool { items.isEmpty }
    
    // Debounced persistence
    private var persistenceTask: Task<Void, Never>?
    private let persistenceDelay: Duration = .seconds(1)
    
    nonisolated deinit {
        MainActor.assumeIsolated {
            persistenceTask?.cancel()
        }
    }

    // Injected helpers
    let imageProcessor: any ShelfImageProcessorProtocol
    let fileHandler: any ShelfFileHandlerProtocol
    private let persistenceService: ShelfPersistenceService

    // MARK: - Initialization

    init(
        imageProcessor: any ShelfImageProcessorProtocol,
        fileHandler: any ShelfFileHandlerProtocol,
        persistenceService: ShelfPersistenceService = ShelfPersistenceService()
    ) {
        self.imageProcessor = imageProcessor
        self.fileHandler = fileHandler
        self.persistenceService = persistenceService
        items = persistenceService.load()
    }
    
    // MARK: - Methods
    
    private func schedulePersistence() {
        persistenceTask?.cancel()
        persistenceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: self?.persistenceDelay ?? .seconds(1))
            guard let self = self, !Task.isCancelled else { return }
            await persistenceService.saveAsync(self.items)
        }
    }
    
    func add(_ newItems: [ShelfItem]) {
        guard !newItems.isEmpty else { return }
        var merged = items
        // Deduplicate by identityKey while preserving order (existing first)
        var seen: Set<String> = Set(merged.map { $0.identityKey })
        for it in newItems {
            let key = it.identityKey
            if !seen.contains(key) {
                merged.append(it)
                seen.insert(key)
            }
        }
        items = merged
    }
    
    func remove(_ item: ShelfItem) {
        item.cleanupStoredData(storage: fileHandler.temporaryFileStorage)
        items.removeAll { $0.id == item.id }
    }
    
    func updateBookmark(for item: ShelfItem, bookmark: Data) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        if case .file = items[idx].kind {
            items[idx] = ShelfItem(kind: .file(bookmark: bookmark), isTemporary: items[idx].isTemporary)
        }
    }
    
    func load(_ providers: [NSItemProvider]) {
        guard !providers.isEmpty else { return }
        isLoading = true
        Task { [weak self] in
            guard let self else { return }
            let dropped = await ShelfDropService.items(from: providers, storage: self.fileHandler.temporaryFileStorage)
            await MainActor.run {
                self.add(dropped)
                self.isLoading = false
            }
        }
    }
    
    func cleanupInvalidItems() {
        Task { [weak self] in
            guard let self else { return }
            var keep: [ShelfItem] = []
            for item in self.items {
                switch item.kind {
                case .file(let data):
                    let bookmark = Bookmark(data: data)
                    if await bookmark.validate() {
                        keep.append(item)
                    } else {
                        item.cleanupStoredData(storage: self.fileHandler.temporaryFileStorage)
                    }
                default:
                    keep.append(item)
                }
            }
            await MainActor.run { self.items = keep }
        }
    }
    
    func resolveAndUpdateBookmark(for item: ShelfItem) -> URL? {
        guard case .file(let bookmarkData) = item.kind else { return nil }
        let bookmark = Bookmark(data: bookmarkData)
        let result = bookmark.resolve()
        if let refreshed = result.refreshedData, refreshed != bookmarkData {
            NSLog("Bookmark for \(item) stale; refreshing")
            updateBookmark(for: item, bookmark: refreshed)
        }
        return result.url
    }
    
    func resolveFileURLs(for items: [ShelfItem]) -> [URL] {
        items.compactMap { $0.fileURL }
    }
    
    func flushSync() {
        // Cancel any scheduled persistence task (we'll save synchronously now)
        persistenceTask?.cancel()
        persistenceTask = nil
        
        // Perform a synchronous, atomic save to disk
        persistenceService.save(self.items)
    }
}
