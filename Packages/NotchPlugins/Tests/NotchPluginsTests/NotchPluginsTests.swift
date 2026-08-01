import XCTest
@testable import NotchPlugins

final class NotchPluginsTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(NotchPlugins.version, "1.0.0")
    }
}
