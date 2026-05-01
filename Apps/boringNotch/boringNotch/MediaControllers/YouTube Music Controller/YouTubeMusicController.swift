//
//  YouTubeMusicController.swift
//  boringNotch
//
//  Created By Alexander on 2025-03-30.
//  Modified by Pranav on 2025-06-16.
//

import Foundation
import Combine
import SwiftUI

@Observable
@MainActor
final class YouTubeMusicController: MediaControllerProtocol {
    // MARK: - Properties
    var playbackState = PlaybackState(
        bundleIdentifier: YouTubeMusicConfiguration.default.bundleIdentifier
    ) {
        didSet { _playbackStateSubject.send(playbackState) }
    }

    var currentTime: Double = 0 {
        didSet { _progressSubject.send((currentTime, duration)) }
    }
    var duration: Double = 0 {
        didSet { _progressSubject.send((currentTime, duration)) }
    }

    var artworkFetchTask: Task<Void, Never>?

    @ObservationIgnored
    private let _playbackStateSubject = CurrentValueSubject<PlaybackState, Never>(
        PlaybackState(bundleIdentifier: YouTubeMusicConfiguration.default.bundleIdentifier)
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
        return true
    }

    var supportsFavorite: Bool { true }

    func setFavorite(_ favorite: Bool) async {
        do {
            let token = try await authManager.authenticate()
            if favorite && !playbackState.isFavorite {
                _ = try await httpClient.toggleLike(token: token)
            } else if !favorite && playbackState.isFavorite {
                _ = try await httpClient.toggleLike(token: token)
            }
            try? await Task.sleep(for: .milliseconds(150))
            await updatePlaybackInfo()
        } catch {
            print("[YouTubeMusicController] Failed to set favorite: \(error)")
        }
    }

    // MARK: - Properties
    let configuration: YouTubeMusicConfiguration
    let httpClient: YouTubeMusicHTTPClient
    let authManager: YouTubeMusicAuthManager
    let imageService: ImageServiceProtocol
    var webSocketClient: YouTubeMusicWebSocketClient?

    private var updateTimer: Timer?
    private var appStateObserver: Task<Void, Never>?
    var reconnectDelay: TimeInterval = 1.0

    // MARK: - Initialization
    init(configuration: YouTubeMusicConfiguration = .default, imageService: ImageServiceProtocol = ImageService()) {
        self.configuration = configuration
        self.httpClient = YouTubeMusicHTTPClient(baseURL: configuration.baseURL)
        self.authManager = YouTubeMusicAuthManager(httpClient: httpClient)
        self.imageService = imageService

        setupAppStateObserver()

        Task {
            await initializeIfAppActive()
        }
    }

    nonisolated deinit {
        MainActor.assumeIsolated {
            artworkFetchTask?.cancel()
            appStateObserver?.cancel()
        }
    }

    // MARK: - MediaControllerProtocol Implementation
    func play() async { await sendCommand(endpoint: "/play", method: "POST") }
    func pause() async { await sendCommand(endpoint: "/pause", method: "POST") }

    func togglePlay() async {
        if !isActive() { launchApp() }
        await sendCommand(endpoint: "/toggle-play", method: "POST")
    }

    func nextTrack() async { await sendCommand(endpoint: "/next", method: "POST") }
    func previousTrack() async { await sendCommand(endpoint: "/previous", method: "POST") }

    func seek(to time: Double) async {
        let payload = ["seconds": time]
        await sendCommand(endpoint: "/seek-to", method: "POST", body: payload)
    }

    func setVolume(_ level: Double) async {
        let clampedLevel = max(0.0, min(1.0, level))
        let volumePercentage = Int(clampedLevel * 100)
        let payload = ["volume": volumePercentage]
        await sendCommand(endpoint: "/volume", method: "POST", body: payload)
    }
    func fetchShuffleState() async { await sendCommand(endpoint: "/shuffle", method: "GET", refresh: false) }
    func fetchRepeatMode() async { await sendCommand(endpoint: "/repeat-mode", method: "GET", refresh: false) }

    func toggleShuffle() async { await sendCommand(endpoint: "/shuffle", method: "POST") }
    func toggleRepeat() async { await sendCommand(endpoint: "/switch-repeat", method: "POST") }

