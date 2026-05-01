//
//  TemporaryFileStorageServiceProtocol.swift
//  boringNotch
//
//  Created by Agent on 01/01/26.
//

import Foundation

@MainActor
protocol TemporaryFileStorageServiceProtocol: Sendable {
    func createTempFile(for type: TempFileType) async -> URL?
    func removeTemporaryFileIfNeeded(at url: URL)
    func createZip(from urls: [URL], suggestedName: String?) async -> URL?
}
