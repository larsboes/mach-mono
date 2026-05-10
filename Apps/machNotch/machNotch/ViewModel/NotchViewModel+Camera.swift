//
//  NotchViewModel+Camera.swift
//  machNotch — mach-mono
//
//  Webcam preview toggle with System Settings hand-off when access is denied.
//

import AppKit

extension NotchViewModel {

    func toggleCameraPreview() {
        guard !isRequestingAuthorization else { return }

        switch services.webcam.authorizationStatus {
        case .authorized:
            flipRunningCameraSession()
        case .denied, .restricted:
            promptOpenCameraPrivacySettings()
        case .notDetermined:
            requestInitialCameraAuthorization()
        default:
            break
        }
    }

    private func flipRunningCameraSession() {
        if services.webcam.isSessionRunning {
            services.webcam.stopSession()
            isCameraExpanded = false
        } else if services.webcam.cameraAvailable {
            services.webcam.startSession()
            isCameraExpanded = true
        }
    }

    private func promptOpenCameraPrivacySettings() {
        Task { @MainActor in
NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)

            let alert = NSAlert()
            alert.messageText = "Camera Access Required"
            alert.informativeText = "Please allow camera access in System Settings."
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Cancel")

            if alert.runModal() == .alertFirstButtonReturn,
               let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                NSWorkspace.shared.open(url)
            }

            NSApp.setActivationPolicy(.accessory)
            NSApp.deactivate()
        }
    }

    private func requestInitialCameraAuthorization() {
        isRequestingAuthorization = true
        services.webcam.checkAndRequestVideoAuthorization()
        Task { @MainActor [weak self] in
            
    try? await Task.sleep(nanoseconds: 2000000000)
self?.isRequestingAuthorization = false
        }
    }
}
