//
//  ClipboardPlugin.swift
//  machNotch
//
//  Created by Agent on 02/01/26.
//

import SwiftUI

@MainActor
@Observable
public final class ClipboardPlugin: NotchPlugin {

    // MARK: - NotchPlugin

    public let id = PluginID.clipboard

    public let metadata = PluginMetadata(
        name: "Clipboard",
        description: "View and manage clipboard history",
        icon: "doc.on.clipboard",
        version: "1.0.0",
        author: "machNotch",
        category: .utilities
    )

    public var isEnabled: Bool = true

    public private(set) var state: PluginState = .inactive
    private var context: PluginContext?

    // MARK: - Initialization

    public init() {}

    // MARK: - Lifecycle

    public func activate(context: PluginContext) async throws {
        self.context = context
        context.pluginExtensionServices.clipboardManager.startMonitoring()
        state = .active
    }

    public func deactivate() async {
        context?.pluginExtensionServices.clipboardManager.stopMonitoring()
        state = .inactive
    }

    // MARK: - UI Slots

    @ViewBuilder
    public func expandedPanelContent() -> some View {
        if isEnabled, state.isActive, let context {
            ClipboardView(manager: context.pluginExtensionServices.clipboardManager)
        }
    }
}
