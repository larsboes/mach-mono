//
//  ShelfItemViewModel.swift
//  boringNotch
//
//  Created by Alexander on 2025-09-24.
//

import Foundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers
import CoreServices
import ObjectiveC

@MainActor
@Observable
final class ShelfItemViewModel {
    var item: ShelfItem
    var thumbnail: NSImage?
    var isDropTargeted: Bool = false
    var isRenaming: Bool = false
    var draftTitle: String = ""
    
    // Services are now accessed via injection in methods

    init(item: ShelfItem) {
        self.item = item
        self.draftTitle = item.displayName
        // Thumbnail loading moved to onAppear with service injection
    }

    func loadThumbnail(service: ShelfServiceProtocol) async {
        guard let url = item.fileURL else { return }
        self.thumbnail = await service.imageProcessor.loadThumbnail(for: url, size: CGSize(width: 56, height: 56))
    }

    // MARK: - Actions
    func handleClick(event: NSEvent, view: NSView, items: [ShelfItem], service: ShelfServiceProtocol, quickLookService: any QuickLookServiceProtocol, quickShareService: QuickShareService) {
        let selection = service.selection
        let flags = event.modifierFlags
        if flags.contains(.shift) {
            selection.shiftSelect(to: item, in: items)
        } else if flags.contains(.command) {
            selection.toggle(item)
        } else if flags.contains(.control) {
            handleRightClick(event: event, view: view, service: service, quickLookService: quickLookService, quickShareService: quickShareService)
        } else {
            if !selection.isSelected(item.id) { selection.selectSingle(item) }
        }
        if event.clickCount == 2 { handleDoubleClick(items: items, service: service) }
    }

    func handleRightClick(event: NSEvent, view: NSView, service: ShelfServiceProtocol, quickLookService: any QuickLookServiceProtocol, quickShareService: QuickShareService) {
        ShelfContextMenuHandler.present(event: event, in: view, item: item, service: service, quickLookService: quickLookService, quickShareService: quickShareService)
    }

    func handleDoubleClick(items: [ShelfItem], service: ShelfServiceProtocol) {
        let selected = service.selection.selectedItems(in: items)
        service.fileHandler.open(items: selected, with: nil)
    }
}
