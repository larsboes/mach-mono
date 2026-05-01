//
//  WindowCoordinator+MultiDisplay.swift
//  boringNotch
//
//  Extracted multi-display support from WindowCoordinator.
//

import AppKit
import SwiftUI

extension WindowCoordinator {
    func adjustMultiDisplayWindows(changeAlpha: Bool) {
        let currentScreenUUIDs = Set(NSScreen.screens.compactMap { $0.displayUUID })

        // Remove windows for screens that no longer exist
        for uuid in windows.keys where !currentScreenUUIDs.contains(uuid) {
            if let window = windows[uuid] {
                window.close()
                spaceManager.notchSpace.windows.remove(window)
                windows.removeValue(forKey: uuid)
                viewModels.removeValue(forKey: uuid)
            }
        }

        // Create or update windows for all screens
        for screen in NSScreen.screens {
            guard let uuid = screen.displayUUID else { continue }

            if windows[uuid] == nil {
                let viewModel = BoringViewModel(
                    screenUUID: uuid,
                    coordinator: coordinator,
                    detector: detector,
                    services: pluginManager.services,
                    displaySettings: settings
                )
                let stateMachine = NotchStateMachine(settings: settings)
                let window = createBoringNotchWindow(for: screen, with: viewModel, stateMachine: stateMachine)

                windows[uuid] = window
                viewModels[uuid] = viewModel
                stateMachines[uuid] = stateMachine
            }

            if let window = windows[uuid], let viewModel = viewModels[uuid] {
                positionWindow(window, on: screen, changeAlpha: changeAlpha)

                if viewModel.notchState == .closed {
                    viewModel.close()
                }
            }
        }
    }

    func adjustSingleDisplayWindow(changeAlpha: Bool) {
        let selectedScreen: NSScreen

        if let preferredScreen = NSScreen.screen(withUUID: coordinator.preferredScreenUUID ?? "") {
            coordinator.selectedScreenUUID = coordinator.preferredScreenUUID ?? ""
            selectedScreen = preferredScreen
        } else if settings.automaticallySwitchDisplay, let mainScreen = NSScreen.main,
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
        primaryViewModel.notchSize = getClosedNotchSize(settings: settings, screenUUID: selectedScreen.displayUUID)

        if window == nil {
            window = createBoringNotchWindow(for: selectedScreen, with: primaryViewModel, stateMachine: primaryStateMachine)
        }

        if let window = window {
            positionWindow(window, on: selectedScreen, changeAlpha: changeAlpha)

            if primaryViewModel.notchState == .closed {
                primaryViewModel.close()
            }
        }
    }

    // MARK: - SkyLight Window Support (Lock Screen)

    func enableSkyLightOnAllWindows() {
        if settings.showOnAllDisplays {
            windows.values.forEach { window in
                if let skyWindow = window as? BoringNotchSkyLightWindow {
                    skyWindow.enableSkyLight()
                }
            }
        } else {
            if let skyWindow = window as? BoringNotchSkyLightWindow {
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
                        if let skyWindow = window as? BoringNotchSkyLightWindow {
                            skyWindow.disableSkyLight()
                        }
                    }
                } else {
                    if let skyWindow = self.window as? BoringNotchSkyLightWindow {
                        skyWindow.disableSkyLight()
                    }
                }
            }
        }
    }
}
