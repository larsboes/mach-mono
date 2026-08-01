//
//  machNotchApp.swift
//  machNotchApp
//
//  Created by Harsh Vardhan  Goswami  on 02/08/24.
//

import AppKit
import Sparkle
import SwiftUI

/// Sparkle user driver delegate to handle gentle reminders for background updates
final class SparkleUserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool {
        return true
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        // No-op: Let Sparkle handle showing updates normally
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        // No-op: User has acknowledged the update
    }

    func standardUserDriverWillFinishUpdateSession() {
        // No-op: Update session is finishing
    }
}

public struct MachNotchAppRoot: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) var openWindow

    let updaterController: SPUStandardUpdaterController
    private let userDriverDelegate = SparkleUserDriverDelegate()

    public init() {
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

        #if DEBUG
            let startUpdater = false
        #else
            let startUpdater = !isRunningTests
        #endif
        updaterController = SPUStandardUpdaterController(
            startingUpdater: startUpdater, updaterDelegate: nil, userDriverDelegate: userDriverDelegate)

        // Pass the updater controller to appDelegate for wiring in applicationDidFinishLaunching
        appDelegate.updaterController = updaterController
    }

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private var showMenuBarIconBinding: Binding<Bool> {
        Binding(
            get: { appDelegate.graph.settings.menubarIcon },
            set: { appDelegate.graph.settings.menubarIcon = $0 }
        )
    }

    public var body: some Scene {
        MenuBarExtra("mach.notch", systemImage: "sparkle", isInserted: showMenuBarIconBinding) {
            PluginMenuBarItems()
            Button("Settings") {
                appDelegate.graph.settingsWindowController.showWindow()
            }
            .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
            CheckForUpdatesView(updater: updaterController.updater)
            Divider()
            Button("Restart machNotch") {
                ApplicationRelauncher.restart()
            }
            Button("Quit", role: .destructive) {
                NSApplication.shared.terminate(self)
            }
            .keyboardShortcut(KeyEquivalent("Q"), modifiers: .command)
        }
        .environment(\.pluginManager, appDelegate.graph.pluginManager)
    }
}
