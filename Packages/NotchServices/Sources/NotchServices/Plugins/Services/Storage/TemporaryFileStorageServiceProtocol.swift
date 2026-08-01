//
//  TemporaryFileStorageServiceProtocol.swift
//  NotchServices
//

import Foundation
import NotchCore

@MainActor
public protocol TemporaryFileStorageServiceProtocol: Sendable {
    func createTempFile(for type: TempFileType) async -> URL?
    func removeTemporaryFileIfNeeded(at url: URL)
    func createZip(from urls: [URL], suggestedName: String?) async -> URL?
}
