import SwiftUI
import AppKit

public func AppIcon(for bundleID: String) -> Image {
    let workspace = NSWorkspace.shared

    if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleID) {
        let appIcon = workspace.icon(forFile: appURL.path)
        return Image(nsImage: appIcon)
    }

    return Image(nsImage: workspace.icon(for: .applicationBundle))
}
