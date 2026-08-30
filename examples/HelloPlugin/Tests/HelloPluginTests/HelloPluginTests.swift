import XCTest

import NotchPluginCore

@testable import HelloPlugin

@MainActor
final class HelloPluginTests: XCTestCase {

    func testIdentityIsStable() {
        let plugin = HelloPlugin()

        // The id keys the plugin's settings namespace and its enabled state.
        // Changing it orphans every user's configuration.
        XCTAssertEqual(plugin.id, "com.example.hello")
        XCTAssertEqual(plugin.metadata.name, "Hello")
        XCTAssertEqual(plugin.metadata.category, .utilities)
    }

    func testStartsInactive() {
        XCTAssertEqual(HelloPlugin().state, .inactive)
        XCTAssertFalse(HelloPlugin().isEnabled)
    }

    func testDescriptorDeclaresOnlyWhatThePluginUses() {
        let descriptor = HelloPlugin.makeDescriptor()

        XCTAssertEqual(descriptor.id, HelloPlugin().id)
        XCTAssertTrue(descriptor.capabilities.contains(.mediaServices))
        XCTAssertTrue(descriptor.capabilities.contains(.expandedPanelContent))

        // Over-declaring is visible to users and counts against a plugin in review.
        XCTAssertFalse(descriptor.capabilities.contains(.extensionServices))
        XCTAssertFalse(descriptor.capabilities.contains(.storageServices))
        XCTAssertFalse(descriptor.capabilities.contains(.systemServices))
        XCTAssertFalse(descriptor.capabilities.contains(.uiServices))
    }

    func testDescriptorIsExternal() {
        guard case .external(let bundle) = HelloPlugin.makeDescriptor().origin else {
            return XCTFail("A third-party plugin must register as .external")
        }
        XCTAssertEqual(bundle, "com.example.hello")
    }

    func testDescriptorDoesNotConstructThePlugin() {
        // Registration is metadata-only, so a disabled plugin costs nothing at launch.
        var constructed = 0
        let descriptor = PluginDescriptor(
            id: "com.example.hello",
            metadata: HelloPlugin().metadata,
            origin: .external("com.example.hello"),
            capabilities: [.mediaServices],
            factory: {
                constructed += 1
                return HelloPlugin()
            }
        )

        XCTAssertEqual(constructed, 0, "Building the descriptor must not build the plugin")
        _ = descriptor.makePlugin()
        XCTAssertEqual(constructed, 1)
    }

    func testDeactivateReturnsToInactive() async {
        let plugin = HelloPlugin()
        await plugin.deactivate()
        XCTAssertEqual(plugin.state, .inactive)
    }
}
