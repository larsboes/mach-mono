import XCTest
@testable import NotchPlugins
import NotchCore
import NotchServices

@MainActor
final class BatteryPluginTests: XCTestCase {
    func testPluginMetadata() {
        let plugin = BatteryPlugin()
        XCTAssertEqual(plugin.id, "com.machnotch.battery")
        XCTAssertEqual(plugin.metadata.name, "Battery")
        XCTAssertEqual(plugin.metadata.category, .system)
    }
}
