import Foundation

public struct ObsidianSink: BriefSink {
    public let noteURL: URL

    public init(noteURL: URL) {
        self.noteURL = noteURL
    }

    public func receive(_ entry: BriefEntry) async {
        let block = """
        ## Daily Brief
        \(entry.title)
        \(entry.subtitle ?? "")
        
        ---

        """
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
}
