//
//  YouTubeMusicController+WebSocket.swift
//  boringNotch
//
//  Extracted WebSocket handling from YouTubeMusicController.
//

import Foundation

extension YouTubeMusicController {
    func setupWebSocketIfPossible(token: String) async {
        guard let wsURL = WebSocketURLBuilder.buildURL(from: configuration.baseURL) else {
            print("[YouTubeMusicController] Failed to build WebSocket URL")
            return
        }

        let client = YouTubeMusicWebSocketClient(
            onMessage: { [weak self] data in
                await self?.handleWebSocketMessage(data)
            },
            onDisconnect: { [weak self] in
                await self?.handleWebSocketDisconnect()
            }
        )

        do {
            try await client.connect(to: wsURL, with: token)
            webSocketClient = client
            stopPeriodicUpdates() // WebSocket will provide real-time updates
            reconnectDelay = configuration.reconnectDelay.lowerBound
        } catch {
            print("[YouTubeMusicController] WebSocket connection failed: \(error)")
            await scheduleReconnect()
        }
    }

    func handleWebSocketMessage(_ data: Data) async {
        guard let message = WebSocketMessage(from: data) else {
            if let response = try? JSONDecoder().decode(PlaybackResponse.self, from: data) {
                await updatePlaybackState(with: response)
            }
            return
        }
        switch message.type {
        case .playerInfo, .videoChanged, .playerStateChanged:
            if let data = message.extractData(),
               let response = PlaybackResponse.from(websocketData: data) {
                await updatePlaybackState(with: response)
            }

        case .positionChanged:
            guard let data = message.extractData() else { return }

            var position: Double?
            if let pos = data["position"] as? Double {
                position = pos
            } else if let elapsed = data["elapsedSeconds"] as? Double {
                position = elapsed
            }
            guard let newPosition = position else { return }

            self.currentTime = newPosition
            playbackState.lastUpdated = Date()

        case .repeatChanged:
            guard let data = message.extractData() else { return }
            var copy = playbackState

            if let repeatStr = data["repeat"] as? String {
                switch repeatStr.uppercased() {
                case "NONE": copy.repeatMode = .off
                case "ALL": copy.repeatMode = .all
                case "ONE": copy.repeatMode = .one
                default: break
                }
            }
            copy.lastUpdated = Date()
            if copy != playbackState { playbackState = copy }

        case .shuffleChanged:
            guard let data = message.extractData() else { return }
            var copy = playbackState
            if let shuffle = data["shuffle"] as? Bool { copy.isShuffled = shuffle } else if let shuffle = data["isShuffled"] as? Bool { copy.isShuffled = shuffle }
            copy.lastUpdated = Date()
            if copy != playbackState { playbackState = copy }

        case .volumeChanged:
            guard let data = message.extractData() else { return }
            var copy = playbackState
            if let volume = data["volume"] as? Double {
                copy.volume = volume / 100.0
            } else if let volume = data["volume"] as? Int {
                copy.volume = Double(volume) / 100.0
            }
            copy.lastUpdated = Date()
            if copy != playbackState { playbackState = copy }
        }
    }

    func handleWebSocketDisconnect() async {
        webSocketClient = nil
        await startPeriodicUpdates() // Fallback to polling
        await scheduleReconnect()
    }

    func scheduleReconnect() async {
        try? await Task.sleep(for: .seconds(reconnectDelay))
        reconnectDelay = min(reconnectDelay * 2, configuration.reconnectDelay.upperBound)

        if isActive() {
            await initializeIfAppActive()
        }
    }
}
