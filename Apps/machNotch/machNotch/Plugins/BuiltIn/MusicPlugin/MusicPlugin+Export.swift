//
//  MusicPlugin+Export.swift
//  machNotch
//
//  ExportablePlugin conformance for MusicPlugin.
//

import Foundation

extension MusicPlugin {
    var supportedExportFormats: [ExportFormat] { [.json] }

    func exportData(format: ExportFormat) async throws -> Data {
        guard format == .json else {
            throw PluginError.exportFailed("Unsupported format: \(format.displayName)")
        }
        guard let service = musicService else {
            throw PluginError.exportFailed("Music service unavailable")
        }
        let snapshot = MusicExportSnapshot(
            track: service.currentTrack,
            isPlaying: service.playbackState.isPlaying,
            progress: service.progress,
            volume: service.volume,
            isShuffled: service.isShuffled,
            exportedAt: Date()
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }
}

// MARK: - Export DTO

struct MusicExportSnapshot: Codable {
    let track: TrackInfo?
    let isPlaying: Bool
    let progress: Double
    let volume: Double
    let isShuffled: Bool
    let exportedAt: Date
}
