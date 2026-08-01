//
//  ShelfSelectionModel.swift
//  NotchServices
//

import Foundation
import NotchCore

private let _shelfTypeAnchor: Bool = {
    _ = String(describing: ShelfItem.self)
    return true
}()

@MainActor
@Observable public final class ShelfSelectionModel {

    public private(set) var selectedIDs: Set<UUID> = []

    // Anchor for shift-range selection
    private var lastAnchorID: UUID?

    public init() {}

    public func isSelected(_ id: UUID) -> Bool { selectedIDs.contains(id) }

    public var hasSelection: Bool { !selectedIDs.isEmpty }

    public func selectedItems(in allItems: [ShelfItem]) -> [ShelfItem] {
        allItems.filter { selectedIDs.contains($0.id) }
    }

    public func selectSingle(_ item: ShelfItem) {
        selectedIDs = [item.id]
        lastAnchorID = item.id
    }

    public func toggle(_ item: ShelfItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
        lastAnchorID = item.id
    }

    public func shiftSelect(to item: ShelfItem, in allItems: [ShelfItem]) {
        // Determine anchor
        let anchorID = lastAnchorID ?? selectedIDs.first ?? item.id
        guard let startIndex = allItems.firstIndex(where: { $0.id == anchorID }),
            let endIndex = allItems.firstIndex(where: { $0.id == item.id })
        else {
            // Fallback to single select if indices not found
            return selectSingle(item)
        }
        let lower = min(startIndex, endIndex)
        let upper = max(startIndex, endIndex)
        let rangeIDs = allItems[lower...upper].map { $0.id }
        selectedIDs = Set(rangeIDs)
    }

    public func clear() {
        selectedIDs.removeAll()
        lastAnchorID = nil
    }

    // Keep anchor sane if items array changed drastically (optional helper)
    public func ensureValidAnchor(in allItems: [ShelfItem]) {
        if let anchor = lastAnchorID, !allItems.contains(where: { $0.id == anchor }) {
            lastAnchorID = selectedIDs.first
        }
    }

    public private(set) var isDragging: Bool = false

    public func beginDrag() {
        isDragging = true
    }

    public func endDrag() {
        isDragging = false
    }
}
