//
//  BrowserMediaController.swift
//  machNotch
//
//  Created by Alexander on 2025-06-16.
//

import Combine
import Foundation
import SwiftUI

@Observable
@MainActor
final class BrowserMediaController: MediaControllerProtocol {
    private var cancellables = Set<AnyCancellable>()

    var playbackState = PlaybackState(bundleIdentifier: "com.google.Chrome")
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    private var lastArtworkURL: String?

    var supportsVolumeControl: Bool { false }
    var supportsFavorite: Bool { false }

    private let server: BrowserExtensionServer

    init(server: BrowserExtensionServer) {
        self.server = server
        server.start()

        server.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] browserState in
                self?.handleStateUpdate(browserState)
            }
            .store(in: &cancellables)
    }

    private func handleStateUpdate(_ browserState: BrowserMediaState) {
        var newState = playbackState

        newState.title = browserState.title
        newState.artist = browserState.artist
        newState.album = browserState.album
        newState.isPlaying = !browserState.isPaused

        // Update high-frequency properties separately
        self.currentTime = browserState.currentTime
        self.duration = browserState.duration

        newState.playbackRate = browserState.playbackRate
        newState.bundleIdentifier = browserState.bundleIdentifier
        newState.lastUpdated = Date()

        if browserState.artworkURL != lastArtworkURL {
            lastArtworkURL = browserState.artworkURL
            if let urlString = browserState.artworkURL, let url = URL(string: urlString) {
                Task {
                    if let (data, _) = try? await URLSession.shared.data(from: url) {
                        await MainActor.run {
                            self.playbackState.artwork = data
                            self.playbackState.lastUpdated = Date()
                        }
                    }
                }
            } else {
                newState.artwork = nil
            }
        }

        playbackState = newState
    }

    func play() async { server.sendCommand(BrowserMediaCommand(command: "play")) }
    func pause() async { server.sendCommand(BrowserMediaCommand(command: "pause")) }
    func togglePlay() async {
        server.sendCommand(BrowserMediaCommand(command: playbackState.isPlaying ? "pause" : "play"))
    }
    func nextTrack() async { server.sendCommand(BrowserMediaCommand(command: "next")) }
    func previousTrack() async { server.sendCommand(BrowserMediaCommand(command: "previous")) }
    func seek(to time: Double) async { server.sendCommand(BrowserMediaCommand(command: "seek", value: time)) }

    func setVolume(_ level: Double) async {}
    func toggleShuffle() async {}
    func toggleRepeat() async {}
    func setFavorite(_ favorite: Bool) async {}

    func isActive() -> Bool {
        // We consider it active if we have received a state update recently
        return Date().timeIntervalSince(playbackState.lastUpdated) < 10.0
    }

    func updatePlaybackInfo() async {
        // Handled via WebSocket push from the extension
    }
}
