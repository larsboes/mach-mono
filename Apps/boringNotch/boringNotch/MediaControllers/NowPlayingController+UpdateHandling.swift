//
//  NowPlayingController+UpdateHandling.swift
//  boringNotch
//
//  Extracted from NowPlayingController — adapter update parsing.
//

import Foundation

extension NowPlayingController {

    // MARK: - Update Handling

    func handleAdapterUpdate(_ update: NowPlayingUpdate) async {
        let payload = update.payload
        let diff = update.diff ?? false

        var newPlaybackState = PlaybackState(bundleIdentifier: playbackState.bundleIdentifier)
        newPlaybackState.title = payload.title ?? (diff ? self.playbackState.title : "")
        newPlaybackState.artist = payload.artist ?? (diff ? self.playbackState.artist : "")
        newPlaybackState.album = payload.album ?? (diff ? self.playbackState.album : "")
        self.duration = payload.duration ?? (diff ? self.duration : 0)

        if let elapsedTime = payload.elapsedTime {
            self.currentTime = elapsedTime
        } else if diff {
            if payload.playing == false {
                let timeSinceLastUpdate = Date().timeIntervalSince(self.playbackState.lastUpdated)
                self.currentTime += (self.playbackState.playbackRate * timeSinceLastUpdate)
            } else {
                self.currentTime = self.currentTime
            }
        } else {
            self.currentTime = 0
        }

        if let shuffleMode = payload.shuffleMode {
            newPlaybackState.isShuffled = shuffleMode != 1
        } else if !diff {
            newPlaybackState.isShuffled = false
        } else {
            newPlaybackState.isShuffled = self.playbackState.isShuffled
        }
        if let repeatModeValue = payload.repeatMode {
            newPlaybackState.repeatMode = RepeatMode(rawValue: repeatModeValue) ?? .off
        } else if !diff {
            newPlaybackState.repeatMode = .off
        } else {
            newPlaybackState.repeatMode = self.playbackState.repeatMode
        }

        if let artworkDataString = payload.artworkData {
            newPlaybackState.artwork = Data(
                base64Encoded: artworkDataString.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } else if !diff {
            newPlaybackState.artwork = nil
        }

        if let dateString = payload.timestamp,
           let date = ISO8601DateFormatter().date(from: dateString) {
            newPlaybackState.lastUpdated = date
        } else if !diff {
            newPlaybackState.lastUpdated = Date()
        } else {
            newPlaybackState.lastUpdated = self.playbackState.lastUpdated
        }

        newPlaybackState.playbackRate = payload.playbackRate ?? (diff ? self.playbackState.playbackRate : 1.0)
        newPlaybackState.isPlaying = payload.playing ?? (diff ? self.playbackState.isPlaying : false)
        newPlaybackState.bundleIdentifier = (
            payload.parentApplicationBundleIdentifier ??
            payload.bundleIdentifier ??
            (diff ? self.playbackState.bundleIdentifier : "")
        )
        newPlaybackState.volume = payload.volume ?? (diff ? self.playbackState.volume : 0.5)

        if isBrowser(newPlaybackState.bundleIdentifier) {
            var rawTitle = newPlaybackState.title
            var rawArtist = newPlaybackState.artist

            if rawTitle.hasSuffix(" - YouTube") {
                rawTitle = String(rawTitle.dropLast(" - YouTube".count))
            }

            if rawTitle.contains(" - ") {
                let components = rawTitle.components(separatedBy: " - ")
                if components.count >= 2 {
                    rawArtist = components[0].trimmingCharacters(in: .whitespaces)
                    rawTitle = components.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespaces)
                }
            }

            newPlaybackState.title = rawTitle
            newPlaybackState.artist = rawArtist

            if self.duration > 0 && abs(self.duration - self.currentTime) < 0.1 {
                self.duration = 0
            }
        }

        self.playbackState = newPlaybackState
    }

    func isBrowser(_ bundleID: String) -> Bool {
        let lower = bundleID.lowercased()
        return lower.contains("chrome") ||
               lower.contains("safari") ||
               lower.contains("brave") ||
               lower.contains("edgemac") ||
               lower.contains("firefox") ||
               lower.contains("thebrowser")
    }
}
