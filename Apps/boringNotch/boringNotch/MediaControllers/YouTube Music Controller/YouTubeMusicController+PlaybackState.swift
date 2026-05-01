//
//  YouTubeMusicController+PlaybackState.swift
//  boringNotch
//
//  Extracted playback state updates from YouTubeMusicController.
//

import Foundation

extension YouTubeMusicController {
    func updatePlaybackState(with response: PlaybackResponse) async {
        var newState = playbackState

        newState.isPlaying = !response.isPaused

        if let title = response.title {
            newState.title = title
        }

        if let artist = response.artist {
            newState.artist = artist
        }

        if let album = response.album {
            newState.album = album
        }

        if let elapsed = response.elapsedSeconds {
            self.currentTime = elapsed
        }

        if let duration = response.songDuration {
            self.duration = duration
        }

        newState.lastUpdated = Date()

        if let shuffled = response.isShuffled {
            newState.isShuffled = shuffled
        }

        if let mode = response.repeatMode {
            switch mode {
            case 0: newState.repeatMode = .off
            case 1: newState.repeatMode = .all
            case 2: newState.repeatMode = .one
            default: break
            }
        }

        if let volume = response.volume {
            newState.volume = volume / 100.0
        }

        if newState != playbackState {
            playbackState = newState

            artworkFetchTask?.cancel()
            artworkFetchTask = nil

            if let artworkURL = response.imageSrc,
               let url = URL(string: artworkURL) {
                artworkFetchTask = Task {
                    do {
                        let data = try await imageService.fetchImageData(from: url)
                        await MainActor.run { [weak self] in
                            self?.playbackState.artwork = data
                        }
                    } catch { /* ignore */ }
                }
            }
        }
    }

    func resetPlaybackState() {
        playbackState = PlaybackState(
            bundleIdentifier: configuration.bundleIdentifier,
            isPlaying: false
        )
    }

    func updateRepeatMode(_ mode: String) {
        var target: RepeatMode?
        switch mode {
            case "NONE": target = .off
            case "ALL": target = .all
            case "ONE": target = .one
            default: break
        }
        if let target, target != playbackState.repeatMode { playbackState.repeatMode = target }
    }
}
