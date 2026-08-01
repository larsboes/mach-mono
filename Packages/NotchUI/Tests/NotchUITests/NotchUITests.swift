import XCTest
@testable import NotchUI

final class NotchUITests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(NotchUI.version, "1.0.0")
    }

    func testFluidSimulationEngineInitializationAndResize() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            // Skip test on environments without Metal support (e.g. headless CI)
            return
        }

        let engine = try FluidSimulationEngine(device: device)
        XCTAssertEqual(engine.curlStrength, 26.0)
        XCTAssertEqual(engine.velocityDissipation, 0.22)
        XCTAssertEqual(engine.dyeDissipation, 0.9)

        // Test resize allocating textures
        engine.resize(width: 200, height: 100)
    }
}
