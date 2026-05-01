//
//  BoringNotchSkyLightWindow.swift
//  boringNotch
//
//  Created by Alexander on 2025-10-20.
//

import Cocoa
import SkyLightWindow
import Defaults
import Combine

extension SkyLightOperator {
    func undelegateWindow(_ window: NSWindow) {
        typealias F_SLSRemoveWindowsFromSpaces = @convention(c) (Int32, CFArray, CFArray) -> Int32
        
        let handler = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight", RTLD_NOW)
        guard let SLSRemoveWindowsFromSpaces = unsafeBitCast(
            dlsym(handler, "SLSRemoveWindowsFromSpaces"),
            to: F_SLSRemoveWindowsFromSpaces?.self
        ) else {
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

class BoringNotchSkyLightWindow: NSPanel {
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
        Defaults.publisher(.hideFromScreenRecording)
            .sink { [weak self] _ in
                self?.updateSharingType()
            }
            .store(in: &observers)
            
        Defaults.publisher(.hideNonNotchedFromMissionControl)
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
            .ignoresCycle
        ]

        let hasNotch = (self.screen?.safeAreaInsets.top ?? 0) > 0

        // NOTE: .transient is intentionally NOT used here. On macOS 16+, .transient
        // can cause windows to be hidden on external displays when combined with
        // CGSSpace management. Mission Control hiding is handled via window level instead.
        _ = hasNotch // Silence unused warning; screen type may be used for future per-display behavior

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
    
    /// Dynamic canBecomeKey: only accept key status when notch is open.
    /// This enables button clicks while preventing focus stealing when closed.
    override var canBecomeKey: Bool { isNotchOpen }
    override var canBecomeMain: Bool { false }
}
