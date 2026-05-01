//
//  QuickShareService.swift
//  boringNotch
//
//  Created by Alexander on 2025-09-24.
//

import AppKit
import Foundation
import UniformTypeIdentifiers

/// Dynamic representation of a sharing provider discovered at runtime
struct QuickShareProvider: Identifiable, Hashable, Sendable {
    var id: String
    var supportsRawText: Bool
}

import Observation

@MainActor
@Observable
class QuickShareService {
    var availableProviders: [QuickShareProvider] = []
    var isPickerOpen = false
    private var cachedServices: [String: NSSharingService] = [:]
    private var cachedIcons: [String: NSImage] = [:]
    // Hold security-scoped URLs during sharing
    private var sharingAccessingURLs: [URL] = []
    private var lifecycleDelegate: SharingLifecycleDelegate?

    private let temporaryFileStorage: any TemporaryFileStorageServiceProtocol
    private let sharingStateManager: any SharingServiceProtocol

    init(temporaryFileStorage: any TemporaryFileStorageServiceProtocol, sharingStateManager: any SharingServiceProtocol) {
        self.temporaryFileStorage = temporaryFileStorage
        self.sharingStateManager = sharingStateManager
        Task {
            await discoverAvailableProviders()
        }
    }
    
    // MARK: - Icon Retrieval

    @MainActor
    func icon(for providerId: String, size: CGFloat) -> NSImage? {
        // Return cached icon if available
        if let cachedIcon = cachedIcons[providerId] {
            return resizedIcon(cachedIcon, to: size)
        }
        
        // Try to get icon from cached service
        if let service = cachedServices[providerId] {
            cachedIcons[providerId] = service.image
            return resizedIcon(service.image, to: size)
        }
        
        // For system share menu, return a generic share icon
        if providerId == "System Share Menu" {
            return NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: "Share")
        }
        
        return nil
    }
    
    private func resizedIcon(_ image: NSImage, to size: CGFloat) -> NSImage {
        let targetSize = NSSize(width: size, height: size)
        return NSImage(size: targetSize, flipped: false) { rect in
            image.draw(in: rect,
                       from: NSRect(origin: .zero, size: image.size),
                       operation: .copy,
                       fraction: 1.0)
            return true
        }
    }
    // MARK: - Provider Discovery
    
    @MainActor
    func discoverAvailableProviders() async {
        let finder = ShareServiceFinder()

        let testItems: [Any] = [
            URL(string: "http://example.com")!,
            "Test" as NSString
        ]

        let services = await finder.findApplicableServices(for: testItems)

        var providers: [QuickShareProvider] = []

        for svc in services {
            let title = svc.title
            let supportsRawText = svc.canPerform(withItems: ["Test Text"])
            let provider = QuickShareProvider(id: title, supportsRawText: supportsRawText)
            if !providers.contains(provider) {
                providers.append(provider)
                cachedServices[title] = svc
                cachedIcons[title] = svc.image
            }
        }
        
        if let idx = providers.firstIndex(where: { $0.id == "AirDrop" }) {
            let ad = providers.remove(at: idx)
            providers.insert(ad, at: 0)
        }

        if !providers.contains(where: { $0.id == "System Share Menu" }) {
            providers.append(QuickShareProvider(id: "System Share Menu", supportsRawText: true))
        }

        self.availableProviders = providers

    }
    
    // MARK: - File Picker
    @MainActor
    func showFilePicker(for provider: QuickShareProvider, from view: NSView?) async {
        guard !isPickerOpen else {
            print("⚠️ QuickShareService: File picker already open")
            return
        }

        isPickerOpen = true
        sharingStateManager.beginInteraction()

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.title = "Select Files for \(provider.id)"
        panel.message = "Choose files to share via \(provider.id)"

        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            defer {
                self?.isPickerOpen = false
                self?.sharingStateManager.endInteraction()
            }

            if response == .OK && !panel.urls.isEmpty {
                Task {
                    await self?.shareFilesOrText(panel.urls, using: provider, from: view)
                }
            }
        }

        let response = panel.runModal()
        completion(response)
    }
    
    // MARK: - Sharing
    @MainActor
    func shareFilesOrText(_ items: [Any], using provider: QuickShareProvider, from view: NSView?) async {
        let fileURLs = items.compactMap { $0 as? URL }.filter { $0.isFileURL }
        // Stop any previous sharing access
        stopSharingAccessingURLs()
        // Start security-scoped access for all file URLs
        sharingAccessingURLs = fileURLs.filter { $0.startAccessingSecurityScopedResource() }

        // Setup lifecycle delegate to keep notch open during picker/service
        let delegate = sharingStateManager.makeDelegate { [weak self] in
            self?.lifecycleDelegate = nil
            self?.stopSharingAccessingURLs()
        }
        lifecycleDelegate = delegate

        if let svc = cachedServices[provider.id], svc.canPerform(withItems: items) {
            // For direct service path, explicitly mark service interaction start
            delegate.markServiceBegan()
            svc.delegate = delegate
            svc.perform(withItems: items)
        } else {
            let picker = NSSharingServicePicker(items: items)
            picker.delegate = delegate
            delegate.markPickerBegan()
            if let view, view.window != nil {
                picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
            } else {
                print("⚠️ QuickShareService: Cannot show picker - view has no window")
            }
        }
    }

    private func stopSharingAccessingURLs() {
        // NSLog("Stopping sharing access to URLs")
        for url in sharingAccessingURLs {
            url.stopAccessingSecurityScopedResource()
        }
        sharingAccessingURLs.removeAll()
    }
