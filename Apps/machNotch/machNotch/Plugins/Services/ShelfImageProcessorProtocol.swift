//
//  ShelfImageProcessorProtocol.swift
//  boringNotch
//
//  Created by Refactoring Agent on 2026-01-01.
//

import AppKit
import Foundation

@MainActor
protocol ShelfImageProcessorProtocol {
    func removeBackground(from item: ShelfItem, service: ShelfServiceProtocol, completion: @escaping (Error?) -> Void)
    func createPDF(from items: [ShelfItem], service: ShelfServiceProtocol, completion: @escaping (Error?) -> Void)
    func convertImage(item: ShelfItem, options: ImageConversionOptions, service: ShelfServiceProtocol, completion: @escaping (Error?) -> Void)
    func loadThumbnail(for url: URL, size: CGSize) async -> NSImage?
    func isImageFile(_ url: URL) -> Bool
}
