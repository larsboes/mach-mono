//
//  ThumbnailServiceProtocol.swift
//  boringNotch
//
//  Created by Agent on 01/01/26.
//

import Foundation
import CoreGraphics

protocol ThumbnailServiceProtocol: Sendable {
    func thumbnail(for url: URL, size: CGSize) async -> CGImage?
    func clearCache() async
    func clearCache(for url: URL) async
}
