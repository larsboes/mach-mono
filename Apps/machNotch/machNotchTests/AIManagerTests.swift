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

    func testOllamaOptInControlsActiveProvider() {
        let manager = AIManager()

        manager.enableOllama(model: "test-model", host: "http://127.0.0.1:11434")
        XCTAssertEqual(manager.activeProviderId, "ollama")

        manager.disableOllama()
        XCTAssertNil(manager.activeProviderId)
    }

    func testDefaultProviderStreamYieldsSingleGeneratedValue() async throws {
        let provider = TestAIProvider(id: "stream-test", response: "chunk", available: true)
        var chunks: [String] = []

        for try await chunk in provider.generateStream(prompt: "prompt", config: AIGenerationConfig()) {
            chunks.append(chunk)
        }

        XCTAssertEqual(chunks, ["chunk"])
    }
}

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
