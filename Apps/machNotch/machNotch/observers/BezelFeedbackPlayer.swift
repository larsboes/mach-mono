//
//  BezelFeedbackPlayer.swift
//  machNotch
//
//  Reauthored media-key feedback sound helper for MIT-readiness.
//

import AVFoundation
import Foundation

@MainActor
final class BezelFeedbackPlayer {
    private let soundPath = "/System/Library/LoginPlugins/BezelServices.loginPlugin/Contents/Resources/volume.aiff"
    private var audioPlayer: AVAudioPlayer?

    func playIfEnabled() {
        guard feedbackSoundEnabled else { return }
        prepareIfNeeded()
        guard let player = audioPlayer else { return }

        if player.isPlaying {
            player.stop()
            player.currentTime = 0
        }

        player.play()
    }

    private var feedbackSoundEnabled: Bool {
        let domain = UserDefaults.standard.persistentDomain(forName: "NSGlobalDomain")
        return domain?["com.apple.sound.beep.feedback"] as? Int == 1
    }

    private func prepareIfNeeded() {
        guard audioPlayer == nil, FileManager.default.fileExists(atPath: soundPath) else { return }
        guard let player = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: soundPath)) else { return }
        player.volume = 1
        player.numberOfLoops = 0
        player.prepareToPlay()
        audioPlayer = player
    }
}
