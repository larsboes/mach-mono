//
//  ShelfFileHandler.swift
//  machNotch
//
//  Created by Refactoring Agent on 2025-12-30.
//

import Foundation
import AppKit
import SwiftUI

@MainActor
final class ShelfFileHandler: ShelfFileHandlerProtocol {
    // Dependencies
    let temporaryFileStorage: any TemporaryFileStorageServiceProtocol
    
    init(temporaryFileStorage: any TemporaryFileStorageServiceProtocol) {
        self.temporaryFileStorage = temporaryFileStorage
    }
    
    // MARK: - File Operations
    
    func rename(item: ShelfItem, newName: String, service: ShelfServiceProtocol, completion: @escaping (Bool) -> Void) {
        guard case let .file(bookmarkData) = item.kind else { 
            completion(false)
            return 
        }
        
        Task {
            let bookmark = Bookmark(data: bookmarkData)
            if let fileURL = bookmark.resolvedURL {
                // Start security-scoped access
                let didStart = fileURL.startAccessingSecurityScopedResource()
                defer { if didStart { fileURL.stopAccessingSecurityScopedResource() } }
                
                let newURL = fileURL.deletingLastPathComponent().appendingPathComponent(newName)
                
                do {
                    NSLog("🔐 Rename: moving from \(fileURL.path) to \(newURL.path)")
                    try FileManager.default.moveItem(at: fileURL, to: newURL)
                    
                    if let newBookmark = try? Bookmark(url: newURL) {
                        service.updateBookmark(for: item, bookmark: newBookmark.data)
                        completion(true)
                    } else {
                        completion(false)
                    }
                } catch {
                    print("❌ Failed to rename file: \(error.localizedDescription)")
                    completion(false)
                }
            } else {
                completion(false)
            }
        }
    }
    
    func showInFinder(items: [ShelfItem], service: ShelfServiceProtocol) {
        Task {
            let urls = await items.asyncCompactMap { item -> URL? in
                if case .file = item.kind {
                    return await service.resolveAndUpdateBookmark(for: item)
                }
                return nil
            }
            
            if !urls.isEmpty {
                await urls.accessSecurityScopedResources { accessibleURLs in
                    NSWorkspace.shared.activateFileViewerSelecting(accessibleURLs)
                }
            }
        }
    }
    
    func copyPath(items: [ShelfItem]) {
        let paths = items.compactMap { $0.fileURL?.path }
        if !paths.isEmpty {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(paths.joined(separator: "\n"), forType: .string)
        }
    }
    
    func compress(items: [ShelfItem], service: ShelfServiceProtocol) {
        let fileURLs = items.compactMap { $0.fileURL }
        guard !fileURLs.isEmpty else { return }

        Task {
            // Create ZIP in a temporary location while holding access to selected resources
            if let zipTempURL = await fileURLs.accessSecurityScopedResources(accessor: { urls in
                await self.temporaryFileStorage.createZip(from: urls, suggestedName: nil)
            }) {
                if let bookmark = try? Bookmark(url: zipTempURL) {
                    let newItem = ShelfItem(kind: .file(bookmark: bookmark.data), isTemporary: true)
                    service.add([newItem])
                } else {
                    // Fallback: reveal the temporary file in Finder
                    NSWorkspace.shared.activateFileViewerSelecting([zipTempURL])
                }
            }
        }
    }
    
    // MARK: - Open With Logic
    
    func open(items: [ShelfItem], with appURL: URL? = nil) {
        Task {
            let allSelectedURLs: [URL] = items.compactMap { itm -> URL? in
                if let fileURL = itm.fileURL { return fileURL }
                if case .link(let url) = itm.kind { return url }
                return nil
            }

            guard !allSelectedURLs.isEmpty else { return }

            if let appURL = appURL {
                let fileURLs = allSelectedURLs.filter { $0.isFileURL }
                do {
                    if !fileURLs.isEmpty {
                        _ = try await fileURLs.accessSecurityScopedResources { _ in
                            let config = NSWorkspace.OpenConfiguration()
                            try await NSWorkspace.shared.open(allSelectedURLs, withApplicationAt: appURL, configuration: config)
                        }
                    } else {
                        let config = NSWorkspace.OpenConfiguration()
                        try await NSWorkspace.shared.open(allSelectedURLs, withApplicationAt: appURL, configuration: config)
                    }
                } catch {
                    print("❌ Failed to open with application: \(error.localizedDescription)")
                }
            } else {
                // Default open
                for it in items {
                    ShelfActionService.open(it)
                }
            }
        }
    }
    
    // MARK: - Helper for Async Map
    
    private func isDirectory(_ url: URL) -> Bool {
        return url.accessSecurityScopedResource { scoped in
            (try? scoped.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        }
    }
}
