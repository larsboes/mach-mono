//
//  MusicPlaybackController.swift
//  boringNotch
//
//  Extracted from MusicManager — handles media controller lifecycle,
//  transport commands, and playback state observation.
//

import AppKit
import Combine
import SwiftUI

@MainActor
@Observable
final class MusicPlaybackController {
    private var cancellables = Set<AnyCancellable>()
    private var controllerCancellables = Set<AnyCancellable>()
    private var debounceIdleTask: Task<Void, Never>?
    @ObservationIgnored public private(set) var isNowPlayingDeprecated: Bool = false
    private let mediaChecker = MediaChecker()
    var activeController: (any MediaControllerProtocol)?
    private var settings: any MediaSettings
    var isPlaying = false
    var isPlayerIdle: Bool = true
    var songTitle: String = "I'm Handsome"
    var artistName: String = "Me"
    var album: String = "Self Love"
    var bundleIdentifier: String?
    var songDuration: TimeInterval = 0
    var elapsedTime: TimeInterval = 0
    var timestampDate: Date = .init()
    var playbackRate: Double = 1
    var isShuffled: Bool = false
    var repeatMode: RepeatMode = .off
    var volume: Double = 0.5
    var volumeControlSupported: Bool = true
    var canFavoriteTrack: Bool = false
    var isFavoriteTrack: Bool = false

    private let playbackStateSubject = PassthroughSubject<PlaybackState, Never>()
    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> { playbackStateSubject.eraseToAnyPublisher() }

    private let sneakPeekSubject = PassthroughSubject<SneakPeekRequest, Never>()
    var sneakPeekPublisher: AnyPublisher<SneakPeekRequest, Never> { sneakPeekSubject.eraseToAnyPublisher() }

    nonisolated deinit {
        MainActor.assumeIsolated {
            debounceIdleTask?.cancel()
        }
    }

    var onContentChange: ((PlaybackState) -> Void)?

    // MARK: - Initialization

    init(settings: any MediaSettings) {
        self.settings = settings
        NotificationCenter.default.publisher(for: Notification.Name.mediaControllerChanged)
            .sink { [weak self] _ in
                self?.setActiveControllerBasedOnPreference()
            }
            .store(in: &cancellables)

        Task { @MainActor in
            do {
                self.isNowPlayingDeprecated = try await self.mediaChecker.checkDeprecationStatus()
                self.settings.isNowPlayingDeprecated = self.isNowPlayingDeprecated
            } catch {
                print("Failed to check deprecation status: \(error). Defaulting to false.")
                self.isNowPlayingDeprecated = false
            }
            self.setActiveControllerBasedOnPreference()
        }
    }

    func destroy() {
        debounceIdleTask?.cancel()
        cancellables.removeAll()
        controllerCancellables.removeAll()
        activeController = nil
    }

    private func createController(for type: MediaControllerType) -> (any MediaControllerProtocol)? {
        if activeController != nil {
            controllerCancellables.removeAll()
            activeController = nil
        }

        let newController: (any MediaControllerProtocol)?

        switch type {
        case .nowPlaying:
            if !isNowPlayingDeprecated {
                newController = NowPlayingController()
            } else {
                return nil
            }
        case .appleMusic:
            newController = AppleMusicController()
        case .spotify:
            newController = SpotifyController()
        case .youtubeMusic:
            newController = YouTubeMusicController()
        }

        if let controller = newController {
            controller.playbackStatePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] state in
                    guard let self = self,
                          self.activeController === controller else { return }
                    self.updateFromPlaybackState(state)
                }
                .store(in: &controllerCancellables)

