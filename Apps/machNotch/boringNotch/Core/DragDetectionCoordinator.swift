//
//  DragDetectionCoordinator.swift
//  boringNotch
//
//  Created as part of Phase 3 architectural refactoring.
//  Extracted from AppDelegate - handles drag detection for opening the notch.
//

import AppKit

/// Coordinates drag detection to open the notch when files are dragged to the notch region.
/// Extracted from AppDelegate to improve separation of concerns.
@MainActor
final class DragDetectionCoordinator {
    // MARK: - Properties

    /// UUID -> DragDropService mapping for each screen
    private var dragDetectors: [String: DragDropService] = [:]

    /// Reference to window coordinator for accessing view models and windows
    private weak var windowCoordinator: WindowCoordinator?

    /// Reference to view coordinator
    private let coordinator: any ViewCoordinating

    /// Settings for reading drag detection and display preferences
    private let settings: NotchSettings

    /// Factory for creating per-screen DragDropService instances
    private let makeDragDropService: () -> DragDropService

    // MARK: - Initialization

    init(
        windowCoordinator: WindowCoordinator,
        coordinator: any ViewCoordinating,
        settings: NotchSettings,
        makeDragDropService: @escaping @MainActor () -> DragDropService = { DragDropService() }
    ) {
        self.windowCoordinator = windowCoordinator
        self.coordinator = coordinator
        self.settings = settings
        self.makeDragDropService = makeDragDropService
    }

    // MARK: - Setup

    /// Setup drag detectors for all relevant screens
    func setupDragDetectors() {
        cleanupDragDetectors()

        guard settings.expandedDragDetection else { return }

        if settings.showOnAllDisplays {
            for screen in NSScreen.screens {
                setupDragDetectorForScreen(screen)
            }
        } else {
            let preferredScreen: NSScreen? = windowCoordinator?.window?.screen
                ?? NSScreen.screen(withUUID: coordinator.selectedScreenUUID)
                ?? NSScreen.main

            if let screen = preferredScreen {
                setupDragDetectorForScreen(screen)
            }
        }
    }

    // MARK: - Per-Screen Setup

    private func setupDragDetectorForScreen(_ screen: NSScreen) {
        guard let uuid = screen.displayUUID else { return }

        let screenFrame = screen.frame
        let notchHeight = openNotchSize.height
        let notchWidth = openNotchSize.width

        // Create notch region at the top-center of the screen where an open notch would occupy
        let notchRegion = CGRect(
            x: screenFrame.midX - notchWidth / 2,
            y: screenFrame.maxY - notchHeight,
            width: notchWidth,
            height: notchHeight
        )

        let service = makeDragDropService()
        service.updateNotchRegion(notchRegion)

        service.onDragEntersNotchRegion = { [weak self] in
            Task { @MainActor in
                self?.handleDragEntersNotchRegion(onScreen: screen)
            }
        }

        dragDetectors[uuid] = service
        service.startMonitoring()
    }

    // MARK: - Drag Handling

    private func handleDragEntersNotchRegion(onScreen screen: NSScreen) {
        guard let uuid = screen.displayUUID,
              let windowCoordinator = windowCoordinator else { return }

        if settings.showOnAllDisplays {
            if let viewModel = windowCoordinator.viewModels[uuid] {
                viewModel.open()
                viewModel.currentView = .shelf
            }
        } else {
            if let windowScreen = windowCoordinator.window?.screen, screen == windowScreen {
                windowCoordinator.primaryViewModel.open()
                windowCoordinator.primaryViewModel.currentView = .shelf
            }
        }
    }

    // MARK: - Cleanup

    func cleanupDragDetectors() {
        dragDetectors.values.forEach { service in
            service.stopMonitoring()
        }
        dragDetectors.removeAll()
    }
}
