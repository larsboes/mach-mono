//
//  ShelfDraggableClickHandler.swift
//  boringNotch
//
//  Extracted from ShelfItemView.swift — NSDraggingSource drag handler.
//

import AppKit
import QuickLook
import SwiftUI

struct DraggableClickHandler<Content: View>: NSViewRepresentable {
    let item: ShelfItem
    let settings: NotchSettings
    let viewModel: ShelfItemViewModel
    let service: ShelfServiceProtocol
    @ViewBuilder let dragPreviewContent: () -> Content
    let onRightClick: (NSEvent, NSView) -> Void
    let onClick: (NSEvent, NSView) -> Void

    func makeNSView(context: Context) -> DraggableClickView {
        let view = DraggableClickView()
        view.item = item
        view.settings = settings
        view.viewModel = viewModel
        view.service = service
        view.getDragPreview = { self.renderDragPreview() }
        view.onRightClick = onRightClick
        view.onClick = onClick
        return view
    }

    func updateNSView(_ nsView: DraggableClickView, context: Context) {
        nsView.item = item
        nsView.settings = settings
        nsView.viewModel = viewModel
        nsView.service = service
        nsView.getDragPreview = { self.renderDragPreview() }
        nsView.onRightClick = onRightClick
        nsView.onClick = onClick
    }

    private func renderDragPreview() -> NSImage {
        let content = dragPreviewContent()
        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        return renderer.nsImage ?? viewModel.thumbnail ?? item.icon
    }

    // MARK: - NSView + NSDraggingSource

    final class DraggableClickView: NSView, NSDraggingSource {
        var item: ShelfItem?
        var settings: (any NotchSettings)?
        weak var viewModel: ShelfItemViewModel?
        var service: (any ShelfServiceProtocol)?
        var getDragPreview: (() -> NSImage)?
        var onRightClick: ((NSEvent, NSView) -> Void)?
        var onClick: ((NSEvent, NSView) -> Void)?

        private var mouseDownEvent: NSEvent?
        private let dragThreshold: CGFloat = 3.0
        private var draggedURLs: [URL] = []
        private var draggedItems: [ShelfItem] = []

        override func rightMouseDown(with event: NSEvent) {
            onRightClick?(event, self)
        }

        override func mouseDown(with event: NSEvent) {
            mouseDownEvent = event
            onClick?(event, self)
        }

        override func mouseDragged(with event: NSEvent) {
            guard let mouseDownEvent else { return super.mouseDragged(with: event) }
            let dist = hypot(
                event.locationInWindow.x - mouseDownEvent.locationInWindow.x,
                event.locationInWindow.y - mouseDownEvent.locationInWindow.y
            )
            if dist > dragThreshold {
                startDragSession(with: event)
                self.mouseDownEvent = nil
            } else {
                super.mouseDragged(with: event)
            }
        }

        private func startDragSession(with event: NSEvent) {
            guard let item, let service else { return }
            let selectedItems = service.selection.selectedItems(in: service.items)
            let itemsToDrag = (selectedItems.count > 1 && selectedItems.contains { $0.id == item.id })
                ? selectedItems : [item]
            draggedItems = itemsToDrag

            let draggingItems: [NSDraggingItem] = itemsToDrag.compactMap { dragItem in
                guard let pasteboardItem = createPasteboardItem(for: dragItem) else { return nil }
                let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
                let image = getDragPreview?() ?? dragItem.icon
                draggingItem.setDraggingFrame(NSRect(origin: .zero, size: image.size), contents: image)
                return draggingItem
            }

            guard !draggingItems.isEmpty else { return }
            beginDraggingSession(with: draggingItems, event: event, source: self)
        }

        private func createPasteboardItem(for item: ShelfItem) -> NSPasteboardItem? {
            let pasteboardItem = NSPasteboardItem()
            switch item.kind {
            case .file:
                guard let url = service?.resolveAndUpdateBookmark(for: item) else {
                    pasteboardItem.setString(item.displayName, forType: .string)
                    return pasteboardItem
                }
                if url.startAccessingSecurityScopedResource() { draggedURLs.append(url) }
                pasteboardItem.setString(url.absoluteString, forType: .fileURL)
                pasteboardItem.setString(url.path, forType: .string)
            case .text(let string):
                pasteboardItem.setString(string, forType: .string)
            case .link(let url):
                pasteboardItem.setString(url.absoluteString, forType: .URL)
                pasteboardItem.setString(url.absoluteString, forType: .string)
            }
            return pasteboardItem
        }

        // MARK: NSDraggingSource

        func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            if settings?.copyOnDrag == true { return [.copy] }
            switch context {
            case .outsideApplication: return [.copy, .move]
            case .withinApplication: return [.copy, .move, .generic]
            @unknown default: return [.copy]
            }
        }

        func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
            service?.selection.beginDrag()
        }

        func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
            service?.selection.endDrag()
            draggedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
            draggedURLs.removeAll()
            if settings?.autoRemoveShelfItems == true && !operation.isEmpty {
                draggedItems.forEach { service?.remove($0) }
            }
            draggedItems.removeAll()
        }

        func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { false }
    }
}