            controller.progressPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] progress in
                    guard let self = self,
                          self.activeController === controller else { return }
                    if progress.currentTime != self.elapsedTime { self.elapsedTime = progress.currentTime }
                    if progress.duration != self.songDuration { self.songDuration = progress.duration }
                }
                .store(in: &controllerCancellables)
        }

        return newController
    }

    private func setActiveControllerBasedOnPreference() {
        let preferredType = settings.mediaController
        let controllerType = (isNowPlayingDeprecated && preferredType == .nowPlaying)
            ? .appleMusic
            : preferredType

        if let controller = createController(for: controllerType) {
            setActiveController(controller)
        } else if controllerType != .appleMusic, let fallback = createController(for: .appleMusic) {
            setActiveController(fallback)
        }
    }

    private func setActiveController(_ controller: any MediaControllerProtocol) {
        activeController = controller
        canFavoriteTrack = controller.supportsFavorite
        forceUpdate()
    }

    func updateFromPlaybackState(_ state: PlaybackState) {
        playbackStateSubject.send(state)

        if state.isPlaying != isPlaying {
            withAnimation(.smooth) {
                self.isPlaying = state.isPlaying
                self.updateIdleState(state: state.isPlaying)
            }

            if state.isPlaying && !state.title.isEmpty && !state.artist.isEmpty {
                emitSneakPeek()
            }
        }

        let hasContentChange = state.title != songTitle
            || state.artist != artistName
            || state.album != album
            || state.artwork != nil
            || state.bundleIdentifier != bundleIdentifier

        if hasContentChange {
            songTitle = state.title
            artistName = state.artist
            album = state.album
            onContentChange?(state)

            if !state.title.isEmpty && !state.artist.isEmpty && state.isPlaying {
                emitSneakPeek()
            }
        }

        if state.playbackRate != playbackRate { playbackRate = state.playbackRate }
        if state.isShuffled != isShuffled { isShuffled = state.isShuffled }
        if state.repeatMode != repeatMode { repeatMode = state.repeatMode }
        if state.volume != volume { volume = state.volume }
        if state.isFavorite != isFavoriteTrack { isFavoriteTrack = state.isFavorite }
        timestampDate = state.lastUpdated

        if state.bundleIdentifier != bundleIdentifier {
            bundleIdentifier = state.bundleIdentifier
            volumeControlSupported = activeController?.supportsVolumeControl ?? false
        }
    }

    private func updateIdleState(state: Bool) {
        if state {
            isPlayerIdle = false
            debounceIdleTask?.cancel()
        } else {
            debounceIdleTask?.cancel()
            debounceIdleTask = Task { [weak self] in
                guard let self = self else { return }
                try? await Task.sleep(for: .seconds(self.settings.waitInterval))
                withAnimation {
                    self.isPlayerIdle = !self.isPlaying
                }
            }
        }
    }

    private func emitSneakPeek() {
        if isPlaying && settings.enableSneakPeek {
            sneakPeekSubject.send(
                SneakPeekRequest(style: settings.sneakPeekStyles, type: .music)
            )
        }
    }

    // MARK: - Playback Position

    func estimatedPlaybackPosition(at date: Date = Date()) -> TimeInterval {
        guard isPlaying else { return min(elapsedTime, songDuration) }
        let timeDifference = date.timeIntervalSince(timestampDate)
        let estimated = elapsedTime + (timeDifference * playbackRate)
        return min(max(0, estimated), songDuration)
    }

    // MARK: - Transport Controls

    func playPause() { Task { await activeController?.togglePlay() } }
    func play() { Task { await activeController?.play() } }
    func pause() { Task { await activeController?.pause() } }
    func togglePlay() { Task { await activeController?.togglePlay() } }
    func nextTrack() { Task { await activeController?.nextTrack() } }
    func previousTrack() { Task { await activeController?.previousTrack() } }
    func seek(to position: TimeInterval) { Task { await activeController?.seek(to: position) } }
    func toggleShuffle() { Task { await activeController?.toggleShuffle() } }
    func toggleRepeat() { Task { await activeController?.toggleRepeat() } }

    func setVolume(to level: Double) {
        if let controller = activeController {
            Task { await controller.setVolume(level) }
        }
    }

    func skip(seconds: TimeInterval) {
        let newPos = min(max(0, elapsedTime + seconds), songDuration)
        seek(to: newPos)
    }

    func setFavorite(_ favorite: Bool) {
        guard canFavoriteTrack, let controller = activeController else { return }
        Task { @MainActor in
            await controller.setFavorite(favorite)
            try? await Task.sleep(for: .milliseconds(150))
            await controller.updatePlaybackInfo()
        }
    }

    func toggleFavoriteTrack() {
        guard canFavoriteTrack else { return }
        setFavorite(!isFavoriteTrack)
    }

}
