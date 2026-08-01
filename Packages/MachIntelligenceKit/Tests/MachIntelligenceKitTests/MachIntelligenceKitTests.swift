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

    func testOMLXNormalizedHostPreservesExistingV1Path() {
        let settings = OMLXEmbeddingProviderSettings(
            isEnabled: true,
            host: URL(string: "http://127.0.0.1:8000/v1")!
        )

        XCTAssertEqual(settings.host.absoluteString, "http://127.0.0.1:8000/v1")
    }

    func testOMLXNormalizedHostAppendsV1PathWhenMissing() {
        let settings = OMLXEmbeddingProviderSettings(
            isEnabled: true,
            host: URL(string: "http://127.0.0.1:8000")!
        )

        XCTAssertEqual(settings.host.absoluteString, "http://127.0.0.1:8000/v1")
    }

    func testOMLXHostAllowlistDefaultsToLocalOnly() {
        XCTAssertTrue(URL(string: "http://localhost:8000/v1")!.isAllowedOMLXHost(false))
        XCTAssertTrue(URL(string: "http://127.0.0.1:9000/v1")!.isAllowedOMLXHost(false))
        XCTAssertTrue(URL(string: "http://[::1]:8080/v1")!.isAllowedOMLXHost(false))
        XCTAssertFalse(URL(string: "http://example.com:8000/v1")!.isAllowedOMLXHost(false))
    }

    func testOMLXHostAllowlistCanBeOverridden() {
        XCTAssertTrue(URL(string: "http://example.com:8000/v1")!.isAllowedOMLXHost(true))
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
