//
//  MediaControllerProtocol.swift
//  machNotch
//
//  Created by Alexander on 2025-03-29.
//

import AppKit
import Combine
import Foundation

/// All concrete implementations must be `@Observable @MainActor`.
@MainActor
protocol MediaControllerProtocol: AnyObject {
    var playbackState: PlaybackState { get }

    var currentTime: Double { get }
    var duration: Double { get }
    var supportsVolumeControl: Bool { get }
    var supportsFavorite: Bool { get }

    func setFavorite(_ favorite: Bool) async
    func play() async
    func pause() async
    func seek(to time: Double) async
    func nextTrack() async
    func previousTrack() async
    func togglePlay() async
    func toggleShuffle() async
    func toggleRepeat() async
    func setVolume(_ level: Double) async
    func isActive() -> Bool
    func updatePlaybackInfo() async
}
