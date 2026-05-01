//
//  SoundService.swift
//  boringNotch
//
//  Created as part of Polishing phase.
//  Handles sound effects playback with safe error handling.
//

import Foundation
import AppKit

// MARK: - Protocol

@MainActor
protocol SoundServiceProtocol: Sendable {
    func play(_ sound: SoundEffect)
}

// MARK: - Sound Effects

enum SoundEffect: String, Sendable {
    case welcome = "boring"
    // Add more sounds here as needed
    // case click
    // case success
    // case error
    
    var fileName: String { rawValue }
    var fileExtension: String { "m4a" } // Default extension, can be made dynamic if needed
}

// MARK: - Service Implementation

@MainActor
final class SoundService: SoundServiceProtocol {
    // Cache sounds to avoid reloading from disk repeatedly
    private var soundCache: [SoundEffect: NSSound] = [:]
    
    init() {}
    
    func play(_ sound: SoundEffect) {
        if let cachedSound = soundCache[sound] {
            if cachedSound.isPlaying {
                cachedSound.stop()
            }
            cachedSound.play()
            return
        }
        
        // Load if not cached
        if let url = Bundle.main.url(forResource: sound.fileName, withExtension: sound.fileExtension),
           let nsSound = NSSound(contentsOf: url, byReference: false) {
            soundCache[sound] = nsSound
            nsSound.play()
        } else {
            print("⚠️ Failed to load sound: \(sound.fileName).\(sound.fileExtension)")
        }
    }
}
