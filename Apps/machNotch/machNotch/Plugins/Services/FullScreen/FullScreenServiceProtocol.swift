//
//  FullScreenServiceProtocol.swift
//  machNotch
//

import Foundation
import MacroVisionKit

@MainActor
public protocol FullScreenServiceProtocol: Sendable {
    var currentFullScreenApps: [FullScreenMonitor.SpaceInfo] { get }
    func spaceChanges() async -> AsyncStream<[FullScreenMonitor.SpaceInfo]>
}
