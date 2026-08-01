import Foundation

public struct ObsidianSink: BriefSink {
    public let noteURL: URL

    public init(noteURL: URL) {
        self.noteURL = noteURL
    }

    public func receive(_ entry: BriefEntry) async {
        let block = Self.markdown(for: entry)
        do {
            if FileManager.default.fileExists(atPath: noteURL.path) {
                let handle = try FileHandle(forWritingTo: noteURL)
                try handle.seekToEnd()
                if let data = block.data(using: .utf8) {
                    try handle.write(contentsOf: data)
                }
                try handle.close()
            } else {
                try block.write(to: noteURL, atomically: true, encoding: .utf8)
            }
        } catch {
            // Silent by design: sink failures should not break user flow.
        }
    }

    public static func markdown(for entry: BriefEntry, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: entry.revealedAt)
        let minute = calendar.component(.minute, from: entry.revealedAt)
        let time = String(format: "%02d:%02d", hour, minute)

        if entry.metadata[MoodMetadataKey.promptKind.rawValue] == MoodMetadataKey.promptKindValue
            || entry.sourceID == "mood" {
            let rating = entry.metadata[MoodMetadataKey.moodRating.rawValue] ?? "Unanswered"
            let note = entry.metadata[MoodMetadataKey.moodNote.rawValue]
            return """
                ## Mood - \(time)
                Feeling: \(rating.capitalized)
                \(note.map { "Note: \($0)" } ?? "")

                ---

                """
        }

        let sourceName = BriefSourceRegistry.descriptor(for: entry.sourceID).displayName
        var lines = [
            "## Daily Brief - \(time)",
            "",
            "**\(sourceName):** \(entry.title)",
        ]
        if let subtitle = entry.subtitle, !subtitle.isEmpty {
            lines.append("*\(subtitle)*")
        }
        if let body = entry.body, !body.isEmpty {
            lines.append("> \(body)")
        }
        lines.append("")
        lines.append("---")
        lines.append("")
        return lines.joined(separator: "\n")
    }
}
