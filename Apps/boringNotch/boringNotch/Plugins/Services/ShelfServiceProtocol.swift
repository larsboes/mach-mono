//
//  ShelfServiceProtocol.swift
//  boringNotch
//
//  Created by Agent on 01/01/26.
//

import Foundation
import AppKit

/// Protocol defining the interface for shelf data access and manipulation.
/// Wraps the functionality of ShelfStateViewModel.
@MainActor
protocol ShelfServiceProtocol: Observable, Sendable {
    /// The current list of items in the shelf
    var items: [ShelfItem] { get }
    
    /// The selection model for shelf items
    var selection: ShelfSelectionModel { get }
    
    /// Image processor helper
    var imageProcessor: any ShelfImageProcessorProtocol { get }
    
    /// File handler helper
    var fileHandler: any ShelfFileHandlerProtocol { get }
    
    /// Whether data is currently being loaded (e.g. from a drop)
    var isLoading: Bool { get }
    
    /// Whether the shelf is empty
    var isEmpty: Bool { get }
    
    /// Adds new items to the shelf
    func add(_ newItems: [ShelfItem])
    
    /// Removes a specific item from the shelf
    func remove(_ item: ShelfItem)
    
    /// Updates the bookmark data for a file item
    func updateBookmark(for item: ShelfItem, bookmark: Data)
    
    /// Loads items from NSItemProviders (e.g. from drag and drop)
    func load(_ providers: [NSItemProvider])
    
    /// Cleans up invalid items (e.g. stale file bookmarks)
    func cleanupInvalidItems()
    
    /// Resolves the file URL for an item and updates the bookmark if stale
    func resolveAndUpdateBookmark(for item: ShelfItem) -> URL?
    
    /// Resolves file URLs for a list of items
    func resolveFileURLs(for items: [ShelfItem]) -> [URL]
    
    /// Flushes pending changes to disk synchronously
    func flushSync()
}
