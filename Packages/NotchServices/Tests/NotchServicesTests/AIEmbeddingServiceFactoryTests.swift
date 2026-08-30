import XCTest

import MachIntelligenceKit
import NotchCore

@testable import NotchServices

/// Covers "provider selection and availability behavior remains clean and
/// local-first" from #76.
///
/// The failure that matters is silent: if the factory ever hands back a live
/// provider pointed at a remote host, shelf contents leave the machine.
@MainActor
final class AIEmbeddingServiceFactoryTests: XCTestCase {

    private func settings(
        aiEnabled: Bool = true,
        omlxEnabled: Bool = true,
        host: String = "http://127.0.0.1:8000/v1",
        allowRemote: Bool = false
    ) -> MockNotchSettings {
        let mock = MockNotchSettings()
        mock.isAIEnabled = aiEnabled
        mock.omlxProviderEnabled = omlxEnabled
        mock.omlxProviderHost = host
        mock.omlxAllowNonLocalhostHost = allowRemote
        return mock
    }

    func testReturnsNoServiceWhenAIIsOff() {
        let service = AIEmbeddingServiceFactory.make(settings: settings(aiEnabled: false))
        XCTAssertTrue(service is NoAIEmbeddingService)
    }

    func testReturnsNoServiceWhenTheProviderIsOff() {
        let service = AIEmbeddingServiceFactory.make(settings: settings(omlxEnabled: false))
        XCTAssertTrue(service is NoAIEmbeddingService)
    }

    func testRefusesARemoteHostByDefault() {
        let service = AIEmbeddingServiceFactory.make(
            settings: settings(host: "http://example.com:8000/v1")
        )
        XCTAssertTrue(
            service is NoAIEmbeddingService,
            "a non-local host must not produce a live provider without the explicit override"
        )
    }

    func testAcceptsARemoteHostOnlyWithTheExplicitOverride() {
        let service = AIEmbeddingServiceFactory.make(
            settings: settings(host: "http://example.com:8000/v1", allowRemote: true)
        )
        XCTAssertFalse(service is NoAIEmbeddingService)
    }

    func testAcceptsLoopbackHosts() {
        for host in ["http://127.0.0.1:8000/v1", "http://localhost:9000", "http://[::1]:8080/v1"] {
            let service = AIEmbeddingServiceFactory.make(settings: settings(host: host))
            XCTAssertFalse(service is NoAIEmbeddingService, "\(host) is local and should be allowed")
        }
    }

    func testDisablingAIAfterConstructionStopsEmbedding() async {
        let mock = settings()
        let service = AIEmbeddingServiceFactory.make(settings: mock)

        mock.isAIEnabled = false

        do {
            _ = try await service.embedding(for: "anything")
            XCTFail("embedding must fail once AI is switched off")
        } catch let error as AIEmbeddingError {
            guard case .featureDisabled = error else {
                return XCTFail("expected .featureDisabled, got \(error)")
            }
        } catch {
            XCTFail("expected AIEmbeddingError, got \(error)")
        }
    }
}
