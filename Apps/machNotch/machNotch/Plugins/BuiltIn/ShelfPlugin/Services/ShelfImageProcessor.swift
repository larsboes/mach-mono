//
//  ShelfImageProcessor.swift
//  boringNotch
//
//  Created by Refactoring Agent on 2025-12-30.
//

import Foundation
import AppKit
import SwiftUI

@MainActor
final class ShelfImageProcessor: ShelfImageProcessorProtocol {
    
    // Dependencies
    private let imageProcessingService: any ImageProcessingServiceProtocol
    private let thumbnailService: any ThumbnailServiceProtocol
    
    init(imageProcessingService: any ImageProcessingServiceProtocol, thumbnailService: any ThumbnailServiceProtocol) {
        self.imageProcessingService = imageProcessingService
        self.thumbnailService = thumbnailService
    }
    
    // MARK: - Image Operations
    
    func removeBackground(from item: ShelfItem, service: ShelfServiceProtocol, completion: @escaping (Error?) -> Void) {
        guard let fileURL = item.fileURL, imageProcessingService.isImageFile(fileURL) else {
            completion(nil) // Or error
            return
        }
        
        Task {
            do {
                let resultURL = try await fileURL.accessSecurityScopedResource { url in
                    try await self.imageProcessingService.removeBackground(from: url)
                }
                
                if let resultURL = resultURL {
                    // Create bookmark and add to shelf as temporary item
                    if let bookmark = try? Bookmark(url: resultURL) {
                        let newItem = ShelfItem(
                            kind: .file(bookmark: bookmark.data),
                            isTemporary: true
                        )
                        service.add([newItem])
                    }
                }
                completion(nil)
            } catch {
                print("❌ Failed to remove background: \(error.localizedDescription)")
                completion(error)
            }
        }
    }
    
    func createPDF(from items: [ShelfItem], service: ShelfServiceProtocol, completion: @escaping (Error?) -> Void) {
        let imageURLs = items.compactMap { $0.fileURL }.filter { imageProcessingService.isImageFile($0) }
        guard !imageURLs.isEmpty else { return }
        
        Task {
            do {
                let resultURL = try await imageURLs.accessSecurityScopedResources { urls in
                    try await self.imageProcessingService.createPDF(from: urls, outputName: nil)
                }
                
                if let resultURL = resultURL {
                    if let bookmark = try? Bookmark(url: resultURL) {
                        let newItem = ShelfItem(
                            kind: .file(bookmark: bookmark.data),
                            isTemporary: true
                        )
                        service.add([newItem])
                    }
                }
                completion(nil)
            } catch {
                print("❌ Failed to create PDF: \(error.localizedDescription)")
                completion(error)
            }
        }
    }
    
    func convertImage(item: ShelfItem, options: ImageConversionOptions, service: ShelfServiceProtocol, completion: @escaping (Error?) -> Void) {
        guard let fileURL = item.fileURL, imageProcessingService.isImageFile(fileURL) else { return }
        
        Task {
            do {
                let resultURL = try await fileURL.accessSecurityScopedResource { url in
                    try await self.imageProcessingService.convertImage(from: url, options: options)
                }
                
                if let resultURL = resultURL {
                    if let bookmark = try? Bookmark(url: resultURL) {
                        let newItem = ShelfItem(
                            kind: .file(bookmark: bookmark.data),
                            isTemporary: true
                        )
                        service.add([newItem])
                    }
                }
                completion(nil)
            } catch {
                print("❌ Failed to convert image: \(error.localizedDescription)")
                completion(error)
            }
        }
    }
    
    func loadThumbnail(for url: URL, size: CGSize = CGSize(width: 56, height: 56)) async -> NSImage? {
        if let image = await thumbnailService.thumbnail(for: url, size: size) {
            return NSImage(cgImage: image, size: size)
        }
        return nil
    }
    
    func isImageFile(_ url: URL) -> Bool {
        return imageProcessingService.isImageFile(url)
    }
}
