//
//  ClipboardPlugin.swift
//  boringNotch
//
//  Created by Agent on 02/01/26.
//

import SwiftUI

@MainActor
@Observable
final class ClipboardPlugin: NotchPlugin {
    
    // MARK: - NotchPlugin
    
    let id = PluginID.clipboard
    
    let metadata = PluginMetadata(
        name: "Clipboard",
        description: "View and manage clipboard history",
        icon: "doc.on.clipboard",
        version: "1.0.0",
        author: "boringNotch",
        category: .utilities
    )
    
    var isEnabled: Bool = true

    private(set) var state: PluginState = .inactive
    private var context: PluginContext?

    // MARK: - Initialization

    init() {}

    // MARK: - Lifecycle

    func activate(context: PluginContext) async throws {
        self.context = context
        context.services.clipboardManager.startMonitoring()
        state = .active
    }

    func deactivate() async {
        context?.services.clipboardManager.stopMonitoring()
        state = .inactive
    }
    
    // MARK: - UI Slots
    
    @ViewBuilder
    func expandedPanelContent() -> some View {
        if isEnabled, state.isActive, let context {
            ClipboardView(manager: context.services.clipboardManager)
        }
    }
}
