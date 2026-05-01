//
//  LyricsServiceProtocol.swift
//  boringNotch
//
//  Created by Agent on 01/01/26.
//

import Foundation

@MainActor
protocol LyricsServiceProtocol: Observable {
    var currentLyrics: String { get }
    var isFetchingLyrics: Bool { get }
    var syncedLyrics: [(time: Double, text: String)] { get }
    func fetchLyrics(bundleIdentifier: String?, title: String, artist: String) async
    func clearLyrics()
    func lyricLine(at elapsed: Double) -> String
}
