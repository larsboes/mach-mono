//
//  FullScreenService.swift
//  machNotch
//

import Foundation
import SwiftUI
import MacroVisionKit

@MainActor
@Observable
public final class FullScreenService: FullScreenServiceProtocol {
    public private(set) var currentFullScreenApps: [FullScreenMonitor.SpaceInfo] = []
    @ObservationIgnored private var monitorTask: Task<Void, Never>?
    
    public init() {
    }
    
    public func startMonitoring() {
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            let stream = await FullScreenMonitor.shared.spaceChanges()
            for await spaces in stream {
                self?.currentFullScreenApps = spaces
            }
        }
    }
    
    public func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }
    
    public func spaceChanges() async -> AsyncStream<[FullScreenMonitor.SpaceInfo]> {
        return await FullScreenMonitor.shared.spaceChanges()
    }
}
