//
//  FullscreenMediaDetection.swift
//  machNotch
//
//  Reauthored fullscreen-media detection policy for MIT-readiness.
//

import Foundation
import MacroVisionKit

public struct FullscreenSpaceSnapshot: Equatable {
    public let runningApps: [String]
    public let screenUUID: String?

    public init(runningApps: [String], screenUUID: String?) {
        self.runningApps = runningApps
        self.screenUUID = screenUUID
    }

    public init(_ space: MacroVisionKit.FullScreenMonitor.SpaceInfo) {
        self.init(runningApps: space.runningApps, screenUUID: space.screenUUID)
    }
}

public enum FullscreenMediaDetectionPolicy {
    public static func statusByScreen(
        spaces: [FullscreenSpaceSnapshot],
        hideOption: HideNotchOption,
        nowPlayingBundleIdentifier: String?
    ) -> [String: Bool] {
        spaces.reduce(into: [:]) { result, space in
            guard let uuid = space.screenUUID else { return }
            result[uuid] = shouldMarkFullscreen(
                space: space,
                hideOption: hideOption,
                nowPlayingBundleIdentifier: nowPlayingBundleIdentifier
            )
        }
    }

    private static func shouldMarkFullscreen(
        space: FullscreenSpaceSnapshot,
        hideOption: HideNotchOption,
        nowPlayingBundleIdentifier: String?
    ) -> Bool {
        guard hideOption == .nowPlayingOnly, let bundle = nowPlayingBundleIdentifier else {
            return true
        }
        return space.runningApps.contains(bundle)
    }
}

@MainActor
@Observable public final class FullscreenMediaDetector {
    public typealias SpaceStreamProvider = () async -> AsyncStream<[MacroVisionKit.FullScreenMonitor.SpaceInfo]>

    public var fullscreenStatus: [String: Bool] = [:]

    private let musicService: any MusicServiceProtocol
    private let settings: any MediaSettings
    private let streamProvider: SpaceStreamProvider
    @ObservationIgnored nonisolated(unsafe) private var monitorTask: Task<Void, Never>?

    public init(
        musicService: any MusicServiceProtocol,
        settings: any MediaSettings,
        streamProvider: @escaping SpaceStreamProvider = {
            FullScreenMonitor.shared.spaceChanges()
        }
    ) {
        self.musicService = musicService
        self.settings = settings
        self.streamProvider = streamProvider
        startMonitoring()
    }

    deinit {
        monitorTask?.cancel()
    }

    func apply(spaces: [FullscreenSpaceSnapshot]) {
        fullscreenStatus = FullscreenMediaDetectionPolicy.statusByScreen(
            spaces: spaces,
            hideOption: settings.hideNotchOption,
            nowPlayingBundleIdentifier: musicService.bundleIdentifier
        )
    }

    private func startMonitoring() {
        monitorTask = Task { @MainActor [streamProvider] in
            let stream = await streamProvider()
            for await spaces in stream {
                guard !Task.isCancelled else { return }
                apply(spaces: spaces.map(FullscreenSpaceSnapshot.init))
            }
        }
    }
}
