//
//  NowPlayingController.swift
//  boringNotch
//
//  Created by Alexander on 2025-03-29.
//

import AppKit
import Combine
import Foundation

@Observable
@MainActor
final class NowPlayingController: MediaControllerProtocol {
    func updatePlaybackInfo() async {
        await fetchFavoriteStateIfSupported()
    }

    // MARK: - Properties
    var playbackState: PlaybackState = .init(
        bundleIdentifier: "com.apple.Music"
    ) {
        didSet { _playbackStateSubject.send(playbackState) }
    }

    var currentTime: Double = 0 {
        didSet { _progressSubject.send((currentTime, duration)) }
    }
    var duration: Double = 0 {
        didSet { _progressSubject.send((currentTime, duration)) }
    }

    @ObservationIgnored
    private let _playbackStateSubject = CurrentValueSubject<PlaybackState, Never>(
        .init(bundleIdentifier: "com.apple.Music")
    )

    @ObservationIgnored
    private let _progressSubject = PassthroughSubject<(currentTime: Double, duration: Double), Never>()

    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> {
        _playbackStateSubject.eraseToAnyPublisher()
    }

    var progressPublisher: AnyPublisher<(currentTime: Double, duration: Double), Never> {
        _progressSubject.eraseToAnyPublisher()
    }

    var supportsVolumeControl: Bool {
        let bundleID = playbackState.bundleIdentifier
        return bundleID == "com.apple.Music" || bundleID == "com.spotify.client"
    }

    var supportsFavorite: Bool {
        let bundleID = playbackState.bundleIdentifier
        return bundleID == "com.apple.Music"
    }

    func setFavorite(_ favorite: Bool) async {
        let bundleID = playbackState.bundleIdentifier
        if bundleID == "com.apple.Music" {
            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music")
            if !runningApps.isEmpty {
                let script = """
                tell application "Music"
                    try
                        set favorited of current track to \(favorite ? "true" : "false")
                    end try
                end tell
                """
                try? await AppleScriptHelper.executeVoid(script)
            }
        }
        try? await Task.sleep(for: .milliseconds(150))
        await updatePlaybackInfo()
    }

    private var lastMusicItem:
        (title: String, artist: String, album: String, duration: TimeInterval, artworkData: Data?)?

    // MARK: - Media Remote Functions
    private let mediaRemoteBundle: CFBundle
    private let MRMediaRemoteSendCommandFunction: @convention(c) (Int, AnyObject?) -> Void
    private let MRMediaRemoteSetElapsedTimeFunction: @convention(c) (Double) -> Void
    private let MRMediaRemoteSetShuffleModeFunction: @convention(c) (Int) -> Void
    private let MRMediaRemoteSetRepeatModeFunction: @convention(c) (Int) -> Void

    @ObservationIgnored nonisolated(unsafe) private var process: Process?
    @ObservationIgnored nonisolated(unsafe) private var pipeHandler: JSONLinesPipeHandler?
    @ObservationIgnored nonisolated(unsafe) private var streamTask: Task<Void, Never>?

    // MARK: - Initialization
    init?() {
        guard
            let bundle = CFBundleCreate(
                kCFAllocatorDefault,
                NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")),
            let MRMediaRemoteSendCommandPointer = CFBundleGetFunctionPointerForName(
                bundle, "MRMediaRemoteSendCommand" as CFString),
            let MRMediaRemoteSetElapsedTimePointer = CFBundleGetFunctionPointerForName(
                bundle, "MRMediaRemoteSetElapsedTime" as CFString),
            let MRMediaRemoteSetShuffleModePointer = CFBundleGetFunctionPointerForName(
                bundle, "MRMediaRemoteSetShuffleMode" as CFString),
            let MRMediaRemoteSetRepeatModePointer = CFBundleGetFunctionPointerForName(
                bundle, "MRMediaRemoteSetRepeatMode" as CFString)
        else { return nil }

        mediaRemoteBundle = bundle
        MRMediaRemoteSendCommandFunction = unsafeBitCast(
            MRMediaRemoteSendCommandPointer, to: (@convention(c) (Int, AnyObject?) -> Void).self)
        MRMediaRemoteSetElapsedTimeFunction = unsafeBitCast(
            MRMediaRemoteSetElapsedTimePointer, to: (@convention(c) (Double) -> Void).self)
        MRMediaRemoteSetShuffleModeFunction = unsafeBitCast(
            MRMediaRemoteSetShuffleModePointer, to: (@convention(c) (Int) -> Void).self)
        MRMediaRemoteSetRepeatModeFunction = unsafeBitCast(
            MRMediaRemoteSetRepeatModePointer, to: (@convention(c) (Int) -> Void).self)

        Task { await setupNowPlayingObserver() }
    }

    deinit {
        streamTask?.cancel()
        if let pipeHandler = self.pipeHandler {
            Task { await pipeHandler.close() }
        }
        if let process = self.process {
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
            }
        }
        self.process = nil
        self.pipeHandler = nil
    }

