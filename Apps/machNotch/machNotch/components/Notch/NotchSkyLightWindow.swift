//
//  NotchSkyLightWindow.swift
//  machNotch
//
//  Created by Alexander on 2025-10-20.
//

import Cocoa
import Combine
import Defaults
import SkyLightWindow

extension SkyLightOperator {
    func undelegateWindow(_ window: NSWindow) {
        typealias F_SLSRemoveWindowsFromSpaces = @convention(c) (Int32, CFArray, CFArray) -> Int32

        let handler = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight", RTLD_NOW)
        guard
            let SLSRemoveWindowsFromSpaces = unsafeBitCast(
                dlsym(handler, "SLSRemoveWindowsFromSpaces"),
                to: F_SLSRemoveWindowsFromSpaces?.self
            )
        else {
            return
        }

        // Remove the window from the SkyLight space
        _ = SLSRemoveWindowsFromSpaces(
            connection,
            [window.windowNumber] as CFArray,
            [space] as CFArray
        )
    }
}

class NotchSkyLightWindow: NSPanel {
    private let settings: NotchSettings
    private var isSkyLightEnabled: Bool = false

    /// Whether the notch is currently open (enables click handling)
    var isNotchOpen: Bool = false

    init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        backing: NSWindow.BackingStoreType,
        defer flag: Bool,
        settings: NotchSettings
    ) {
        self.settings = settings
        super.init(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: backing,
            defer: flag
        )

        configureWindow()
        setupObservers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureWindow() {
        isFloatingPanel = true
        isOpaque = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = .clear
        isMovable = false
        level = .mainMenu + 3
        hasShadow = false
        isReleasedWhenClosed = false

        // Force dark appearance regardless of system setting
        appearance = NSAppearance(named: .darkAqua)

        updateCollectionBehavior()

        // Apply initial sharing type setting
        updateSharingType()
    }

    private func setupObservers() {
        // NOTE: Defaults.publisher is required because DefaultsNotchSettings uses
        // @Observable with computed properties, which don't trigger observation tracking.
        // The settings protocol is used for value access; reactive streams need Defaults.

        // Listen for changes to the hideFromScreenRecording setting
        Defaults.publisher(DefaultsNotchSettings.hideFromScreenRecordingKey)
            .sink { [weak self] _ in
                self?.updateSharingType()
            }
            .store(in: &observers)

        Defaults.publisher(DefaultsNotchSettings.hideNonNotchedFromMissionControlKey)
            .sink { [weak self] _ in
                self?.updateCollectionBehavior()
            }
            .store(in: &observers)

        NotificationCenter.default.publisher(for: NSWindow.didChangeScreenNotification, object: self)
            .sink { [weak self] _ in
                self?.updateCollectionBehavior()
            }
            .store(in: &observers)
    }

    private func updateCollectionBehavior() {
        let newBehavior: NSWindow.CollectionBehavior = [
            .fullScreenAuxiliary,
            .stationary,
            .canJoinAllSpaces,
            .ignoresCycle,
        ]

        let hasNotch = (self.screen?.safeAreaInsets.top ?? 0) > 0

        // NOTE: .transient is intentionally NOT used here. On macOS 16+, .transient
        // can cause windows to be hidden on external displays when combined with
        // MachWindowSpace management. Mission Control hiding is handled via window level instead.
        _ = hasNotch  // Silence unused warning; screen type may be used for future per-display behavior

        collectionBehavior = newBehavior
    }

    private func updateSharingType() {
        if settings.hideFromScreenRecording {
            sharingType = .none
        } else {
            sharingType = .readOnly
        }
    }

    func enableSkyLight() {
        if !isSkyLightEnabled {
            SkyLightOperator.shared.delegateWindow(self)
            isSkyLightEnabled = true
        }
    }

    func disableSkyLight() {
        if isSkyLightEnabled {
            SkyLightOperator.shared.undelegateWindow(self)
            isSkyLightEnabled = false
        }
    }

    private var observers: Set<AnyCancellable> = []

    deinit {
        observers.removeAll()
    }

    /// Dynamic canBecomeKey: only accept key status when notch is open.
    /// This enables button clicks while preventing focus stealing when closed.
    override var canBecomeKey: Bool { isNotchOpen }
    override var canBecomeMain: Bool { false }

    /// Intercept Tab / Shift+Tab so focus never escapes the panel.
    /// Without this, pressing Tab while the notch is open causes macOS
    /// to deactivate the panel, leaving the notch in a broken state.
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 48 {  // Tab key
            return  // swallow
        }
        super.keyDown(with: event)
    }

    /// Intercept Control+Tab (and other modifier+Tab combos) via the key-equivalent path.
    /// macOS routes modifier+Tab through performKeyEquivalent: before keyDown:, so the
    /// keyDown swallow above doesn't fire — causing the same panel-deactivation glitch.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.keyCode == 48 {  // Tab key
            return true  // swallow
        }
        return super.performKeyEquivalent(with: event)
    }
}
