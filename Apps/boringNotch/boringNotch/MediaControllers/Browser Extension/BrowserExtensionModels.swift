//
//  BrowserExtensionModels.swift
//  boringNotch
//
//  Created by Alexander on 2025-06-16.
//

import Foundation

// MARK: - Browser -> Swift (Incoming)
struct BrowserMediaState: Codable {
    let title: String
    let artist: String
    let album: String
    let isPaused: Bool
    let currentTime: Double
    let duration: Double
    let playbackRate: Double
    let bundleIdentifier: String
}

// MARK: - Swift -> Browser (Outgoing)
struct BrowserMediaCommand: Codable {
    let command: String
    let value: Double?
    
    init(command: String, value: Double? = nil) {
        self.command = command
        self.value = value
    }
}
