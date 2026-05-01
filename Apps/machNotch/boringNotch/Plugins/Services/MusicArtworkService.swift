//
//  MusicArtworkService.swift
//  boringNotch
//
//  Extracted from MusicManager — handles album art resolution,
//  app icon fallback, color averaging, and flip animations.
//

import AppKit
import Combine
import SwiftUI

let defaultImage: NSImage = .init(
    systemSymbolName: "heart.fill",
    accessibilityDescription: "Album Art"
)!

@MainActor
@Observable
final class MusicArtworkService {
    // MARK: - Properties

    var albumArt: NSImage = defaultImage
    var avgColor: NSColor = .white
    var usingAppIconForArtwork: Bool = false
    var isFlipping: Bool = false

    private var artworkData: Data?
    private var albumArtTask: Task<Void, Error>?
    private var flipTask: Task<Void, Never>?
    private let settings: any MediaSettings

    // Track the last values when artwork was changed to avoid redundant updates
    private var lastArtworkTitle: String = "I'm Handsome"
    private var lastArtworkArtist: String = "Me"
    private var lastArtworkAlbum: String = "Self Love"
    private var lastArtworkBundleIdentifier: String?

    private let avgColorSubject = PassthroughSubject<NSColor, Never>()
    var avgColorPublisher: AnyPublisher<NSColor, Never> {
        avgColorSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    init(settings: any MediaSettings) {
        self.settings = settings
    }

    nonisolated deinit {
        MainActor.assumeIsolated {
            albumArtTask?.cancel()
            flipTask?.cancel()
        }
    }

    // MARK: - Public API

    /// Called by MusicManager when a content change is detected in the playback state.
    func handleContentChange(_ state: PlaybackState) {
        let titleChanged = state.title != lastArtworkTitle
        let artistChanged = state.artist != lastArtworkArtist
        let albumChanged = state.album != lastArtworkAlbum
        let bundleChanged = state.bundleIdentifier != lastArtworkBundleIdentifier
        let artworkChanged = state.artwork != nil && state.artwork != artworkData

        let hasContentChange = titleChanged || artistChanged || albumChanged || artworkChanged || bundleChanged
        guard hasContentChange else { return }

        triggerFlipAnimation()

        if artworkChanged || state.artwork == nil {
            lastArtworkTitle = state.title
            lastArtworkArtist = state.artist
            lastArtworkAlbum = state.album
            lastArtworkBundleIdentifier = state.bundleIdentifier
        }

        var newAlbumArt: NSImage = defaultImage
        var usingAppIcon = false

        if artworkChanged, let artwork = state.artwork, let artworkImage = NSImage(data: artwork) {
            newAlbumArt = artworkImage
        } else if let appIcon = AppIconAsNSImage(for: state.bundleIdentifier) {
            newAlbumArt = appIcon
            usingAppIcon = true
        }

        triggerFlipAnimation()

        albumArtTask?.cancel()
        albumArtTask = Task(priority: .userInitiated) { [weak self] in
            if usingAppIcon {
                try? await Task.sleep(for: .milliseconds(400))
            }

            guard let self = self, !Task.isCancelled else { return }

            await MainActor.run {
                self.albumArt = newAlbumArt
                self.usingAppIconForArtwork = usingAppIcon
                self.artworkData = state.artwork

                if self.settings.coloredSpectrogram {
                    self.calculateAverageColor()
                }
            }
        }
    }

    func calculateAverageColor() {
        albumArt.averageColor { [weak self] color in
            DispatchQueue.main.async {
                let newColor = color ?? .white
                self?.avgColor = newColor
                self?.avgColorSubject.send(newColor)
            }
        }
    }

    func updateAlbumArt(newAlbumArt: NSImage) {
        withAnimation(.smooth) {
            self.albumArt = newAlbumArt
            if settings.coloredSpectrogram {
                self.calculateAverageColor()
            }
        }
    }

    func destroy() {
        albumArtTask?.cancel()
        flipTask?.cancel()
    }

    // MARK: - Private

    private func triggerFlipAnimation() {
        flipTask?.cancel()
        flipTask = Task { [weak self] in
            self?.isFlipping = true
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            self?.isFlipping = false
        }
    }
}
