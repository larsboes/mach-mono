//
//  NotchCameraController.swift
//  boringNotch
//
//  Extracted from BoringViewModel - handles camera preview toggle
//

import SwiftUI
import AppKit

/// Controller for managing camera preview functionality
@MainActor
@Observable class NotchCameraController {
    // MARK: - Dependencies

    private let webcamService: any WebcamServiceProtocol

    // MARK: - State

    var isCameraExpanded: Bool = false
    var isRequestingAuthorization: Bool = false

    // MARK: - Initialization

    init(webcamService: any WebcamServiceProtocol) {
        self.webcamService = webcamService
    }

    // MARK: - Camera Methods

    func toggleCameraPreview() {
        if isRequestingAuthorization {
            return
        }

        switch webcamService.authorizationStatus {
        case .authorized:
            if webcamService.isSessionRunning {
                webcamService.stopSession()
                isCameraExpanded = false
            } else if webcamService.cameraAvailable {
                webcamService.startSession()
                isCameraExpanded = true
            }

        case .denied, .restricted:
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)

                let alert = NSAlert()
                alert.messageText = "Camera Access Required"
                alert.informativeText = "Please allow camera access in System Settings."
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "Cancel")

                if alert.runModal() == .alertFirstButtonReturn {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                        NSWorkspace.shared.open(url)
                    }
                }

                NSApp.setActivationPolicy(.accessory)
                NSApp.deactivate()
            }

        case .notDetermined:
            isRequestingAuthorization = true
            webcamService.checkAndRequestVideoAuthorization()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.isRequestingAuthorization = false
            }

        default:
            break
        }
    }
}
