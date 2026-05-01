//
//  DragDropService.swift
//  boringNotch
//
//  Created by Alexander on 2025-11-20.
//  Refactored by Agent on 2026-01-03.
//

import Cocoa
import UniformTypeIdentifiers

@MainActor
final class DragDropService: DragDropServiceProtocol {

    // MARK: - Callbacks

    var onDragEntersNotchRegion: (() -> Void)?
    var onDragExitsNotchRegion: (() -> Void)?
    var onDragMove: ((CGPoint) -> Void)?

    // MARK: - Properties

    private var mouseDownMonitor: Any?
    private var mouseDraggedMonitor: Any?
    private var mouseUpMonitor: Any?

    private var pasteboardChangeCount: Int = -1
    private var isDragging: Bool = false
    private var isContentDragging: Bool = false
    private var hasEnteredNotchRegion: Bool = false

    private var notchRegion: CGRect = .zero
    private let dragPasteboard = NSPasteboard(name: .drag)

    // MARK: - Initialization

    init() {}

    // MARK: - Methods

    func updateNotchRegion(_ region: CGRect) {
        // print("DragDropService: Updating notch region to: \(region)")
        self.notchRegion = region
    }

    func startMonitoring() {
        stopMonitoring()

        // Track pasteboard to detect content drag
        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            guard let self = self else { return }
            self.pasteboardChangeCount = self.dragPasteboard.changeCount
            self.isDragging = true
            self.isContentDragging = false
            self.hasEnteredNotchRegion = false
        }

        // Track drag movement and notch region intersection
        mouseDraggedMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] event in
            guard let self = self else { return }
            guard self.isDragging else { return }

            let newContent = self.dragPasteboard.changeCount != self.pasteboardChangeCount
            
            // Detect if actual content is being dragged AND it's valid content
            if newContent && !self.isContentDragging && self.hasValidDragContent() {
                self.isContentDragging = true
            }

            // Only process position when content is being dragged
            if self.isContentDragging {
                let mouseLocation = NSEvent.mouseLocation
                self.onDragMove?(mouseLocation)
                
                // Track notch region entry/exit
                let containsMouse = self.notchRegion.contains(mouseLocation)
                if containsMouse && !self.hasEnteredNotchRegion {
                    // print("DragDropService: Entered notch region at \(mouseLocation)")
                    self.hasEnteredNotchRegion = true
                    self.onDragEntersNotchRegion?()
                } else if !containsMouse && self.hasEnteredNotchRegion {
                    // print("DragDropService: Exited notch region at \(mouseLocation)")
                    self.hasEnteredNotchRegion = false
                    self.onDragExitsNotchRegion?()
                }
            }
        }

        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            guard let self = self else { return }
            guard self.isDragging else { return }
            
            self.isDragging = false
            self.isContentDragging = false
            self.hasEnteredNotchRegion = false
            self.pasteboardChangeCount = -1
        }
    }

    func stopMonitoring() {
        [mouseDownMonitor, mouseDraggedMonitor, mouseUpMonitor].forEach { monitor in
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
        mouseDownMonitor = nil
        mouseDraggedMonitor = nil
        mouseUpMonitor = nil
        isDragging = false
        isContentDragging = false
        hasEnteredNotchRegion = false
    }

    // MARK: - Private Helpers
    
    /// Checks if the drag pasteboard contains valid content types that can be dropped on the shelf
    private func hasValidDragContent() -> Bool {
        let validTypes: [NSPasteboard.PasteboardType] = [
            .fileURL,
            NSPasteboard.PasteboardType(UTType.url.identifier),
            .string
        ]
        let isValid = dragPasteboard.pasteboardItems?.allSatisfy { item in
            item.types.allSatisfy { validTypes.contains($0) }
        }
        return isValid ?? false
    }
}
