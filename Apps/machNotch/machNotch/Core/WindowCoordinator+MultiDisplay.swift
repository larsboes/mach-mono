//
//  WindowCoordinator+MultiDisplay.swift
//  machNotch
//
//  Extracted multi-display support from WindowCoordinator.
//

import AppKit
import SwiftUI

extension WindowCoordinator {
    func adjustMultiDisplayWindows(changeAlpha: Bool) {
        let currentScreenUUIDs = Set(ScreenDisplayRegistry.shared.screensByUUID.keys)

        // Remove windows for screens that no longer exist
        for uuid in windows.keys where !currentScreenUUIDs.contains(uuid) {
            if let window = windows[uuid] {
                window.close()
                spaceManager.notchSpace.unregister(window)
                windows.removeValue(forKey: uuid)
                viewModels.removeValue(forKey: uuid)
            }
        }

        // Create or update windows for all screens
        for screen in ScreenDisplayRegistry.shared.currentScreens {
            guard let uuid = screen.displayUUID else { continue }

            if windows[uuid] == nil {
                let viewModel = NotchViewModel(
                    screenUUID: uuid,
                    coordinator: coordinator,
                    detector: detector,
                    services: pluginManager.services,
                    settings: DefaultNotchViewModelSettings(source: settings),
                    displaySettings: settings
                )
                let stateMachine = NotchStateMachine(
                    viewModel: viewModel,
                    coordinator: coordinator,
                    pluginManager: pluginManager,
                    settings: settings
                )
                let window = createNotchWindow(for: screen, with: viewModel, stateMachine: stateMachine)

                windows[uuid] = window
                viewModels[uuid] = viewModel
                stateMachines[uuid] = stateMachine
            }

            if let window = windows[uuid] {
                positionWindow(window, on: screen, changeAlpha: changeAlpha)
            }
        }
    }

    func adjustSingleDisplayWindow(changeAlpha: Bool) {
        let selectedScreen: NSScreen

        if let preferredScreen = NSScreen.screen(withUUID: coordinator.preferredScreenUUID ?? "") {
            coordinator.selectedScreenUUID = coordinator.preferredScreenUUID ?? ""
            selectedScreen = preferredScreen
        } else if settings.automaticallySwitchDisplay, let mainScreen = NSScreen.main ?? ScreenDisplayRegistry.shared.currentScreens.first,
                  let mainUUID = mainScreen.displayUUID {
            coordinator.selectedScreenUUID = mainUUID
            selectedScreen = mainScreen
        } else {
            if let window = window {
                window.alphaValue = 0
            }
            return
        }

        primaryViewModel.screenUUID = selectedScreen.displayUUID
        primaryViewModel.updateNotchSize()

        if window == nil {
            window = createNotchWindow(for: selectedScreen, with: primaryViewModel, stateMachine: primaryStateMachine)
        }

        if let window = window {
            positionWindow(window, on: selectedScreen, changeAlpha: changeAlpha)
        }
    }

    // MARK: - SkyLight Window Support (Lock Screen)

    func enableSkyLightOnAllWindows() {
        if settings.showOnAllDisplays {
            windows.values.forEach { window in
                if let skyWindow = window as? NotchSkyLightWindow {
                    skyWindow.enableSkyLight()
                }
            }
        } else {
            if let skyWindow = window as? NotchSkyLightWindow {
                skyWindow.enableSkyLight()
            }
        }
    }

    func disableSkyLightOnAllWindows() {
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            await MainActor.run {
                if self.settings.showOnAllDisplays {
                    self.windows.values.forEach { window in
                        if let skyWindow = window as? NotchSkyLightWindow {
                            skyWindow.disableSkyLight()
                        }
                    }
                } else {
                    if let skyWindow = self.window as? NotchSkyLightWindow {
                        skyWindow.disableSkyLight()
                    }
                }
            }
        }
    }
}
