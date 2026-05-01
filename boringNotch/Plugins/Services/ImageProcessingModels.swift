//
//  ImageProcessingModels.swift
//  boringNotch
//
//  Extracted from ImageProcessingService.swift — value types and error types.
//

import Foundation
import UniformTypeIdentifiers

// MARK: - Conversion Options

struct ImageConversionOptions {
    enum ImageFormat {
        case png, jpeg, heic, tiff, bmp

        var utType: UTType {
            switch self {
            case .png: return .png
            case .jpeg: return .jpeg
            case .heic: return .heic
            case .tiff: return .tiff
            case .bmp: return .bmp
            }
        }

        var fileExtension: String {
            switch self {
            case .png: return "png"
            case .jpeg: return "jpg"
            case .heic: return "heic"
            case .tiff: return "tiff"
            case .bmp: return "bmp"
            }
        }
    }

    let format: ImageFormat
    let compressionQuality: Double
    let maxDimension: CGFloat?
    let removeMetadata: Bool
}

// MARK: - Errors

enum ImageProcessingError: LocalizedError {
    case invalidImage
    case backgroundRemovalFailed
    case conversionFailed
    case pdfCreationFailed
    case noImagesProvided
    case saveFailed

    var errorDescription: String? {
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
