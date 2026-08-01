//
//  ImageProcessingModels.swift
//  machNotch
//
//  Extracted from ImageProcessingService.swift — value types and error types.
//

import Foundation
import UniformTypeIdentifiers

// MARK: - Conversion Options

public struct ImageConversionOptions {
    public enum ImageFormat {
        case png, jpeg, heic, tiff, bmp

        public var utType: UTType {
            switch self {
            case .png: return .png
            case .jpeg: return .jpeg
            case .heic: return .heic
            case .tiff: return .tiff
            case .bmp: return .bmp
            }
        }

        public var fileExtension: String {
            switch self {
            case .png: return "png"
            case .jpeg: return "jpg"
            case .heic: return "heic"
            case .tiff: return "tiff"
            case .bmp: return "bmp"
            }
        }
    }

    public let format: ImageFormat
    public let compressionQuality: Double
    public let maxDimension: CGFloat?
    public let removeMetadata: Bool

    public init(format: ImageFormat, compressionQuality: Double, maxDimension: CGFloat?, removeMetadata: Bool) {
        self.format = format
        self.compressionQuality = compressionQuality
        self.maxDimension = maxDimension
        self.removeMetadata = removeMetadata
    }
}

// MARK: - Errors

public enum ImageProcessingError: LocalizedError {
    case invalidImage
    case backgroundRemovalFailed
    case conversionFailed
    case pdfCreationFailed
    case noImagesProvided
    case saveFailed

    public var errorDescription: String? {
        switch self {
        case .invalidImage: return "The file is not a valid image"
        case .backgroundRemovalFailed: return "Failed to remove background from image"
        case .conversionFailed: return "Failed to convert image format"
        case .pdfCreationFailed: return "Failed to create PDF from images"
        case .noImagesProvided: return "No images were provided"
        case .saveFailed: return "Failed to save processed file"
        }
    }
}
