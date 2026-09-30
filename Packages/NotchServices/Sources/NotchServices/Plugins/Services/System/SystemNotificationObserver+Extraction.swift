//
//  SystemNotificationObserver+Extraction.swift
//  machNotch
//
//  AX tree traversal and banner content extraction.
//  Extracted from SystemNotificationObserver.swift.
//

import AppKit
import ApplicationServices

extension SystemNotificationObserver {
    /// Walks the banner windows once. Returns whether any banner window exists,
    /// which is what tells the scan burst whether to keep going.
    func scanNotificationBanners() -> Bool {
        var sawWindow = false

        for app in Self.notificationCenterApps() {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            guard let windows = axAttribute(axApp, kAXWindowsAttribute) as? [AXUIElement], !windows.isEmpty else {
                continue
            }
            sawWindow = true
            for window in windows {
                extractNotifications(from: window)
            }
        }

        return sawWindow
    }

    /// Resolved only when the running-app set changes, not per scan — the
    /// localized name match below walks every running application.
    static func notificationCenterApps() -> [NSRunningApplication] {
        let bundled = notificationCenterBundleIDs.flatMap { bundleID in
            NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        }

        let named = NSWorkspace.shared.runningApplications.filter { app in
            (app.localizedName ?? "").localizedCaseInsensitiveContains("notification")
        }

        var seenPIDs = Set<pid_t>()
        return (bundled + named).filter { app in
            seenPIDs.insert(app.processIdentifier).inserted
        }
    }

    // MARK: - AX Tree Traversal

    private func extractNotifications(from element: AXUIElement) {
        let role = axAttribute(element, kAXRoleAttribute) as? String
        let subrole = axAttribute(element, kAXSubroleAttribute) as? String

        // Notification banners are typically AXGroup or AXNotificationCenter elements
        if role == kAXGroupRole as String || subrole == "AXNotificationCenterAlert"
            || subrole == "AXNotificationCenterBanner"
        {
            if let notification = extractNotificationContent(from: element) {
                guard recordIfNew(notification) else { return }
                report(notification)
                return
            }
        }

        // Recursively traverse children
        guard let children = axAttribute(element, kAXChildrenAttribute) as? [AXUIElement] else {
            return
        }

        for child in children {
            extractNotifications(from: child)
        }
    }

    private func extractNotificationContent(from element: AXUIElement) -> NotchNotification? {
        // Try to extract title and body from the notification element's children
        var title: String?
        var body: String?
        var appName: String?

        // Try direct attributes first
        title = axAttribute(element, kAXTitleAttribute) as? String
        body = axAttribute(element, kAXDescriptionAttribute) as? String

        // If no direct attributes, traverse children for static text elements
        if title == nil || body == nil {
            if let children = axAttribute(element, kAXChildrenAttribute) as? [AXUIElement] {
                var staticTexts: [String] = []
                collectStaticTexts(from: children, into: &staticTexts)

                // Typically: [app name, title, body] or [title, body]
                switch staticTexts.count {
                case 1:
                    title = title ?? staticTexts[0]
                case 2:
                    title = title ?? staticTexts[0]
                    body = body ?? staticTexts[1]
                case 3...:
                    appName = staticTexts[0]
                    title = title ?? staticTexts[1]
                    body = body ?? staticTexts[2]
                default:
                    break
                }
            }
        }

        guard let notifTitle = title, !notifTitle.isEmpty else { return nil }

        return NotchNotification(
            title: notifTitle,
            message: body ?? "",
            category: .app,
            sourceApp: appName
        )
    }

    private func collectStaticTexts(from elements: [AXUIElement], into texts: inout [String]) {
        for element in elements {
            let role = axAttribute(element, kAXRoleAttribute) as? String
            if role == kAXStaticTextRole as String {
                if let value = axAttribute(element, kAXValueAttribute) as? String, !value.isEmpty {
                    texts.append(value)
                }
            }
            // Recurse into children (max 3 levels deep to avoid excessive traversal)
            if texts.count < 5, let children = axAttribute(element, kAXChildrenAttribute) as? [AXUIElement] {
                collectStaticTexts(from: children, into: &texts)
            }
        }
    }

    // MARK: - AX Helpers

    private func axAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return result == .success ? value : nil
    }
}
