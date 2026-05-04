//
//  NotchWindow.swift
//  machNotch
//
//  Created by Harsh Vardhan  Goswami  on 06/08/24.
//

import Cocoa

class NotchWindow: NSPanel {
    /// Whether the notch is currently open (enables click handling)
    var isNotchOpen: Bool = false

    override init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        backing: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: backing,
            defer: flag
        )

        isFloatingPanel = true
        isOpaque = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = .clear
        isMovable = false

        collectionBehavior = [
            .fullScreenAuxiliary,
            .stationary,
            .canJoinAllSpaces,
            .ignoresCycle
        ]

        isReleasedWhenClosed = false
        level = .mainMenu + 3
        hasShadow = false
    }

    /// Dynamic canBecomeKey: only accept key status when notch is open.
    /// This enables button clicks while preventing focus stealing when closed.
    override var canBecomeKey: Bool {
        isNotchOpen
    }

    override var canBecomeMain: Bool {
        false
    }

    /// Intercept Tab / Shift+Tab so focus never escapes the panel.
    /// Without this, pressing Tab while the notch is open causes macOS
    /// to deactivate the panel, leaving the notch in a broken state.
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 48 { // Tab key
            return // swallow
        }
        super.keyDown(with: event)
    }
}
