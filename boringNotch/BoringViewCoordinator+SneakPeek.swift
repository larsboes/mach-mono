//
//  BoringViewCoordinator+SneakPeek.swift
//  boringNotch
//
//  Sneak peek and expanding view logic extracted from BoringViewCoordinator.
//

import AppKit
import SwiftUI

extension BoringViewCoordinator {

    @objc func sneakPeekEvent(_ notification: Notification) {
        let decoder = JSONDecoder()
        guard let rawData = notification.userInfo?.first?.value as? Data,
              let decodedData = try? decoder.decode(SharedSneakPeek.self, from: rawData) else {
            return
        }

        let contentType: SneakContentType = {
            switch decodedData.type {
            case "brightness": return .brightness
            case "volume": return .volume
            case "backlight": return .backlight
            case "mic": return .mic
            default: return .brightness
            }
        }()

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        let value = CGFloat((formatter.number(from: decodedData.value) ?? 0.0).floatValue)

        toggleSneakPeek(status: decodedData.show, type: contentType, value: value, icon: decodedData.icon)
    }

    func toggleSneakPeek(
        status: Bool, type: SneakContentType, duration: TimeInterval = 1.5, value: CGFloat = 0,
        icon: String = ""
    ) {
        sneakPeekDuration = duration == 1.5 ? settings.sneakPeakDuration : duration
        if type != .music {
            if !settings.hudReplacement {
                return
            }
        }
        // Synchronous — no Task hop. This class is @MainActor so we're already on main.
        // Wrapping in Task deferred the mutation by one tick, causing stale state reads.
        withAnimation(.smooth) {
            self.sneakPeek.show = status
            self.sneakPeek.type = type
            self.sneakPeek.value = value
            self.sneakPeek.icon = icon
        }

        if type == .mic {
            settings.currentMicStatus = value == 1
        }
    }

    func scheduleSneakPeekHide(after duration: TimeInterval) {
        sneakPeekTask?.cancel()

        sneakPeekTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard let self = self, !Task.isCancelled else { return }
            withAnimation {
                self.toggleSneakPeek(status: false, type: .music)
                self.sneakPeekDuration = self.settings.sneakPeakDuration
            }
        }
    }

    func toggleExpandingView(
        status: Bool,
        type: SneakContentType,
        value: CGFloat = 0,
        browser: BrowserType = .chromium
    ) {
        // Synchronous — no Task hop. Already on @MainActor.
        withAnimation(.smooth) {
            self.expandingView.show = status
            self.expandingView.type = type
            self.expandingView.value = value
            self.expandingView.browser = browser
        }
    }
}
