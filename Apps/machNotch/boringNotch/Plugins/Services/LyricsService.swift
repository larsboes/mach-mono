//
//  LyricsService.swift
//  boringNotch
//
//  Extracted from MusicManager for better separation of concerns.
//

import AppKit
import Foundation

/// Service responsible for fetching and parsing lyrics for the currently playing track.
@MainActor
@Observable
class LyricsService: LyricsServiceProtocol {
    var currentLyrics: String = ""
    var isFetchingLyrics: Bool = false
    var syncedLyrics: [(time: Double, text: String)] = []

    private var lyricsCache: [String: (plain: String, synced: [(time: Double, text: String)])] = [:]
    private var currentFetchTask: Task<Void, Never>?

    init() {}

    nonisolated deinit {
        MainActor.assumeIsolated {
            currentFetchTask?.cancel()
        }
    }

    // MARK: - Public API

    func fetchLyrics(bundleIdentifier: String?, title: String, artist: String) async {
        currentFetchTask?.cancel()

        guard !title.isEmpty else {
            clearLyrics()
            return
        }

        let cacheKey = cacheKey(title: title, artist: artist)
        if let cached = lyricsCache[cacheKey] {
            currentLyrics = cached.plain
            syncedLyrics = cached.synced
            isFetchingLyrics = false
            return
        }

        isFetchingLyrics = true
        currentLyrics = ""
        syncedLyrics = []

        let task = Task { [weak self] in
            guard let self = self else { return }

            if let bundleIdentifier = bundleIdentifier, bundleIdentifier.contains("com.apple.Music") {
                if let lyrics = await self.fetchAppleMusicLyrics() {
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        self.currentLyrics = lyrics
                        self.syncedLyrics = []
                        self.isFetchingLyrics = false
                        self.lyricsCache[cacheKey] = (plain: lyrics, synced: [])
                    }
                    return
                }
            }

            guard !Task.isCancelled else { return }
            let webResult = await self.fetchLyricsFromWeb(title: title, artist: artist)

            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.currentLyrics = webResult.plain
                self.syncedLyrics = webResult.synced
                self.isFetchingLyrics = false
                if !webResult.plain.isEmpty {
                    self.lyricsCache[cacheKey] = webResult
                }
            }
        }

        currentFetchTask = task
        await task.value
    }

    func clearLyrics() {
        currentFetchTask?.cancel()
        currentFetchTask = nil
        currentLyrics = ""
        syncedLyrics = []
        isFetchingLyrics = false
    }

    func lyricLine(at elapsed: Double) -> String {
        guard !syncedLyrics.isEmpty else { return currentLyrics }
        var low = 0
        var high = syncedLyrics.count - 1
        var idx = 0
        while low <= high {
            let mid = (low + high) / 2
            if syncedLyrics[mid].time <= elapsed {
                idx = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return syncedLyrics[idx].text
    }

    // MARK: - Private Methods

    private func cacheKey(title: String, artist: String) -> String {
        "\(normalizedQuery(title))|\(normalizedQuery(artist))"
    }

    private func fetchAppleMusicLyrics() async -> String? {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music")
        guard !runningApps.isEmpty else { return nil }

        let script = """
        tell application "Music"
            if it is running then
                if player state is playing or player state is paused then
                    try
                        set l to lyrics of current track
                        if l is missing value then
                            return ""
                        else
                            return l
                        end if
                    on error
                        return ""
                    end try
                else
                    return ""
                end if
            else
                return ""
            end if
        end tell
        """

        do {
            if let result = try await AppleScriptHelper.execute(script),
               let lyricsString = result.stringValue,
               !lyricsString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return lyricsString.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            // Fall through to return nil
        }
        return nil
    }
}