// MARK: - SharingServiceDelegate

private class SharingServiceDelegate: NSObject {}
    
    @MainActor
    func shareDroppedFiles(_ providers: [NSItemProvider], using shareProvider: QuickShareProvider, from view: NSView?, service: ShelfServiceProtocol) async {
        var itemsToShare: [Any] = []
        var foundText: String?

        for provider in providers {
            if let webURL = await provider.extractURL() {
                itemsToShare.append(webURL)
            } else if foundText == nil, let text = await provider.extractText() {
                foundText = text
            } else if let itemFileURL = await provider.extractItem() {
                let resolvedURL = resolveShelfItemBookmark(for: itemFileURL, service: service) ?? itemFileURL
                itemsToShare.append(resolvedURL)
            }
        }

        // If text was found, prioritize sharing it.
        if let text = foundText {
            if shareProvider.supportsRawText {
                await shareFilesOrText([text], using: shareProvider, from: view)
            } else {
                if let tempTextURL = await self.temporaryFileStorage.createTempFile(for: .text(text)) {
                    await shareFilesOrText([tempTextURL], using: shareProvider, from: view)
                    self.temporaryFileStorage.removeTemporaryFileIfNeeded(at: tempTextURL)
                } else {
                    await shareFilesOrText([text], using: shareProvider, from: view)
                }
            }
        } else if !itemsToShare.isEmpty {
            await shareFilesOrText(itemsToShare, using: shareProvider, from: view)
        }
    }

    @MainActor
    func share(items: [ShelfItem], from view: NSView?, service: ShelfServiceProtocol) {
        Task {
            var itemsToShare: [Any] = []
            
            for item in items {
                switch item.kind {
                case .file:
                    if let url = service.resolveAndUpdateBookmark(for: item) {
                        itemsToShare.append(url)
                    }
                case .text(let string):
                    itemsToShare.append(string)
                case .link(let url):
                    itemsToShare.append(url)
                }
            }
            
            guard !itemsToShare.isEmpty else { return }
            
            // Default to System Share Menu if no specific provider is chosen
            let provider = QuickShareProvider(id: "System Share Menu", supportsRawText: true)
            await shareFilesOrText(itemsToShare, using: provider, from: view)
        }
    }

    private func resolveShelfItemBookmark(for fileURL: URL, service: ShelfServiceProtocol) -> URL? {
        let items = service.items

        for itm in items {
            if let resolved = service.resolveAndUpdateBookmark(for: itm) {
                if resolved.standardizedFileURL.path == fileURL.standardizedFileURL.path {
                    return resolved
                }
            }
        }
        print("❌ Failed to resolve bookmark for shelf item")
        return nil
    }
}

// MARK: - App Storage Extension for Provider Selection

extension QuickShareProvider {
    @MainActor static func defaultProvider(from service: QuickShareService) -> QuickShareProvider {
        if let airdrop = service.availableProviders.first(where: { $0.id == "AirDrop" }) {
            return airdrop
        }
        return service.availableProviders.first ?? QuickShareProvider(id: "System Share Menu", supportsRawText: true)
    }
}
