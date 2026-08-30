import Observation
import XCTest

import NotchCore
import NotchServices

@testable import NotchPlugins

/// Covers the capability boundary a published Plugin SDK promises: a plugin
/// reaches only the service groups it declared.
@MainActor
final class PluginCapabilityGrantTests: XCTestCase {

    // MARK: - The narrowing has to be real, not advisory

    func testNarrowedFacadeCannotBeCastBackToFullProvider() {
        let media = makeContext(granting: .allServices).mediaServices

        XCTAssertNil(
            media as? any NotchServiceProvider,
            "mediaServices must not be castable to the full provider — that is the "
                + "hole the facades close."
        )
        XCTAssertNil(media as? any PluginExtensionServiceProvider)
        XCTAssertNil(media as? any StorageServiceProvider)
    }

    func testEveryNarrowedAccessorIsCapabilityScoped() {
        let context = makeContext(granting: .allServices)

        XCTAssertNil(context.systemServices as? any NotchServiceProvider)
        XCTAssertNil(context.storageServices as? any NotchServiceProvider)
        XCTAssertNil(context.uiServices as? any NotchServiceProvider)
        XCTAssertNil(context.pluginExtensionServices as? any NotchServiceProvider)
    }

    func testFacadeStillForwardsToTheRealService() {
        let music = MockMusicService()
        music.volume = 0.42
        let context = PluginContext(
            settings: PluginSettings(pluginId: "test.plugin"),
            services: TestNotchServiceProvider(music: music),
            eventBus: PluginEventBus(),
            appState: MockAppState(),
            mediaSettings: MockNotchSettings(),
            grantedCapabilities: .allServices
        )

        XCTAssertEqual(
            context.mediaServices.music.volume,
            0.42,
            "Narrowing must not change which object the plugin talks to."
        )
    }

    // MARK: - Grant resolution

    func testExternalDescriptorGrantsOnlyDeclaredServiceGroups() {
        let manager = makeManager()
        manager.registerDescriptor(
            makeDescriptor(
                id: "com.example.external",
                origin: .external("com.example.external"),
                capabilities: [.mediaServices, .expandedPanelContent]
            )
        )

        let granted = manager.grantedServiceCapabilities(for: "com.example.external")
        XCTAssertTrue(granted.contains(.mediaServices))
        XCTAssertFalse(
            granted.contains(.extensionServices),
            "An external plugin must not receive clipboard, calendar or AI it never declared."
        )
        XCTAssertFalse(granted.contains(.storageServices))
        XCTAssertFalse(
            granted.contains(.expandedPanelContent),
            "UI capabilities are not service grants."
        )
    }

    func testBuiltInDescriptorGrantsEveryServiceGroup() {
        let manager = makeManager()
        manager.registerDescriptor(
            makeDescriptor(id: "com.machnotch.builtin", origin: .builtIn, capabilities: [])
        )

        XCTAssertEqual(
            manager.grantedServiceCapabilities(for: "com.machnotch.builtin"),
            .allServices
        )
    }

    func testUnregisteredPluginIsTreatedAsBuiltIn() {
        XCTAssertEqual(
            makeManager().grantedServiceCapabilities(for: "not.registered"),
            .allServices
        )
    }

    // MARK: - Helpers

    private func makeContext(granting capabilities: PluginCapabilities) -> PluginContext {
        PluginContext(
            settings: PluginSettings(pluginId: "test.plugin"),
            services: TestNotchServiceProvider(music: MockMusicService()),
            eventBus: PluginEventBus(),
            appState: MockAppState(),
            mediaSettings: MockNotchSettings(),
            grantedCapabilities: capabilities
        )
    }

    private func makeManager() -> PluginManager {
        PluginManager(
            services: TestNotchServiceProvider(music: MockMusicService()),
            eventBus: PluginEventBus(),
            appState: MockAppState(),
            mediaSettings: MockNotchSettings(),
            coordinator: CapabilityTestCoordinator()
        )
    }

    private func makeDescriptor(
        id: String,
        origin: PluginDescriptorOrigin,
        capabilities: PluginCapabilities
    ) -> PluginDescriptor {
        PluginDescriptor(
            id: id,
            metadata: PluginMetadata(
                name: "Capability Test",
                description: "Declares a narrow service grant",
                icon: "testtube.2",
                category: .utilities
            ),
            origin: origin,
            capabilities: capabilities,
            factory: { StubCapabilityPlugin(id: id) }
        )
    }
}

@MainActor
private final class CapabilityTestCoordinator: NotchAnimationStateProviding {
    var helloAnimationRunning = false
    var sneakPeek = SneakPeekState(show: false, type: .music, value: 0, icon: "")
    var expandingView = ExpandedItem(show: false, type: .battery, value: 0)
    var shelfService: (any ShelfServiceProtocol)?
}

@MainActor
@Observable
private final class StubCapabilityPlugin: NotchPlugin {
    let id: String
    let metadata: PluginMetadata
    var isEnabled = true
    private(set) var state: PluginState = .inactive

    init(id: String) {
        self.id = id
        self.metadata = PluginMetadata(
            name: "Capability Test",
            description: "Declares a narrow service grant",
            icon: "testtube.2",
            category: .utilities
        )
    }

    func activate(context: PluginContext) async throws {
        _ = context
        state = .active
    }

    func deactivate() async {
        state = .inactive
    }
}