    // MARK: - Protocol Implementation
    func play() async { MRMediaRemoteSendCommandFunction(0, nil) }
    func pause() async { MRMediaRemoteSendCommandFunction(1, nil) }
    func togglePlay() async { MRMediaRemoteSendCommandFunction(2, nil) }
    func nextTrack() async { MRMediaRemoteSendCommandFunction(4, nil) }
    func previousTrack() async { MRMediaRemoteSendCommandFunction(5, nil) }

    func seek(to time: Double) async {
        MRMediaRemoteSetElapsedTimeFunction(time)
    }

    func isActive() -> Bool { return true }

    func toggleShuffle() async {
        MRMediaRemoteSetShuffleModeFunction(playbackState.isShuffled ? 1 : 3)
        playbackState.isShuffled.toggle()
    }

    func toggleRepeat() async {
        let newRepeatMode = (playbackState.repeatMode == .off) ? 3 : (playbackState.repeatMode.rawValue - 1)
        playbackState.repeatMode = RepeatMode(rawValue: newRepeatMode) ?? .off
        MRMediaRemoteSetRepeatModeFunction(newRepeatMode)
    }

    func setVolume(_ level: Double) async {
        let clampedLevel = max(0.0, min(1.0, level))
        let volumePercentage = Int(clampedLevel * 100)
        let bundleID = playbackState.bundleIdentifier
        if !bundleID.isEmpty {
            if bundleID == "com.apple.Music" {
                let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music")
                if !runningApps.isEmpty {
                    let script = "tell application \"Music\" to set sound volume to \(volumePercentage)"
                    try? await AppleScriptHelper.executeVoid(script)
                }
            } else if bundleID == "com.spotify.client" {
                let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client")
                if !runningApps.isEmpty {
                    let script = "tell application \"Spotify\" to set sound volume to \(volumePercentage)"
                    try? await AppleScriptHelper.executeVoid(script)
                }
            }
        }
        playbackState.volume = clampedLevel
    }

    // MARK: - Setup
    private func setupNowPlayingObserver() async {
        let process = Process()
        guard
            let scriptURL = Bundle.main.url(forResource: "mediaremote-adapter", withExtension: "pl"),
            let frameworkPath = Bundle.main.privateFrameworksPath?.appending("/MediaRemoteAdapter.framework")
        else {
            assertionFailure("Could not find mediaremote-adapter.pl script or framework path")
            return
        }
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [scriptURL.path, frameworkPath, "stream"]
        let pipeHandler = JSONLinesPipeHandler()
        process.standardOutput = await pipeHandler.getPipe()
        self.process = process
        self.pipeHandler = pipeHandler

        do {
            try process.run()
            streamTask = Task { [weak self] in
                await self?.processJSONStream()
            }
        } catch {
            assertionFailure("Failed to launch mediaremote-adapter.pl: \(error)")
        }
    }

    private func processJSONStream() async {
        guard let pipeHandler = self.pipeHandler else { return }
        await pipeHandler.readJSONLines(as: NowPlayingUpdate.self) { [weak self] update in
            await self?.handleAdapterUpdate(update)
        }
    }

    private func fetchFavoriteStateIfSupported() async {
        let bundleID = playbackState.bundleIdentifier
        if bundleID == "com.apple.Music" {
            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music")
            guard !runningApps.isEmpty else { return }
            let script = """
            tell application "Music"
                try
                    return favorited of current track
                on error
                    return false
                end try
            end tell
            """
            if let result = try? await AppleScriptHelper.execute(script) {
                var updated = self.playbackState
                updated.isFavorite = result.booleanValue
                self.playbackState = updated
            }
        }
    }
}
