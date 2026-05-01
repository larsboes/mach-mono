//
//  MediaControllerProtocol.swift
//  boringNotch
//
//  Created by Alexander on 2025-03-29.
//

import Foundation
import AppKit
import Combine

/// All concrete implementations must be `@Observable @MainActor`.
@MainActor
protocol MediaControllerProtocol: AnyObject {
    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> { get }
    var progressPublisher: AnyPublisher<(currentTime: Double, duration: Double), Never> { get }
    
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
