//
//  TrackingAreaView.swift
//  boringNotch
//
//  Signal-based hover detection. Only emits signals, validation is done
//  by HoverZoneManager in BoringViewModel.
//

import AppKit
import SwiftUI

/// Signal types for hover events
enum HoverSignal {
    case entered
    case exited
}

/// A view that detects mouse enter/exit and emits signals.
/// Uses a large fixed tracking rect to avoid spurious events during animation.
struct TrackingAreaView: NSViewRepresentable {
    let onSignal: (HoverSignal) -> Void

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.onSignal = onSignal
        return view
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        nsView.onSignal = onSignal
    }

    class TrackingView: NSView {
        var onSignal: ((HoverSignal) -> Void)?

        private var trackingArea: NSTrackingArea?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()

            if let trackingArea = trackingArea {
                removeTrackingArea(trackingArea)
            }

            // Use a large fixed rect instead of dynamic bounds.
            // This prevents spurious exit events during open/close animations.
            // The actual hover zone validation is done by HoverZoneManager.
            let largeRect = NSRect(x: -500, y: -500, width: 2000, height: 2000)

            let options: NSTrackingArea.Options = [
                .mouseEnteredAndExited,
                .activeAlways
            ]

            trackingArea = NSTrackingArea(
                rect: largeRect,
                options: options,
                owner: self,
                userInfo: nil
            )

            addTrackingArea(trackingArea!)
        }

        override func mouseEntered(with event: NSEvent) {
            onSignal?(.entered)
        }

        override func mouseExited(with event: NSEvent) {
            onSignal?(.exited)
        }
    }
}
