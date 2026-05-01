//
//  HoverZoneManager.swift
//  boringNotch
//
//  Single source of truth for hover zone geometry.
//  Uses fixed screen coordinates, decoupled from animated view bounds.
//

import AppKit
import Foundation

/// Protocol for hover zone detection — allows test injection without screen dependencies.
@MainActor
protocol HoverZoneChecking: AnyObject {
    var isNotchOpen: Bool { get set }
    func updateHoverZone(screenUUID: String?)
    func isMouseInHoverZone() -> Bool
}

/// Manages the hover detection zone using fixed screen coordinates.
/// This ensures hover detection works correctly during open/close animations
/// because the zone doesn't change with the animated view bounds.
@MainActor
final class HoverZoneManager: HoverZoneChecking {
    /// The fixed hover zone in screen coordinates (closed)
    private(set) var closedHoverZone: CGRect = .zero

    /// The expanded hover zone in screen coordinates (open)
    private(set) var openHoverZone: CGRect = .zero

    /// Whether the notch is currently open (uses expanded zone)
    var isNotchOpen: Bool = false

    /// Padding around the notch to extend the hover area
    private let hoverPadding: CGFloat = 20

    /// Current screen UUID for zone calculation
    private var currentScreenUUID: String?

    /// Display settings for sizing calculations
    private let displaySettings: any DisplaySettings

    init(displaySettings: any DisplaySettings) {
        self.displaySettings = displaySettings
    }

    // MARK: - Public API

    /// Updates the hover zone based on the notch's closed dimensions.
    /// Call this when screen changes, NOT during animations.
    func updateHoverZone(screenUUID: String?) {
        currentScreenUUID = screenUUID
        recalculateZone()
    }

    /// Checks if the mouse is currently within the active hover zone.
    /// Uses the expanded zone when the notch is open.
    func isMouseInHoverZone() -> Bool {
        let mousePos = NSEvent.mouseLocation
        let activeZone = isNotchOpen ? openHoverZone : closedHoverZone
        return activeZone.contains(mousePos)
    }

    /// Forces recalculation of both hover zones (closed and open).
    func recalculateZone() {
        guard let screenFrame = getScreenFrame(currentScreenUUID) else {
            closedHoverZone = .zero
            openHoverZone = .zero
            return
        }

        // Closed zone
        let closedSize = getClosedNotchSize(settings: displaySettings, screenUUID: currentScreenUUID)
        closedHoverZone = zoneRect(screenFrame: screenFrame, size: closedSize)

        // Open zone
        openHoverZone = zoneRect(screenFrame: screenFrame, size: openNotchSize)
    }

    private func zoneRect(screenFrame: CGRect, size: CGSize) -> CGRect {
        let x = screenFrame.midX - (size.width / 2) - hoverPadding
        let y = screenFrame.maxY - size.height - hoverPadding
        return CGRect(
            x: x,
            y: y,
            width: size.width + (2 * hoverPadding),
            height: size.height + (2 * hoverPadding)
        )
    }
}
