//
//  MusicPlaybackController+Actions.swift
//  boringNotch
//
//  Extracted from MusicPlaybackController — transport and app interaction actions.
//

import AppKit

extension MusicPlaybackController {
    func openMusicApp() {
        guard let bundleID = bundleIdentifier else { return }
        let workspace = NSWorkspace.shared
        if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleID) {
            let configuration = NSWorkspace.OpenConfiguration()
            workspace.openApplication(at: appURL, configuration: configuration) { _, error in
                if let error = error {
                    print("Failed to launch app with bundle ID: \(bundleID), error: \(error)")
                }
            }
        }
    }

    func forceUpdate() {
        Task { [weak self] in
            if self?.activeController?.isActive() == true {
                if let youtubeController = self?.activeController as? YouTubeMusicController {
                    await youtubeController.pollPlaybackState()
                } else {
                    await self?.activeController?.updatePlaybackInfo()
                }
            }
        }
    }

    func syncVolumeFromActiveApp() async {
        guard let bundleID = bundleIdentifier, !bundleID.isEmpty,
              NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == bundleID }) else { return }

        let appName: String
        switch bundleID {
        case "com.apple.Music": appName = "Music"
        case "com.spotify.client": appName = "Spotify"
        default: return
        }

        let script = "tell application \"\(appName)\"\nif it is running then\nget sound volume\nelse\nreturn 50\nend if\nend tell"

        if let result = try? await AppleScriptHelper.execute(script) {
            let currentVolume = Double(result.int32Value) / 100.0
            await MainActor.run {
                if abs(currentVolume - self.volume) > 0.01 { self.volume = currentVolume }
            }
        }
    }
}
