//
//  ImageProcessingServiceProtocol.swift
//  boringNotch
//
//  Created by Agent on 01/01/26.
//

import Foundation
import CoreGraphics

@MainActor
protocol ImageProcessingServiceProtocol: Sendable {
    func removeBackground(from url: URL) async throws -> URL?
    func convertImage(from url: URL, options: ImageConversionOptions) async throws -> URL?
    func createPDF(from imageURLs: [URL], outputName: String?) async throws -> URL?
    func isImageFile(_ url: URL) -> Bool
}
