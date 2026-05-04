import XCTest

@testable import machNotch

// MARK: - Mock Exportable Plugin

@MainActor
@Observable
final class MockExportablePlugin: NotchPlugin, ExportablePlugin {
    let id = "com.test.export"
    let metadata = PluginMetadata(
        name: "TestExport",
        description: "Test",
        icon: "doc",
        version: "1.0",
        author: "test",
        category: .utilities
    )
    var isEnabled: Bool = true
    private(set) var state: PluginState = .active

    func activate(context: PluginContext) async throws { state = .active }
    func deactivate() async { state = .inactive }
    // View methods intentionally omitted — protocol defaults return EmptyView

    // ExportablePlugin

    var supportedExportFormats: [ExportFormat] { [.json, .csv] }

    var exportResult: Data = Data()
    var exportCalledWith: ExportFormat?
    var shouldThrow: Bool = false

    func exportData(format: ExportFormat) async throws -> Data {
        exportCalledWith = format
        if shouldThrow {
            throw PluginError.exportFailed("Test error")
        }
        return exportResult
    }
}

// MARK: - Tests

@MainActor
final class ExportablePluginTests: XCTestCase {

    func testShelfExportJSON() async throws {
        let plugin = ShelfPlugin()
        // ShelfPlugin without service should throw
        do {
            _ = try await plugin.exportData(format: .json)
            XCTFail("Expected error when no shelf service")
        } catch {
            XCTAssertTrue(error is PluginError)
        }
    }

    func testCalendarExportJSON() async throws {
        let plugin = CalendarPlugin()
        // CalendarPlugin without service should throw
        do {
            _ = try await plugin.exportData(format: .json)
            XCTFail("Expected error when no calendar service")
        } catch {
            XCTAssertTrue(error is PluginError)
        }
    }

    func testMusicExportJSON() async throws {
        let plugin = MusicPlugin()
        // MusicPlugin without service should throw
        do {
            _ = try await plugin.exportData(format: .json)
            XCTFail("Expected error when no music service")
        } catch {
            XCTAssertTrue(error is PluginError)
        }
    }

    func testUnsupportedFormatThrows() async throws {
        let plugin = ShelfPlugin()
        // Even with no service, unsupported format should throw
        do {
            _ = try await plugin.exportData(format: .ical)
            XCTFail("Expected error for unsupported format")
        } catch let error as PluginError {
            if case .exportFailed(let msg) = error {
                XCTAssertTrue(msg.contains("Unsupported") || msg.contains("No shelf"))
            }
        }
    }

    func testExportFormatProperties() {
        XCTAssertEqual(ExportFormat.json.fileExtension, "json")
        XCTAssertEqual(ExportFormat.csv.mimeType, "text/csv")
        XCTAssertEqual(ExportFormat.ical.displayName, "iCalendar")
        XCTAssertEqual(ExportFormat.html.fileExtension, "html")
    }

    func testMockExportablePlugin() async throws {
        let plugin = MockExportablePlugin()
        let testData = Data("test export".utf8)
        plugin.exportResult = testData

        let result = try await plugin.exportData(format: .json)
        XCTAssertEqual(result, testData)
        XCTAssertEqual(plugin.exportCalledWith, .json)
    }

    func testMockExportablePluginThrows() async throws {
        let plugin = MockExportablePlugin()
        plugin.shouldThrow = true

        do {
            _ = try await plugin.exportData(format: .csv)
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is PluginError)
        }
    }
}

// NOTE: APIRouterNotchStateTests was removed — APIRouter no longer accepts
// notchState/openNotch/closeNotch/toggleNotch parameters in its initialiser.
// Those route-handler tests live in APIRouterTests.swift using the dynamic
// registration API instead.
