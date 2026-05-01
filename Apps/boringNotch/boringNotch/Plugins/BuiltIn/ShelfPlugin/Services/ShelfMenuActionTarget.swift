//
//  ShelfMenuActionTarget.swift
//  boringNotch
//
//  Extracted from ShelfActionService.swift — handles context menu action dispatch.
//

import AppKit
import Foundation

@MainActor
final class ShelfMenuActionTarget: NSObject {
    let item: ShelfItem
    weak var view: NSView?
    let service: ShelfServiceProtocol
    let quickLookService: any QuickLookServiceProtocol
    let quickShareService: QuickShareService

    // Keep associated objects (like accessory view handlers) without magic keys
    static var sliderHandlerAssoc = AssociatedObject<AnyObject>()

    init(item: ShelfItem, view: NSView, service: ShelfServiceProtocol, quickLookService: any QuickLookServiceProtocol, quickShareService: QuickShareService) {
        self.item = item
        self.view = view
        self.service = service
        self.quickLookService = quickLookService
        self.quickShareService = quickShareService
    }

    @MainActor @objc func handle(_ sender: NSMenuItem) {
        let title = sender.title
        let fileHandler = service.fileHandler

        if let marker = sender.representedObject as? String, marker == "__OTHER__" {
            openWithPanel()
            return
        }

        if let appURL = sender.representedObject as? URL {
            let selected = service.selection.selectedItems(in: service.items)
            fileHandler.open(items: selected, with: appURL)
            return
        }

        switch title {
        case "Quick Look":
            let selected = service.selection.selectedItems(in: service.items)
            let urls: [URL] = selected.compactMap { item in
                if let fileURL = item.fileURL {
                    return fileURL
                }
                if case .link(let url) = item.kind {
                    return url
                }
                return nil
            }
            if !urls.isEmpty {
                quickLookService.show(urls: urls)
            }

        case "Open":
            let selected = service.selection.selectedItems(in: service.items)
            fileHandler.open(items: selected, with: nil)

        case "Share…":
            let selected = service.selection.selectedItems(in: service.items)
            quickShareService.share(items: selected, from: view, service: service)

        case "Rename":
            let selected = service.selection.selectedItems(in: service.items)
            if selected.count == 1, let single = selected.first { showRenameDialog(for: single) }

        case "Show in Finder":
            let selected = service.selection.selectedItems(in: service.items)
            fileHandler.showInFinder(items: selected, service: service)

        case "Copy Path":
            let selected = service.selection.selectedItems(in: service.items)
            fileHandler.copyPath(items: selected)

        case "Copy":
            handleCopy()

        case "Remove":
            let selected = service.selection.selectedItems(in: service.items)
            for it in selected { ShelfActionService.remove(it, service: service) }

        case "Remove Background":
            handleRemoveBackground()

        case "Convert Image…":
            showConvertImageDialog()

        case "Create PDF":
            handleCreatePDF()

        case "Compress":
            let selected = service.selection.selectedItems(in: service.items)
            fileHandler.compress(items: selected, service: service)

        default:
            break
        }
    }

    // MARK: - Copy

    func handleCopy() {
        let selected = service.selection.selectedItems(in: service.items)
        let pb = NSPasteboard.general

        ShelfActionService.stopAccessingCopiedURLs()

        pb.clearContents()
        Task { [weak self, service] in
            guard self != nil else { return }
            let fileURLs = await selected.asyncCompactMap { item -> URL? in
                if case .file = item.kind {
                    return service.resolveAndUpdateBookmark(for: item)
                }
                return nil
            }
            if !fileURLs.isEmpty {
                // Assumes single active clipboard operation at a time
                ShelfActionService.copiedURLs = fileURLs.filter { $0.startAccessingSecurityScopedResource() }
                NSLog("Started security-scoped access for \(ShelfActionService.copiedURLs.count) copied files")
                pb.writeObjects(fileURLs as [NSURL])
            } else {
                let strings = selected.map { $0.displayName }
                if !strings.isEmpty {
                    pb.setString(strings.joined(separator: "\n"), forType: .string)
                }
            }
        }
    }

    // MARK: - Image Actions

    @MainActor
    func handleRemoveBackground() {
        let selected = service.selection.selectedItems(in: service.items)
        let imageURLs = selected.compactMap { $0.fileURL }.filter { service.imageProcessor.isImageFile($0) }

        guard let imageURL = imageURLs.first else { return }

        if let item = selected.first(where: { $0.fileURL == imageURL }) {
            service.imageProcessor.removeBackground(from: item, service: service) { error in
                if let error = error {
                    print("Background Removal Failed: \(error.localizedDescription)")
                }
            }
        }
    }

    @MainActor
    func handleCreatePDF() {
        let selected = service.selection.selectedItems(in: service.items)
        service.imageProcessor.createPDF(from: selected, service: service) { error in
            if let error = error {
                print("PDF Creation Failed: \(error.localizedDescription)")
            }
        }
    }
}
