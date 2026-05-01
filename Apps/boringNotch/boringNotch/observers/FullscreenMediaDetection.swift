//
//  FullscreenMediaDetection.swift
//  boringNotch
//
//  Created by Richard Kunkli on 06/09/2024.
//

import Foundation
import MacroVisionKit

@MainActor
@Observable final class FullscreenMediaDetector {
    var fullscreenStatus: [String: Bool] = [:]

    private let musicService: any MusicServiceProtocol
    private let settings: any MediaSettings
    private var monitorTask: Task<Void, Never>?

    init(musicService: any MusicServiceProtocol, settings: any MediaSettings) {
        self.musicService = musicService
        self.settings = settings
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitorTask = Task { @MainActor in
            let stream = await FullScreenMonitor.shared.spaceChanges()
            for await spaces in stream {
                updateStatus(with: spaces)
            }
        }
    }
    
    private func updateStatus(with spaces: [MacroVisionKit.FullScreenMonitor.SpaceInfo]) {
        var newStatus: [String: Bool] = [:]
        
        for space in spaces {
            if let uuid = space.screenUUID {
                let shouldDetect: Bool
                if settings.hideNotchOption == .nowPlayingOnly, let musicSourceBundle = musicService.bundleIdentifier {
                    shouldDetect = space.runningApps.contains(musicSourceBundle)
                } else {
                    shouldDetect = true
                }
                newStatus[uuid] = shouldDetect
            }
        }
        
        self.fullscreenStatus = newStatus
    }
}
