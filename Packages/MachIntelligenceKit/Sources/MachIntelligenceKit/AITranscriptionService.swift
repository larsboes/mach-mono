import Foundation

public protocol AITranscriptionService: Sendable {
    func transcribe(audioAt url: URL) async throws -> String
}
