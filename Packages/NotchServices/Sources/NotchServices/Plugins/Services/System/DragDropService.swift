//
//  DragDropService.swift
//  machNotch
//
//  Created by Alexander on 2025-11-20.
//  Refactored by Agent on 2026-01-03.
//

import Cocoa
import UniformTypeIdentifiers

@MainActor
public final class DragDropService: DragDropServiceProtocol {

    // MARK: - Observers

    private struct Observer {
        var region: CGRect
        var hasEnteredRegion = false
        let onEnter: (() -> Void)?
        let onExit: (() -> Void)?
        let onMove: ((CGPoint) -> Void)?
    }

    private var observers: [DragDropObserverToken: Observer] = [:]

    public var observerCount: Int { observers.count }

    // MARK: - Properties

    private var mouseDownMonitor: Any?
    private var mouseDraggedMonitor: Any?
    private var mouseUpMonitor: Any?

    private var pasteboardChangeCount: Int = -1
    private var isDragging: Bool = false
    private var isContentDragging: Bool = false

    private let dragPasteboard = NSPasteboard(name: .drag)

    // MARK: - Initialization

    public init() {}

    // MARK: - Registration

    @discardableResult
    public func addObserver(
        region: CGRect,
        onEnter: (() -> Void)?,
        onExit: (() -> Void)?,
        onMove: ((CGPoint) -> Void)?
    ) -> DragDropObserverToken {
        let token = DragDropObserverToken.make()
        observers[token] = Observer(region: region, onEnter: onEnter, onExit: onExit, onMove: onMove)

        // The system monitors exist only while somebody is listening.
        if observers.count == 1 {
            installMonitors()
        }
        return token
    }

    public func updateRegion(_ region: CGRect, for token: DragDropObserverToken) {
        observers[token]?.region = region
    }

    public func removeObserver(_ token: DragDropObserverToken) {
        guard observers.removeValue(forKey: token) != nil else { return }
        if observers.isEmpty {
            removeMonitors()
        }
    }

    // MARK: - Monitors

    private func installMonitors() {
        removeMonitors()

        // Track the pasteboard so a plain click is not mistaken for a content drag.
        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            guard let self else { return }
            self.pasteboardChangeCount = self.dragPasteboard.changeCount
            self.isDragging = true
            self.isContentDragging = false
            self.resetRegionEntry()
        }

        mouseDraggedMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] _ in
            self?.handleDrag()
        }

        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            guard let self, self.isDragging else { return }
            self.isDragging = false
            self.isContentDragging = false
            self.pasteboardChangeCount = -1
            self.resetRegionEntry()
        }
    }

    private func removeMonitors() {
        for monitor in [mouseDownMonitor, mouseDraggedMonitor, mouseUpMonitor] {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
        mouseDownMonitor = nil
        mouseDraggedMonitor = nil
        mouseUpMonitor = nil
        isDragging = false
        isContentDragging = false
        resetRegionEntry()
    }

    // MARK: - Drag Handling

    private func handleDrag() {
        guard isDragging else { return }

        let newContent = dragPasteboard.changeCount != pasteboardChangeCount
        if newContent && !isContentDragging && hasValidDragContent() {
            isContentDragging = true
        }
        guard isContentDragging else { return }

        let mouseLocation = NSEvent.mouseLocation

        for (token, observer) in observers {
            observer.onMove?(mouseLocation)

            let containsMouse = observer.region.contains(mouseLocation)
            guard containsMouse != observer.hasEnteredRegion else { continue }

            observers[token]?.hasEnteredRegion = containsMouse
            if containsMouse {
                observer.onEnter?()
            } else {
                observer.onExit?()
            }
        }
    }

    private func resetRegionEntry() {
        for token in observers.keys {
            observers[token]?.hasEnteredRegion = false
        }
    }

    // MARK: - Private Helpers

    /// Checks if the drag pasteboard contains valid content types that can be dropped on the shelf
    private func hasValidDragContent() -> Bool {
        let validTypes: [NSPasteboard.PasteboardType] = [
            .fileURL,
            NSPasteboard.PasteboardType(UTType.url.identifier),
            .string,
        ]
        guard let items = dragPasteboard.pasteboardItems, !items.isEmpty else { return false }
        return items.allSatisfy { item in
            item.types.contains { validTypes.contains($0) }
        }
    }
}
