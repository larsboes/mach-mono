//
//  ShelfActionService.swift
//  boringNotch
//
//  Created by Alexander on 2025-10-07.
//

import AppKit
import Foundation

/// A service providing common actions for `ShelfItem`s, such as opening, revealing, or copying paths.
@MainActor
enum ShelfActionService {

    static func open(_ item: ShelfItem) {
        switch item.kind {
        case .file(let bookmarkData):
            _ = Bookmark(data: bookmarkData).withAccess { url in
                NSWorkspace.shared.open(url)
            }
        case .link(let url):
            NSWorkspace.shared.open(url)
        case .text(let string):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(string, forType: .string)
        }
    }

    static func reveal(_ item: ShelfItem) {
        guard case .file(let bookmarkData) = item.kind else { return }
        Bookmark(data: bookmarkData).withAccess { url in
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    static func copyPath(_ item: ShelfItem) {
        guard case .file(let bookmarkData) = item.kind else { return }
        Bookmark(data: bookmarkData).withAccess { url in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url.path, forType: .string)
        }
    }

    static func remove(_ item: ShelfItem, service: ShelfServiceProtocol) {
        service.remove(item)
    }
}

// MARK: - Copied URLs

extension ShelfActionService {
    static var copiedURLs: [URL] = []

    static func stopAccessingCopiedURLs() {
        for url in copiedURLs {
            url.stopAccessingSecurityScopedResource()
        }
        copiedURLs.removeAll()
    }
}

// MARK: - Context Menu Handler

@MainActor
final class ShelfContextMenuHandler {
    static func present(event: NSEvent, in view: NSView, item: ShelfItem, service: ShelfServiceProtocol, quickLookService: any QuickLookServiceProtocol, quickShareService: QuickShareService) {
        ensureContextMenuSelection(item: item, service: service)
        let menu = NSMenu()

        func addMenuItem(title: String) {
            let mi = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            menu.addItem(mi)
        }

        let selection = service.selection
        let selectedItems = selection.selectedItems(in: service.items)
        let selectedFileURLs = selectedItems.compactMap { $0.fileURL }
        let selectedLinkURLs: [URL] = selectedItems.compactMap { itm in
            if case .link(let url) = itm.kind { return url }
            return nil
        }
        // URLs valid for Open/Open With (exclude folders)
        let selectedOpenableURLs = selectedItems.compactMap { itm -> URL? in
            if let u = itm.fileURL { return isDirectory(u) ? nil : u }
            if case .link(let url) = itm.kind { return url }
            return nil
        }

        if !selectedOpenableURLs.isEmpty {
            addMenuItem(title: "Open")
        }

        if !selectedOpenableURLs.isEmpty {
            buildOpenWithSubmenu(menu: menu, item: item, selectedOpenableURLs: selectedOpenableURLs)
        }

        if !selectedFileURLs.isEmpty { addMenuItem(title: "Show in Finder") }
        // Allow Quick Look for files and link URLs
        if !selectedFileURLs.isEmpty || !selectedLinkURLs.isEmpty {
            let quickLookItem = NSMenuItem(title: "Quick Look", action: nil, keyEquivalent: "")
            menu.addItem(quickLookItem)

            let slideshowItem = NSMenuItem(title: "Quick Look", action: nil, keyEquivalent: "")
            slideshowItem.isAlternate = true
            slideshowItem.keyEquivalentModifierMask = [.option]
            menu.addItem(slideshowItem)
        }

        menu.addItem(NSMenuItem.separator())
        addMenuItem(title: "Share…")

        buildImageActionsSubmenu(menu: menu, service: service, selectedFileURLs: selectedFileURLs)

        if !selectedFileURLs.isEmpty {
            let compressItem = NSMenuItem(title: "Compress", action: nil, keyEquivalent: "")
            menu.addItem(compressItem)
        }

        if selectedItems.count == 1, case .file = item.kind { addMenuItem(title: "Rename") }

        addMenuItem(title: "Copy")
        if !selectedFileURLs.isEmpty {
            let copyPathItem = NSMenuItem(title: "Copy Path", action: nil, keyEquivalent: "")
            copyPathItem.isAlternate = true
            copyPathItem.keyEquivalentModifierMask = [.option]
            menu.addItem(copyPathItem)
        }

        menu.addItem(NSMenuItem.separator())
        addMenuItem(title: "Remove")

        let actionTarget = ShelfMenuActionTarget(item: item, view: view, service: service, quickLookService: quickLookService, quickShareService: quickShareService)
        wireMenuTargets(menu: menu, target: actionTarget)

        menu.retainActionTarget(actionTarget)
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    // MARK: - Private Helpers

    private static func ensureContextMenuSelection(item: ShelfItem, service: ShelfServiceProtocol) {
        let selection = service.selection
        if !selection.isSelected(item.id) { selection.selectSingle(item) }
    }

    static func isDirectory(_ url: URL) -> Bool {
        return url.accessSecurityScopedResource { scoped in
            (try? scoped.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        }
    }

    static func defaultAppURL(for url: URL?) -> URL? {
        guard let url = url else { return nil }
        if let uti = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
             return NSWorkspace.shared.urlForApplication(toOpen: uti)
        }
        return NSWorkspace.shared.urlForApplication(toOpen: url)
    }

    static func appDisplayName(for url: URL) -> String {
        return FileManager.default.displayName(atPath: url.path)
    }

    static func nsAppIcon(for url: URL, size: CGFloat) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: size, height: size)
        return icon
    }

