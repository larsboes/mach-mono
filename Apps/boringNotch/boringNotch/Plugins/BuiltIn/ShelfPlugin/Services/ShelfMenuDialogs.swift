//
//  ShelfMenuDialogs.swift
//  boringNotch
//
//  Extracted from ShelfActionService.swift — Open With panel and Rename dialog.
//

import AppKit
import Foundation

extension ShelfMenuActionTarget {

    // MARK: - Rename Dialog

    @MainActor
    func showRenameDialog(for item: ShelfItem) {
        service.fileHandler.rename(item: item, newName: "", service: service) { _ in }
        guard case let .file(bookmarkData) = item.kind else { return }
        Task {
            let bookmark = Bookmark(data: bookmarkData)
            if let fileURL = bookmark.resolvedURL {
                let didStart = fileURL.startAccessingSecurityScopedResource()

                let savePanel = NSSavePanel()
                savePanel.title = "Rename File"
                savePanel.prompt = "Rename"
                savePanel.nameFieldStringValue = fileURL.lastPathComponent
                savePanel.directoryURL = fileURL.deletingLastPathComponent()
                savePanel.begin { response in
                    if response == .OK, let newURL = savePanel.url {
                        self.service.fileHandler.rename(item: item, newName: newURL.lastPathComponent, service: self.service) { success in
                            if !success {
                                print("Failed to rename file via handler")
                            }
                        }
                    }
                    if didStart { fileURL.stopAccessingSecurityScopedResource() }
                }
            }
        }
    }

    // MARK: - Open With Panel

    @MainActor
    func openWithPanel() {
        let targetURL: URL?
        let needsSecurityScope: Bool

        if let fileURL = item.fileURL {
            targetURL = fileURL
            needsSecurityScope = true
        } else if case .link(let url) = item.kind {
            targetURL = url
            needsSecurityScope = false
        } else {
            targetURL = nil
            needsSecurityScope = false
        }
        guard let fileURL = targetURL else { return }

        let panel = NSOpenPanel()
        panel.title = "Choose Application"
        panel.message = "Choose an application to open the document \"\(item.displayName)\"."
        panel.prompt = "Open"
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.resolvesAliases = true
        if #available(macOS 12.0, *) {
            panel.allowedContentTypes = [.application]
        }
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        let recommendedApps: Set<URL> = {
            let apps: [URL]
            if let uti = (try? fileURL.resourceValues(forKeys: [.contentTypeKey]))?.contentType {
                apps = NSWorkspace.shared.urlsForApplications(toOpen: uti)
            } else {
                apps = NSWorkspace.shared.urlsForApplications(toOpen: fileURL)
            }
            return Set(apps.map { $0.standardizedFileURL })
        }()

        let chooserDelegate = AppChooserDelegate(recommended: recommendedApps)
        panel.delegate = chooserDelegate

        let (column, _, alwaysCheckbox) = buildOpenWithAccessoryView(chooserDelegate: chooserDelegate, panel: panel)
        panel.accessoryView = column
        panel.isAccessoryViewDisclosed = true

        panel.begin { response in
            if response == .OK, let appURL = panel.url {
                Task {
                    do {
                        let config = NSWorkspace.OpenConfiguration()
                        if alwaysCheckbox.state == .on, let bundleID = Bundle(url: appURL)?.bundleIdentifier {
                            if let contentType = (try? fileURL.resourceValues(forKeys: [.contentTypeKey]))?.contentType {
                                let status = LSSetDefaultRoleHandlerForContentType(contentType.identifier as CFString, LSRolesMask.all, bundleID as CFString)
                                if status != noErr { print("Failed to set default handler for \(contentType.identifier): \(status)") }
                            } else if let scheme = fileURL.scheme {
                                let status = LSSetDefaultHandlerForURLScheme(scheme as CFString, bundleID as CFString)
                                if status != noErr { print("Failed to set default handler for scheme \(scheme): \(status)") }
                            }
                        }

                        if needsSecurityScope {
                            _ = try await fileURL.accessSecurityScopedResource { accessibleURL in
                                try await NSWorkspace.shared.open([accessibleURL], withApplicationAt: appURL, configuration: config)
                            }
                        } else {
                            try await NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: config)
                        }
                    } catch {
                        print("Failed to open with application: \(error.localizedDescription)")
                    }
                }
            }
            _ = chooserDelegate
        }
    }

    private func buildOpenWithAccessoryView(chooserDelegate: AppChooserDelegate, panel: NSOpenPanel) -> (NSStackView, NSPopUpButton, NSButton) {
        let enableLabel = NSTextField(labelWithString: "Enable:")
        enableLabel.font = .systemFont(ofSize: NSFont.systemFontSize)
        enableLabel.alignment = .natural
        enableLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.addItems(withTitles: ["Recommended Applications", "All Applications"])
        popup.font = .systemFont(ofSize: NSFont.systemFontSize)
        popup.selectItem(at: 0)
        popup.setContentHuggingPriority(.defaultLow, for: .horizontal)
        popup.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true

        let alwaysCheckbox = NSButton(checkboxWithTitle: "Always Open With", target: nil, action: nil)
        alwaysCheckbox.font = .systemFont(ofSize: NSFont.systemFontSize)
        alwaysCheckbox.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [enableLabel, popup])
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        row.distribution = .fill

        let column = NSStackView(views: [row, alwaysCheckbox])
        column.orientation = .vertical
        column.spacing = 12
        column.alignment = .centerX
        column.distribution = .fill
        column.edgeInsets = NSEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)

        let binder = PopupBinder(popup: popup, chooserDelegate: chooserDelegate, panel: panel)
        popup.target = binder
        popup.action = #selector(PopupBinder.changed(_:))

        ShelfMenuActionTarget.sliderHandlerAssoc[popup] = binder

        return (column, popup, alwaysCheckbox)
    }
}

// MARK: - AppChooserDelegate

final class AppChooserDelegate: NSObject, NSOpenSavePanelDelegate {
    enum Mode { case recommended, all }
    var mode: Mode = .recommended
    let recommended: Set<URL>
    init(recommended: Set<URL>) { self.recommended = recommended }

    func panel(_ sender: Any, shouldEnable url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if ext == "app" {
            switch mode {
            case .all:
                return true
            case .recommended:
                return recommended.contains(url.standardizedFileURL)
            }
        }

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return true
        }
        return false
    }
}

// MARK: - PopupBinder

class PopupBinder: NSObject {
    weak var popup: NSPopUpButton?
    weak var chooserDelegate: AppChooserDelegate?
    weak var panel: NSOpenPanel?

    init(popup: NSPopUpButton, chooserDelegate: AppChooserDelegate, panel: NSOpenPanel) {
        self.popup = popup
        self.chooserDelegate = chooserDelegate
        self.panel = panel
    }

    @MainActor @objc func changed(_ sender: Any?) {
        if popup?.indexOfSelectedItem == 1 {
            chooserDelegate?.mode = .all
        } else {
            chooserDelegate?.mode = .recommended
        }
        if let panel = panel {
            panel.validateVisibleColumns()
            let currentDir = panel.directoryURL
            panel.directoryURL = currentDir
        }
    }
}
