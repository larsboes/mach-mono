//
//  ExportCoordinator.swift
//  machNotch
//
//  Orchestrates data export from ExportablePlugin conformers.
//  Presents NSSavePanel for user to choose save location.
//

import AppKit
import UniformTypeIdentifiers

@MainActor
@Observable public final class ExportCoordinator {

    // MARK: - Dependencies

    private let pluginManager: PluginManager

    // MARK: - State

    public private(set) var isExporting: Bool = false

    // MARK: - Initialization

    public init(pluginManager: PluginManager) {
        self.pluginManager = pluginManager
    }

    // MARK: - Public API

    /// Instantiated plugins that support export. Use `exportablePluginSummaries` for metadata-only listing.
    public var exportablePlugins: [any ExportablePlugin] {
        pluginManager.allPluginSummaries
            .filter(\.isExportable)
            .compactMap { pluginManager.plugin(id: $0.id)?.underlying as? (any ExportablePlugin) }
    }

    /// Exportable plugin metadata without forcing plugin construction.
    public var exportablePluginSummaries: [PluginSummary] {
        pluginManager.allPluginSummaries.filter(\.isExportable)
    }

    /// Export a single plugin's data and present a save panel
    public func exportPlugin(_ plugin: any ExportablePlugin, format: ExportFormat) async throws {
        isExporting = true
        defer { isExporting = false }

        let data = try await plugin.exportData(format: format)
        let filename = "\(plugin.metadata.name)_export.\(format.fileExtension)"

        try await presentSavePanel(data: data, filename: filename, format: format)
    }

    /// Export a single plugin by id and present a save panel.
    public func exportPlugin(id: String, format: ExportFormat) async throws {
        guard let plugin = pluginManager.plugin(id: id)?.underlying as? any ExportablePlugin else {
            throw PluginError.exportFailed("Export not supported for plugin '\(id)'")
        }
        try await exportPlugin(plugin, format: format)
    }

    /// Export all exportable plugins into a folder
    public func exportAll(format: ExportFormat) async throws {
        isExporting = true
        defer { isExporting = false }

        let plugins = exportablePluginSummaries.filter { $0.supportedExportFormats.contains(format) }
        guard !plugins.isEmpty else { return }

        var exports: [(String, Data)] = []
        for summary in plugins {
            guard let plugin = pluginManager.plugin(id: summary.id)?.underlying as? any ExportablePlugin else {
                continue
            }
            let data = try await plugin.exportData(format: format)
            let filename = "\(summary.metadata.name)_export.\(format.fileExtension)"
            exports.append((filename, data))
        }

        // For single plugin, use save panel. For multiple, use folder picker.
        if exports.count == 1 {
            let (filename, data) = exports[0]
            try await presentSavePanel(data: data, filename: filename, format: format)
        } else {
            try await presentFolderPanel(exports: exports)
        }
    }

    // MARK: - Save Panels

    private func presentSavePanel(data: Data, filename: String, format: ExportFormat) async throws {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = filename
        panel.allowedContentTypes = [contentType(for: format)]
        panel.canCreateDirectories = true

        let response = await panel.beginSheetModal(for: NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first!)
        guard response == .OK, let url = panel.url else { return }

        try data.write(to: url)
    }

    private func presentFolderPanel(exports: [(String, Data)]) async throws {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"

        let response = await panel.beginSheetModal(for: NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first!)
        guard response == .OK, let folder = panel.url else { return }

        for (filename, data) in exports {
            let fileURL = folder.appendingPathComponent(filename)
            try data.write(to: fileURL)
        }
    }

    private func contentType(for format: ExportFormat) -> UTType {
        switch format {
        case .json: return .json
        case .csv: return .commaSeparatedText
        case .xml: return .xml
        case .ical: return .calendarEvent
        case .markdown: return UTType("net.daringfireball.markdown") ?? .plainText
        case .html: return .html
        }
    }
}
