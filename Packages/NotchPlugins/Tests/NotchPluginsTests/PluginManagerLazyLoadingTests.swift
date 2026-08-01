import Observation
import XCTest

import NotchCore
import NotchServices
@testable import NotchPlugins

@MainActor
final class PluginManagerLazyLoadingTests: XCTestCase {
    func testBuiltInRegistryReturnsDescriptorsInExpectedOrder() {
        let descriptors = PluginRegistry.makeBuiltInDescriptors()

        XCTAssertEqual(
            descriptors.map(\.id),
            [
                PluginID.music,
                PluginID.battery,
                PluginID.calendar,
                PluginID.weather,
                PluginID.shelf,
                PluginID.webcam,
                PluginID.notifications,
                PluginID.clipboard,
                PluginID.habitTracker,
                PluginID.pomodoro,
                PluginID.teleprompter,
                PluginID.displaySurface,
                PluginID.systemStats,
                PluginID.brief,
            ]
        )
    }

    func testBuiltInDescriptorMetadataMatchesRepresentativePlugins() {
        let descriptors = Dictionary(
            uniqueKeysWithValues: PluginRegistry.makeBuiltInDescriptors().map { ($0.id, $0) }
        )

        XCTAssertEqual(descriptors[PluginID.music]?.metadata.name, "Music")
        XCTAssertEqual(descriptors[PluginID.music]?.metadata.category, .media)
        XCTAssertEqual(descriptors[PluginID.music]?.origin, .builtIn)
        XCTAssertTrue(descriptors[PluginID.music]?.capabilities.contains(.exportable) == true)
        XCTAssertEqual(descriptors[PluginID.battery]?.closedNotchPosition, .farRight)
        XCTAssertEqual(descriptors[PluginID.calendar]?.supportedExportFormats, [.json, .csv, .ical])
        XCTAssertTrue(descriptors[PluginID.shelf]?.capabilities.contains(.expandedPanelContent) == true)
    }

    func testDescriptorOnlyOperationsDoNotConstructPlugin() {
        let counter = ConstructionCounter()
        let manager = makeManager(counter: counter)

        XCTAssertEqual(counter.count, 0)
        XCTAssertEqual(manager.allPluginIds, [Self.testPluginID])
        XCTAssertEqual(manager.allPluginSummaries.map(\.id), [Self.testPluginID])
        XCTAssertTrue(manager.hasPlugin(id: Self.testPluginID))
        XCTAssertTrue(manager.isPluginEnabled(id: Self.testPluginID))
        XCTAssertEqual(manager.allPlugins.count, 0)

        manager.reorderPlugins([Self.testPluginID])

        XCTAssertEqual(counter.count, 0)
    }

    func testPluginLookupConstructsOnceAndCachesInstance() {
        let counter = ConstructionCounter()
        let manager = makeManager(counter: counter)

        let first = manager.plugin(id: Self.testPluginID)
        let second = manager.plugin(id: Self.testPluginID)

        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertEqual(counter.count, 1)
        XCTAssertTrue(first?.underlying === second?.underlying)
    }

    func testEnablePluginConstructsActivatesAndReusesCachedInstance() async throws {
        let counter = ConstructionCounter()
        let manager = makeManager(counter: counter)

        try await manager.enablePlugin(Self.testPluginID)
        try await manager.enablePlugin(Self.testPluginID)

        let plugin = manager.plugin(id: Self.testPluginID)?.underlying as? CountingPlugin
        XCTAssertEqual(counter.count, 1)
        XCTAssertEqual(plugin?.activateCount, 1)
        XCTAssertEqual(plugin?.state, .active)
        XCTAssertTrue(manager.summary(id: Self.testPluginID)?.isActive == true)
    }

    func testDisableDescriptorOnlyPluginDoesNotConstruct() async {
        let counter = ConstructionCounter()
        let manager = makeManager(counter: counter)

        await manager.disablePlugin(Self.testPluginID)

        XCTAssertEqual(counter.count, 0)
        XCTAssertFalse(manager.isPluginEnabled(id: Self.testPluginID))
        XCTAssertFalse(manager.summary(id: Self.testPluginID)?.isEnabled ?? true)
    }

    func testDisableInstantiatedPluginDeactivates() async throws {
        let counter = ConstructionCounter()
        let manager = makeManager(counter: counter)

        try await manager.enablePlugin(Self.testPluginID)
        let plugin = manager.plugin(id: Self.testPluginID)?.underlying as? CountingPlugin
        await manager.disablePlugin(Self.testPluginID)

        XCTAssertEqual(counter.count, 1)
        XCTAssertEqual(plugin?.deactivateCount, 1)
        XCTAssertEqual(plugin?.state, .inactive)
        XCTAssertFalse(manager.isPluginEnabled(id: Self.testPluginID))
    }

    func testActivateEnabledPluginsDoesNotConstructDescriptorOnlyPlugins() async {
        let counter = ConstructionCounter()
        let manager = makeManager(counter: counter)

        await manager.activateEnabledPlugins()

        XCTAssertEqual(counter.count, 0)
        XCTAssertEqual(manager.allPlugins.count, 0)
    }

