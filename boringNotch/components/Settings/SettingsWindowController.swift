//
//  SettingsWindowController.swift
//  boringNotch
//
//  Created by Alexander on 2025-06-14.
//

import AppKit
import SwiftUI
import Defaults
import Sparkle

class SettingsWindowController: NSWindowController {
    private var updaterController: SPUStandardUpdaterController?
    private var coordinator: BoringViewCoordinator?
    private var pluginManager: PluginManager?
    private var settings: DefaultsNotchSettings?
    private var hasSetupContent = false

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        // Only setup window chrome, defer content view creation until showWindow()
        setupWindowChrome()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setUpdaterController(_ controller: SPUStandardUpdaterController) {
        self.updaterController = controller
        // Mark that content needs refresh on next show
        hasSetupContent = false
    }

    func configure(coordinator: BoringViewCoordinator, pluginManager: PluginManager, settings: DefaultsNotchSettings) {
        self.coordinator = coordinator
        self.pluginManager = pluginManager
        self.settings = settings
        // Mark that content needs refresh on next show
        hasSetupContent = false
    }

    private func setupWindowChrome() {
        guard let window = window else { return }

        window.title = "Boring Notch Settings"
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.toolbarStyle = .unified
        window.isMovableByWindowBackground = true

        // Make it behave like a regular app window with proper Spaces support
        window.collectionBehavior = [.managed, .participatesInCycle, .fullScreenAuxiliary]

        // Ensure proper window behavior
        window.hidesOnDeactivate = false
        window.isExcludedFromWindowsMenu = false

        // Configure window to be a standard document-style window
        window.isRestorable = true
        window.identifier = NSUserInterfaceItemIdentifier("BoringNotchSettingsWindow")

        // Handle window closing
        window.delegate = self
    }

    private func setupContentViewIfNeeded() {
        guard let window = window, !hasSetupContent, let coordinator = coordinator, let settings = settings else { return }

        let settingsView = SettingsView(updaterController: updaterController)
            .environment(coordinator)
            .environment(\.pluginManager, pluginManager)
            .environment(\.settings, settings)
            .environment(\.bindableSettings, settings)
            .environment(\.xpcHelper, pluginManager?.services.xpcHelper)
        let hostingView = NSHostingView(rootView: settingsView)
        window.contentView = hostingView
        hasSetupContent = true
    }
    
    func showWindow() {
        // Set app to regular mode first
        NSApp.setActivationPolicy(.regular)

        // Create content view on first show (deferred to avoid early BoringViewModel access)
        setupContentViewIfNeeded()

        // If window is already visible, bring it to front properly
        if window?.isVisible == true {
            NSApp.activate(ignoringOtherApps: true)
            window?.orderFrontRegardless()
            window?.makeKeyAndOrderFront(nil)
            return
        }

        // Show the window with proper ordering
        window?.orderFrontRegardless()
        window?.makeKeyAndOrderFront(nil)
        window?.center()

        // Activate the app and ensure window gets focus
        NSApp.activate(ignoringOtherApps: true)

        // Force window to front after activation
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeKeyAndOrderFront(nil)
        }
    }
    
    override func close() {
        super.close()
        relinquishFocus()
    }
    
    private func relinquishFocus() {
        window?.orderOut(nil)
        
        // Set app back to accessory mode immediately
        NSApp.setActivationPolicy(.accessory)
    }
}

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        relinquishFocus()
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        // Ensure app is in regular mode when window becomes key
        NSApp.setActivationPolicy(.regular)
    }
    
    func windowDidResignKey(_ notification: Notification) {
    }
    
}
