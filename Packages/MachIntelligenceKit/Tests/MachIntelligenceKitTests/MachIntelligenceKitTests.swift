import XCTest
@testable import MachIntelligenceKit

final class MachIntelligenceKitTests: XCTestCase {
    func testProtocolStubsCompile() async throws {
        let embeddings = StubEmbeddingService()
        let transcription = StubTranscriptionService()

        let vector = try await embeddings.embedding(for: "hello")
        let text = try await transcription.transcribe(audioAt: URL(fileURLWithPath: "/tmp/audio.wav"))

        XCTAssertEqual(vector, [1, 2, 3])
        XCTAssertEqual(text, "hello")
    }
}

private struct StubEmbeddingService: AIEmbeddingService {
    func embedding(for text: String) async throws -> [Float] {
        [1, 2, 3]
    }
}

private struct StubTranscriptionService: AITranscriptionService {
    func transcribe(audioAt url: URL) async throws -> String {
        "hello"
    }
}