    private static func buildOpenWithSubmenu(menu: NSMenu, item: ShelfItem, selectedOpenableURLs: [URL]) {
        let openWith = NSMenuItem(title: "Open With", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        let baseURLForApps: URL? = {
            if let u = item.fileURL, !isDirectory(u) { return u }
            if case .link(let u) = item.kind { return u }
            return selectedOpenableURLs.first
        }()

        let openWithApps: [URL] = {
            guard let u = baseURLForApps else { return [] }
            if u.isFileURL {
                var results = NSWorkspace.shared.urlsForApplications(toOpen: u)
                if results.isEmpty, let uti = try? u.resourceValues(forKeys: [.contentTypeKey]).contentType {
                    results = NSWorkspace.shared.urlsForApplications(toOpen: uti)
                }
                return Array(Set(results))
            } else {
                return Array(Set(NSWorkspace.shared.urlsForApplications(toOpen: u)))
            }
        }()
        let defaultApp = defaultAppURL(for: baseURLForApps)

        if openWithApps.isEmpty {
            let noApps = NSMenuItem(title: "No Compatible Apps Found", action: nil, keyEquivalent: "")
            noApps.isEnabled = false
            submenu.addItem(noApps)
        } else {
            if let defaultApp = defaultApp {
                let appName = appDisplayName(for: defaultApp)
                let def = NSMenuItem(title: appName, action: nil, keyEquivalent: "")
                def.representedObject = defaultApp
                def.image = nsAppIcon(for: defaultApp, size: 16)

                let title = NSMutableAttributedString(string: appName, attributes: [
                    .font: NSFont.menuFont(ofSize: 0),
                    .foregroundColor: NSColor.labelColor
                ])
                let defaultPart = NSAttributedString(string: " (default)", attributes: [
                    .font: NSFont.menuFont(ofSize: 0),
                    .foregroundColor: NSColor.secondaryLabelColor
                ])
                title.append(defaultPart)
                def.attributedTitle = title
                submenu.addItem(def)

                if openWithApps.count > 1 || !openWithApps.contains(defaultApp) {
                    submenu.addItem(NSMenuItem.separator())
                }
            }
            for appURL in openWithApps where appURL != defaultApp {
                let mi = NSMenuItem(title: appDisplayName(for: appURL), action: nil, keyEquivalent: "")
                mi.representedObject = appURL
                mi.image = nsAppIcon(for: appURL, size: 16)
                submenu.addItem(mi)
            }
        }

        submenu.addItem(NSMenuItem.separator())
        let other = NSMenuItem(title: "Other…", action: nil, keyEquivalent: "")
        other.representedObject = "__OTHER__"
        submenu.addItem(other)

        openWith.submenu = submenu
        menu.addItem(openWith)
    }

    private static func buildImageActionsSubmenu(menu: NSMenu, service: ShelfServiceProtocol, selectedFileURLs: [URL]) {
        let imageProcessor = service.imageProcessor
        let imageURLs = selectedFileURLs.filter { imageProcessor.isImageFile($0) }
        guard !imageURLs.isEmpty else { return }

        menu.addItem(NSMenuItem.separator())

        let imageActions = NSMenuItem(title: "Image Actions", action: nil, keyEquivalent: "")
        let imageSubmenu = NSMenu()

        if imageURLs.count == 1 {
            let removeBg = NSMenuItem(title: "Remove Background", action: nil, keyEquivalent: "")
            imageSubmenu.addItem(removeBg)
        }

        if imageURLs.count == 1 {
            let convertItem = NSMenuItem(title: "Convert Image…", action: nil, keyEquivalent: "")
            imageSubmenu.addItem(convertItem)
        }

        let createPDF = NSMenuItem(title: "Create PDF", action: nil, keyEquivalent: "")
        imageSubmenu.addItem(createPDF)

        imageActions.submenu = imageSubmenu
        menu.addItem(imageActions)
        menu.addItem(NSMenuItem.separator())
    }

    private static func wireMenuTargets(menu: NSMenu, target: ShelfMenuActionTarget) {
        for menuItem in menu.items {
            if menuItem.isSeparatorItem { continue }
            menuItem.target = target
            menuItem.action = #selector(ShelfMenuActionTarget.handle(_:))

            if let submenu = menuItem.submenu {
                for subItem in submenu.items {
                    if !subItem.isSeparatorItem {
                        subItem.target = target
                        subItem.action = #selector(ShelfMenuActionTarget.handle(_:))
                    }
                }
            }
        }
    }
}
