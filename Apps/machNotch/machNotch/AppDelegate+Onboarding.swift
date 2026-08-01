//
//  AppDelegate+Onboarding.swift
//  machNotch
//

import AppKit
import SwiftUI

extension AppDelegate {
    func showOnboardingWindow(step: OnboardingStep = .welcome) {
        if onboardingWindowController == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
                styleMask: [.titled, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Onboarding"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.contentView = NSHostingView(
                rootView: OnboardingView(
                    step: step,
                    permissionStore: graph.permissionStore,
                    onFinish: {
                        window.orderOut(nil)
                        window.close()
                        NSApp.deactivate()
                    },
                    onOpenSettings: { [weak self] in
                        window.close()
                        self?.graph.settingsWindowController.showWindow()
                    }
                )
                .environment(graph.coordinator)
                .environment(\.pluginManager, graph.pluginManager)
                .environment(\.settings, graph.settings)
                .environment(\.bindableSettings, graph.settings)
                .environment(\.xpcHelper, graph.pluginManager.services.xpcHelper))
            window.isRestorable = false
            window.identifier = NSUserInterfaceItemIdentifier("OnboardingWindow")
            onboardingWindowController = NSWindowController(window: window)
        }

        NSApp.activate(ignoringOtherApps: true)
        onboardingWindowController?.window?.makeKeyAndOrderFront(nil)
        onboardingWindowController?.window?.orderFrontRegardless()
    }
}