    nonisolated func isActive() -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == configuration.bundleIdentifier
        }
    }

    func updatePlaybackInfo() async {
        guard isActive() else {
            resetPlaybackState()
            return
        }

        do {
            let token = try await authManager.authenticate()
            let response = try await httpClient.getPlaybackInfo(token: token)
            await updatePlaybackState(with: response)
            do {
                let likeResp = try await httpClient.getLikeState(token: token)
                var newState = playbackState
                    if let state = likeResp.state {
                        switch state.uppercased() {
                        case "LIKE":
                            newState.isFavorite = true
                        case "DISLIKE":
                            newState.isFavorite = false
                        default:
                            newState.isFavorite = false
                        }
                    } else {
                        newState.isFavorite = false
                    }
                playbackState = newState
            } catch {
                // Don't treat it as an error if the like endpoint doesn't exist
            }
        } catch YouTubeMusicError.authenticationRequired {
            await authManager.invalidateToken()
        } catch {
            print("[YouTubeMusicController] Failed to update playback info: \(error)")
        }
    }

    // MARK: - App State Observation
    private func setupAppStateObserver() {
        appStateObserver = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    let launchNotifications = NSWorkspace.shared.notificationCenter.notifications(
                        named: NSWorkspace.didLaunchApplicationNotification
                    )
                    for await notification in launchNotifications {
                        await self?.handleAppLaunched(notification)
                    }
                }
                group.addTask {
                    let terminateNotifications = NSWorkspace.shared.notificationCenter.notifications(
                        named: NSWorkspace.didTerminateApplicationNotification
                    )
                    for await notification in terminateNotifications {
                        await self?.handleAppTerminated(notification)
                    }
                }
            }
        }
    }

    private func handleAppLaunched(_ notification: Notification) async {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == configuration.bundleIdentifier else { return }
        await initializeIfAppActive()
    }

    private func handleAppTerminated(_ notification: Notification) async {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == configuration.bundleIdentifier else { return }
        Task { @MainActor in
            stopPeriodicUpdates()
            appStateObserver?.cancel()
        }
        Task {
            await webSocketClient?.disconnect()
            webSocketClient = nil
        }
        resetPlaybackState()
    }

    func initializeIfAppActive() async {
        guard isActive() else { return }
        do {
            let token = try await authManager.authenticate()
            await setupWebSocketIfPossible(token: token)
            await startPeriodicUpdates()
            await updatePlaybackInfo()
        } catch {
            print("[YouTubeMusicController] Failed to initialize: \(error)")
            await scheduleReconnect()
        }
    }

    func startPeriodicUpdates() async {
        guard isActive() && webSocketClient == nil else { return }
        stopPeriodicUpdates()
        updateTimer = Timer.scheduledTimer(withTimeInterval: configuration.updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updatePlaybackInfo()
            }
        }
    }

    func stopPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    func pollPlaybackState() async {
        if !isActive() { return }
        await fetchRepeatMode()
        await fetchShuffleState()
        await updatePlaybackInfo()
    }

    private func sendCommand(
        endpoint: String,
        method: String = "POST",
        body: (any Codable & Sendable)? = nil,
        refresh: Bool = true
    ) async {
        do {
            let token = try await authManager.authenticate()
            let data = try await httpClient.sendCommand(
                endpoint: endpoint, method: method, body: body, token: token
            )
            if endpoint == "/shuffle" {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let shuffleState = json["state"] as? Bool {
                    playbackState.isShuffled = shuffleState
                } else {
                    playbackState.isShuffled = !playbackState.isShuffled
                }
            } else if endpoint == "/repeat-mode" {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let mode = json["mode"] as? String { updateRepeatMode(mode) }
                }
            } else if endpoint == "/switch-repeat" {
                let nextMode: RepeatMode
                switch playbackState.repeatMode {
                case .off: nextMode = .all
                case .all: nextMode = .one
                case .one: nextMode = .off
                }
                playbackState.repeatMode = nextMode
            } else if refresh && webSocketClient == nil {
                try? await Task.sleep(for: .milliseconds(100))
                await updatePlaybackInfo()
            }
        } catch YouTubeMusicError.authenticationRequired {
            await authManager.invalidateToken()
        } catch {
            print("[YouTubeMusicController] Command failed: \(error)")
        }
    }

    private func launchApp() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: configuration.bundleIdentifier) else { return }
        NSWorkspace.shared.open(url)
    }
}
