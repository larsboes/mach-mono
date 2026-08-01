import XCTest
@testable import machNotch

@MainActor
final class AIManagerTests: XCTestCase {
    func testDefaultManagerHasNoActiveProvider() async {
        let manager = AIManager()
        let isTextGenerationAvailable = await manager.textGeneration.isAvailable
        let isManagerAvailable = await manager.checkAvailability()

        XCTAssertNil(manager.activeProviderId)
        XCTAssertTrue(manager.textGeneration is NoAITextGenerationService)
        XCTAssertFalse(isTextGenerationAvailable)
        XCTAssertFalse(isManagerAvailable)
    }

    func testExplicitProviderActivationEnablesTextGeneration() async throws {
        let manager = AIManager()
        manager.registerProvider(TestAIProvider(id: "test", response: "generated", available: true))
        manager.setActiveProvider(id: "test")

        XCTAssertEqual(manager.activeProviderId, "test")
        let isManagerAvailable = await manager.checkAvailability()
        let isTextGenerationAvailable = await manager.textGeneration.isAvailable
        XCTAssertTrue(isManagerAvailable)
        XCTAssertTrue(isTextGenerationAvailable)
        let result = try await manager.textGeneration.rewrite("hello", style: .concise)
        XCTAssertEqual(result, "generated")
    }

    func testDefaultProviderStreamYieldsSingleGeneratedValue() async throws {
        let provider = TestAIProvider(id: "stream-test", response: "chunk", available: true)
        var chunks: [String] = []

        for try await chunk in provider.generateStream(prompt: "prompt", config: AIGenerationConfig()) {
            chunks.append(chunk)
        }

        XCTAssertEqual(chunks, ["chunk"])
    }

    func testProviderBackedRewriteStreamYieldsProviderChunks() async throws {
        let service = ProviderBackedAIService(
            provider: StreamingAIProvider(chunks: ["clear", " and ", "short"])
        )
        var chunks: [String] = []

        for try await chunk in service.rewriteStream("make this better", style: .concise) {
            chunks.append(chunk)
        }

        XCTAssertEqual(chunks, ["clear", " and ", "short"])
    }

    func testTeleprompterAIStreamingReplacesTextIncrementally() async throws {
        let state = TeleprompterState()
        state.text = "rough opener"
        let service = StreamingAITextService(chunks: ["Polished", " opener"])

        try await state.aiAssistStream(action: .refine, ai: service)

        XCTAssertEqual(state.text, "Polished opener")
        XCTAssertEqual(state.scrollPosition, 0)
    }

