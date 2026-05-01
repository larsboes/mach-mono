//
//  ShelfPlugin.swift
//  boringNotch
//
//  Built-in shelf plugin.
//  Provides a temporary storage area for files and links.
//

import SwiftUI

@MainActor
@Observable
final class ShelfPlugin: NotchPlugin, ExportablePlugin {
    
    // MARK: - NotchPlugin
    
    let id = PluginID.shelf
    
    let metadata = PluginMetadata(
        name: "Shelf",
        description: "Temporary storage for files and links",
        icon: "tray.full.fill",
        version: "1.0.0",
        author: "boringNotch",
        category: .productivity
    )
    
    var isEnabled: Bool = true
    
    private(set) var state: PluginState = .inactive
    
    // MARK: - Dependencies
    
    var shelfService: (any ShelfServiceProtocol)?
    private var settings: PluginSettings?
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Lifecycle
    
    func activate(context: PluginContext) async throws {
        state = .activating
        
        self.shelfService = context.services.shelf
        self.settings = context.settings
        
        state = .active
    }
    
    func deactivate() async {
        shelfService = nil
        settings = nil
        state = .inactive
    }
    
    // MARK: - UI Slots
    
    @ViewBuilder
    func expandedPanelContent() -> some View {
        if isEnabled, state.isActive {
            // ShelfView uses Environment(\.pluginManager) to access services
            // It also needs BoringViewModel from environment, which NotchHomeView provides
            ShelfView()
        }
    }
    
    @ViewBuilder
    func settingsContent() -> some View {
        Shelf()
    }

    // MARK: - ExportablePlugin

    var supportedExportFormats: [ExportFormat] { [.json, .csv] }

    func exportData(format: ExportFormat) async throws -> Data {
        guard let items = shelfService?.items else {
            throw PluginError.exportFailed("No shelf data available")
        }

        switch format {
        case .json:
            return try exportJSON(items: items)
        case .csv:
            return exportCSV(items: items)
        default:
            throw PluginError.exportFailed("Unsupported format: \(format.displayName)")
        }
    }

    private func exportJSON(items: [ShelfItem]) throws -> Data {
        let entries: [[String: Any]] = items.map { item in
            [
                "id": item.id.uuidString,
                "name": item.displayName,
                "type": item.kindLabel,
                "isTemporary": item.isTemporary
            ]
        }
        return try JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted, .sortedKeys])
    }

    private func exportCSV(items: [ShelfItem]) -> Data {
        var csv = "id,name,type,temporary\n"
        for item in items {
            let name = item.displayName.replacingOccurrences(of: ",", with: ";")
            csv += "\(item.id),\(name),\(item.kindLabel),\(item.isTemporary)\n"
        }
        return Data(csv.utf8)
    }
}

extension ShelfItem {
    var kindLabel: String {
        switch kind {
        case .file: "file"
        case .text: "text"
        case .link: "link"
        }
    }
}