    func testDiscoveredDescriptorRegistrationIsMetadataOnlyAndDisabledByDefault() {
        let counter = ConstructionCounter()
        let manager = PluginManager(
            services: TestNotchServiceProvider(music: MockMusicService()),
            eventBus: PluginEventBus(),
            appState: MockAppState(),
            mediaSettings: MockNotchSettings(),
            coordinator: TestAnimationCoordinator()
        )
        let descriptor = makeDescriptor(
            counter: counter,
            id: Self.externalPluginID,
            name: "External Lazy",
            origin: .external("com.example.bundle")
        )

        let result = manager.registerDiscoveredDescriptors([descriptor])

        XCTAssertEqual(result.registeredIDs, [Self.externalPluginID])
        XCTAssertEqual(result.skippedIDs, [])
        XCTAssertEqual(counter.count, 0)
        XCTAssertEqual(manager.allPluginIds, [Self.externalPluginID])
        XCTAssertEqual(manager.externalPluginSummaries.map(\.id), [Self.externalPluginID])
        XCTAssertFalse(manager.summary(id: Self.externalPluginID)?.isEnabled ?? true)
        XCTAssertEqual(manager.summary(id: Self.externalPluginID)?.origin, .external("com.example.bundle"))
        XCTAssertEqual(manager.allPlugins.count, 0)
    }

    func testDiscoveredDescriptorDuplicateIsSkippedWithoutConstruction() {
        let counter = ConstructionCounter()
        let manager = makeManager(counter: counter)
        let duplicate = makeDescriptor(
            counter: counter,
            id: Self.testPluginID,
            name: "Duplicate",
            origin: .external("com.example.duplicate")
        )

        let result = manager.registerDiscoveredDescriptors([duplicate])

        XCTAssertEqual(result.registeredIDs, [])
        XCTAssertEqual(result.skippedIDs, [Self.testPluginID])
        XCTAssertEqual(counter.count, 0)
        XCTAssertEqual(manager.summary(id: Self.testPluginID)?.metadata.name, "Lazy Test")
        XCTAssertEqual(manager.summary(id: Self.testPluginID)?.origin, .builtIn)
    }

    func testReplacingDiscoveredDescriptorDoesNotReplaceLivePlugin() {
        let counter = ConstructionCounter()
        let manager = makeManager(counter: counter)
        _ = manager.plugin(id: Self.testPluginID)
        let replacement = makeDescriptor(
            counter: counter,
            id: Self.testPluginID,
            name: "Replacement",
            origin: .external("com.example.replacement")
        )

        let result = manager.registerDiscoveredDescriptors(
            [replacement],
            replacingExisting: true
        )

        XCTAssertEqual(result.registeredIDs, [])
        XCTAssertEqual(result.skippedIDs, [Self.testPluginID])
        XCTAssertEqual(counter.count, 1)
        XCTAssertEqual(manager.summary(id: Self.testPluginID)?.metadata.name, "Lazy Test")
    }

    private static let testPluginID = "com.machnotch.test.lazy"
    private static let externalPluginID = "com.example.external.lazy"

    private func makeManager(counter: ConstructionCounter) -> PluginManager {
        PluginManager(
            services: TestNotchServiceProvider(music: MockMusicService()),
            eventBus: PluginEventBus(),
            appState: MockAppState(),
            mediaSettings: MockNotchSettings(),
            coordinator: TestAnimationCoordinator(),
            builtInDescriptors: [makeDescriptor(counter: counter)]
        )
    }

    private func makeDescriptor(
        counter: ConstructionCounter,
        id: String? = nil,
        name: String = "Lazy Test",
        origin: PluginDescriptorOrigin = .builtIn
    ) -> PluginDescriptor {
        let pluginID = id ?? Self.testPluginID
        return PluginDescriptor(
            id: pluginID,
            metadata: PluginMetadata(
                name: name,
                description: "Counts construction",
                icon: "testtube.2",
                category: .utilities
            ),
            origin: origin,
            capabilities: [.settingsContent],
            factory: {
                counter.count += 1
                return CountingPlugin(id: pluginID, name: name)
            }
        )
    }
}

@MainActor
private final class ConstructionCounter {
    var count = 0
}

@MainActor
private final class TestAnimationCoordinator: NotchAnimationStateProviding {
    var helloAnimationRunning = false
    var sneakPeek = SneakPeekState(show: false, type: .music, value: 0, icon: "")
    var expandingView = ExpandedItem(show: false, type: .battery, value: 0)
    var shelfService: (any ShelfServiceProtocol)?
}

@MainActor
@Observable
private final class CountingPlugin: NotchPlugin {
    let id: String
    let metadata: PluginMetadata
    var isEnabled = true
    private(set) var state: PluginState = .inactive
    private(set) var activateCount = 0
    private(set) var deactivateCount = 0

    init(id: String, name: String = "Lazy Test") {
        self.id = id
        self.metadata = PluginMetadata(
            name: name,
            description: "Counts construction",
            icon: "testtube.2",
            category: .utilities
        )
    }

    func activate(context: PluginContext) async throws {
        _ = context
        activateCount += 1
        state = .active
    }

    func deactivate() async {
        deactivateCount += 1
        state = .inactive
    }
}