    func testFoundationProviderUnavailableReasonsStayUnavailable() async {
        for availability in unavailableFoundationStates {
            let provider = FoundationModelsProvider(
                client: TestFoundationModelsClient(availability: availability)
            )
            let isAvailable = await provider.isAvailable

            XCTAssertFalse(isAvailable)
            do {
                _ = try await provider.generate(prompt: "hello", config: AIGenerationConfig())
                XCTFail("Expected unavailable Foundation Models provider to throw")
            } catch let error as AIError {
                XCTAssertNotNil(error.errorDescription)
            } catch {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }

    func testFoundationProviderMapsSupportedGenerationOptions() async throws {
        let recorder = FoundationOptionsRecorder()
        let provider = FoundationModelsProvider(
            client: TestFoundationModelsClient(
                availability: .available,
                response: "ok",
                onGenerate: { options in recorder.options = options }
            )
        )

        let config = AIGenerationConfig(
            temperature: 0.25,
            maxTokens: 42,
            stopSequences: ["ignored-by-foundation-models"]
        )
        let result = try await provider.generate(prompt: "hello", config: config)

        XCTAssertEqual(result, "ok")
        XCTAssertEqual(recorder.options, FoundationGenerationOptions(config: config))
    }

    func testFoundationProviderStreamConvertsSnapshotsToDeltas() async throws {
        let provider = FoundationModelsProvider(
            client: TestFoundationModelsClient(
                availability: .available,
                snapshots: ["Hel", "Hello", "Hello", "Hello!"]
            )
        )
        var chunks: [String] = []

        for try await chunk in provider.generateStream(prompt: "prompt", config: AIGenerationConfig()) {
            chunks.append(chunk)
        }

        XCTAssertEqual(chunks, ["Hel", "lo", "!"])
    }

    func testLocalRouterPrefersAvailableOMLXThenFallsBackToFoundation() async throws {
        let foundation = TestAIProvider(id: "foundation", response: "foundation", available: true)
        let unavailableOMLX = TestAIProvider(id: "omlx", response: "omlx", available: false)
        let availableOMLX = TestAIProvider(id: "omlx", response: "omlx", available: true)

        let fallback = LocalAIProviderRouter(
            foundationProvider: foundation,
            omlxProvider: unavailableOMLX
        )
        let preferred = LocalAIProviderRouter(
            foundationProvider: foundation,
            omlxProvider: availableOMLX
        )

        let fallbackResult = try await fallback.generate(prompt: "prompt", config: AIGenerationConfig())
        let preferredResult = try await preferred.generate(prompt: "prompt", config: AIGenerationConfig())

        XCTAssertEqual(fallbackResult, "foundation")
        XCTAssertEqual(preferredResult, "omlx")
    }

    func testOMLXSettingsNormalizeHostAndSSEDeltaParsing() {
        let settings = OMLXProviderSettings(
            isEnabled: true,
            host: URL(string: "http://localhost:8000")!,
            preferredModelId: "  qwen  "
        )
        let line = """
            data: {"choices":[{"delta":{"content":"hello"}}]}
            """

        XCTAssertEqual(settings.host.absoluteString, "http://localhost:8000/v1")
        XCTAssertEqual(settings.preferredModelId, "qwen")
        XCTAssertEqual(OMLXProvider.deltaContent(fromServerSentEventLine: line), "hello")
        XCTAssertNil(OMLXProvider.deltaContent(fromServerSentEventLine: "data: [DONE]"))
    }
}

private let unavailableFoundationStates: [FoundationModelAvailability] = [
    .deviceNotEligible,
    .appleIntelligenceNotEnabled,
    .modelNotReady,
]

private struct TestAIProvider: AIProvider {
    let id: String
    let name = "Test"
    let response: String
    let available: Bool

    var isAvailable: Bool {
        get async { available }
    }

    func generate(prompt: String, config: AIGenerationConfig) async throws -> String {
        response
    }
}

private struct StreamingAIProvider: AIProvider {
    let id = "streaming"
    let name = "Streaming"
    let chunks: [String]

    var isAvailable: Bool {
        get async { true }
    }

    func generate(prompt: String, config: AIGenerationConfig) async throws -> String {
        chunks.joined()
    }

    func generateStream(prompt: String, config: AIGenerationConfig) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            for chunk in chunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
    }
}

private final class StreamingAITextService: AITextGenerationService {
    let chunks: [String]

    init(chunks: [String]) {
        self.chunks = chunks
    }

    var isAvailable: Bool {
        get async { true }
    }

    func rewrite(_ text: String, style: AIRewriteStyle) async throws -> String {
        chunks.joined()
    }

    func rewriteStream(_ text: String, style: AIRewriteStyle) -> AsyncThrowingStream<String, Error> {
        chunkStream()
    }

    func summarize(_ text: String) async throws -> String {
        chunks.joined()
    }

    func summarizeStream(_ text: String) -> AsyncThrowingStream<String, Error> {
        chunkStream()
    }

    func section(_ text: String) async throws -> [String] {
        [chunks.joined()]
    }

    func draftIntro(topic: String, durationSeconds: Int) async throws -> String {
        chunks.joined()
    }

    func draftIntroStream(topic: String, durationSeconds: Int) -> AsyncThrowingStream<String, Error> {
        chunkStream()
    }

    private func chunkStream() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            for chunk in chunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
    }
}

private struct TestFoundationModelsClient: FoundationModelsClient {
    let availabilityState: FoundationModelAvailability
    let response: String
    let snapshots: [String]
    let onGenerate: (@Sendable (FoundationGenerationOptions) -> Void)?

    init(
        availability: FoundationModelAvailability,
        response: String = "generated",
        snapshots: [String] = [],
        onGenerate: (@Sendable (FoundationGenerationOptions) -> Void)? = nil
    ) {
        self.availabilityState = availability
        self.response = response
        self.snapshots = snapshots
        self.onGenerate = onGenerate
    }

    var availability: FoundationModelAvailability {
        get async { availabilityState }
    }

    func generate(prompt: String, options: FoundationGenerationOptions) async throws -> String {
        onGenerate?(options)
        return response
    }

    func streamSnapshots(
        prompt: String,
        options: FoundationGenerationOptions
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            for snapshot in snapshots {
                continuation.yield(snapshot)
            }
            continuation.finish()
        }
    }
}

private final class FoundationOptionsRecorder: @unchecked Sendable {
    var options: FoundationGenerationOptions?
}
