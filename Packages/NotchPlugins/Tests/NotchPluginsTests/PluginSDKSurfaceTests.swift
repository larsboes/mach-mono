import Observation
import SwiftUI
import XCTest

import NotchCore
import NotchServices

@testable import NotchPlugins

/// Locks the frozen `NotchPlugin` surface (#71).
///
/// `MinimalPlugin` below implements only the members the protocol *requires*.
/// If a new required member is added, this file stops compiling — which is the
/// point: after the freeze, additions must ship with a default implementation
/// or they break every third-party plugin.
@MainActor
final class PluginSDKSurfaceTests: XCTestCase {

    func testMinimalPluginCompilesAgainstFrozenProtocol() async throws {
        let plugin = MinimalPlugin()

        XCTAssertEqual(plugin.id, "com.example.minimal")
        XCTAssertEqual(plugin.state, .inactive)

        try await plugin.activate(
            context: PluginContext(
                settings: PluginSettings(pluginId: plugin.id),
                services: TestNotchServiceProvider(music: MockMusicService()),
                eventBus: PluginEventBus(),
                appState: MockAppState(),
                mediaSettings: MockNotchSettings()
            )
        )
        XCTAssertEqual(plugin.state, .active)

        await plugin.deactivate()
        XCTAssertEqual(plugin.state, .inactive)
    }

    func testOptionalMembersHaveDefaults() {
        let plugin = MinimalPlugin()

        XCTAssertNil(plugin.displayRequest, "displayRequest defaults to nil")
        XCTAssertTrue(plugin.closedNotchContent() is EmptyView)
        XCTAssertTrue(plugin.expandedPanelContent() is EmptyView)
        XCTAssertTrue(plugin.settingsContent() is EmptyView)
        XCTAssertTrue(plugin.menuBarView() is EmptyView)
    }

    func testTypeErasureReportsNoContentForAMinimalPlugin() {
        let erased = AnyNotchPlugin(MinimalPlugin())

        XCTAssertFalse(erased.hasClosedNotchContent)
        XCTAssertFalse(erased.hasExpandedPanelContent)
        XCTAssertFalse(erased.hasSettingsContent)
        XCTAssertFalse(erased.hasMenuBarContent)
        XCTAssertNil(erased.closedNotchPosition, "Only a PositionedPlugin declares a position")
    }

    /// `DisplayCategory` constants live on `DisplayCategory`, so `category:` infers.
    /// Before the freeze they sat on `DisplayRequest`, forcing `DisplayRequest.music`.
    func testDisplayCategoryConstantsAreInferrable() {
        let request = DisplayRequest(priority: .high, category: .music)

        XCTAssertEqual(request.category, .music)
        XCTAssertEqual(request.category.rawValue, "music")
        XCTAssertNil(request.preferredHeight)
        XCTAssertTrue(DisplayPriority.background < DisplayPriority.critical)
    }
}

// MARK: - The smallest legal plugin

@MainActor
@Observable
private final class MinimalPlugin: NotchPlugin {
    let id = "com.example.minimal"
    let metadata = PluginMetadata(
        name: "Minimal",
        description: "Implements only what NotchPlugin requires",
        icon: "circle"
    )
    var isEnabled = false
    private(set) var state: PluginState = .inactive

    func activate(context: PluginContext) async throws {
        _ = context
        state = .active
    }

    func deactivate() async {
        state = .inactive
    }
}
