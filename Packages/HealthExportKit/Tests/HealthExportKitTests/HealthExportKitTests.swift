import XCTest
@testable import HealthExportKit

final class HealthExportKitTests: XCTestCase {
    func testRoundTripPayload() throws {
        let sample = HealthSample(
            uuid: "abc",
            type: .heartRate,
            value: "61",
            unit: "bpm",
            start: Date(timeIntervalSince1970: 1_700_000_000),
            end: Date(timeIntervalSince1970: 1_700_000_060)
        )
        let payload = HealthExportPayload(
            device: "test-iphone",
            sentAt: Date(timeIntervalSince1970: 1_700_000_000),
            samples: [sample]
        )
        let data = try HealthExportSerializer.encode(payload)
        let decoded = try HealthExportSerializer.decode(data)
        XCTAssertEqual(decoded, payload)
    }

    func testReceiverRequiresPairing() throws {
        let receiver = MacReceiverStub()
        let payload = HealthExportPayload(device: "phone", samples: [])
        let data = try HealthExportSerializer.encode(payload)

        XCTAssertThrowsError(try receiver.ingest(data: data, token: nil)) { error in
            XCTAssertEqual(error as? MacReceiverError, .unauthorized)
        }

        _ = receiver.pair(code: "123456")
        let token = receiver.pairingToken
        try receiver.ingest(data: data, token: token)
        XCTAssertEqual(receiver.received.count, 1)
    }
}
