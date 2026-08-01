//
//  AudioPlayer.swift
//  machNotch
//
//  Created by Harsh Vardhan  Goswami  on 09/08/24.
//

import AppKit
import Foundation

class AudioPlayer {
    func play(fileName: String, fileExtension: String) {
        NSSound(contentsOf: Bundle.main.url(forResource: fileName, withExtension: fileExtension)!, byReference: false)?
            .play()
    }
}
