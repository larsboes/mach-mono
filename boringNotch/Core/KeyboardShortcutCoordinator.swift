//
//  KeyboardShortcutCoordinator.swift
//  boringNotch
//
//  Created as part of Phase 3 architectural refactoring.
//  Extracted from AppDelegate - handles keyboard shortcut registration and actions.
//

import AppKit
import KeyboardShortcuts

/// Coordinates keyboard shortcuts for the notch.
/// Extracted from AppDelegate to improve separation of concerns.
@MainActor
final class KeyboardShortcutCoordinator {
    // MARK: - Properties

    private let coordinator: any ViewCoordinating
    private let eventBus: PluginEventBus
    private let windowCoordinator: WindowCoordinator
    private let settings: NotchSettings
    private var closeNotchTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        coordinator: any ViewCoordinating,
        eventBus: PluginEventBus,
        windowCoordinator: WindowCoordinator,
        settings: NotchSettings
    ) {
        self.coordinator = coordinator
        self.eventBus = eventBus
        self.windowCoordinator = windowCoordinator
        self.settings = settings
    }

    // MARK: - Setup

    /// Register all keyboard shortcuts
    func setupKeyboardShortcuts() {
        setupToggleSneakPeekShortcut()
        setupToggleNotchOpenShortcut()
    }

    // MARK: - Toggle Sneak Peek

    private func setupToggleSneakPeekShortcut() {
        KeyboardShortcuts.onKeyDown(for: .toggleSneakPeek) { [weak self] in
            guard let self = self else { return }
            self.handleToggleSneakPeek()
        }
    }

    private func handleToggleSneakPeek() {
        if settings.sneakPeekStyles == .inline {
            if !coordinator.expandingView.show {
                eventBus.emit(SneakPeekRequestedEvent(
                    sourcePluginId: PluginID.System.keyboard,
                    request: SneakPeekRequest(style: .inline, type: .music)
                ))
            } else {
                coordinator.toggleExpandingView(status: false, type: .music, value: 0, browser: .chromium)
            }
        } else {
            if !coordinator.sneakPeek.show {
                eventBus.emit(SneakPeekRequestedEvent(
                    sourcePluginId: PluginID.System.keyboard,
                    request: SneakPeekRequest(style: .standard, type: .music)
                ))
            } else {
                coordinator.toggleSneakPeek(status: false, type: .music, duration: 1.5, value: 0, icon: "")
            }
        }
    }

    // MARK: - Toggle Notch Open

    private func setupToggleNotchOpenShortcut() {
        KeyboardShortcuts.onKeyDown(for: .toggleNotchOpen) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.handleToggleNotchOpen()
            }
        }
    }

    private func handleToggleNotchOpen() async {
        let mouseLocation = NSEvent.mouseLocation
        let viewModel = windowCoordinator.viewModel(at: mouseLocation)

        closeNotchTask?.cancel()
        closeNotchTask = nil

        switch viewModel.notchState {
        case .closed:
            viewModel.open()

            let task = Task { [weak viewModel] in
                do {
                    try await Task.sleep(for: .seconds(3))
                } catch { return }
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    viewModel?.close()
                }
            }
            closeNotchTask = task

        case .open:
            viewModel.close()
        }
    }

    nonisolated deinit {
        MainActor.assumeIsolated {
            closeNotchTask?.cancel()
        }
    }

    // MARK: - Cleanup

    func cancelPendingTasks() {
        closeNotchTask?.cancel()
        closeNotchTask = nil
    }
}

// Note: Keyboard shortcut names are defined in Shortcuts/ShortcutConstants.swift
