//
//  ImageService.swift
//  boringNotch
//
//  Created by Alexander on 2025-09-13.
//

import Foundation

public protocol ImageServiceProtocol {
    func fetchImageData(from url: URL) async throws -> Data
}

public final class ImageService: ImageServiceProtocol {
    private let session: URLSession

    /// - Parameter needsLegacyCacheCleanup: When `true`, clears the shared URLCache once.
    ///   Callers (e.g. AppObjectGraph) read/write the Defaults flag and pass the result.
    public init(needsLegacyCacheCleanup: Bool = false) {
        let config = URLSessionConfiguration.default
        let cache = URLCache(memoryCapacity: 50 * 1024 * 1024, // 50MB
                             diskCapacity: 100 * 1024 * 1024, // 100MB
                             diskPath: "artwork_cache")
        config.urlCache = cache
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.httpShouldSetCookies = false
        self.session = URLSession(configuration: config)

        if needsLegacyCacheCleanup {
            URLCache.shared.removeAllCachedResponses()
        }
    }

    public func fetchImageData(from url: URL) async throws -> Data {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw URLError(.unsupportedURL)
        }
        let (data, _) = try await session.data(from: url)
        return data
    }
}
