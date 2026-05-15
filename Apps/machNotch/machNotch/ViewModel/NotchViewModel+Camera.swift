//
//  NotchViewModel+Camera.swift
//  machNotch — mach-mono
//
//  Webcam preview toggle. Permission actions are handled inside the mirror tile.
//

extension NotchViewModel {

    func toggleCameraPreview() {
        guard !isRequestingAuthorization else { return }

        switch services.webcam.authorizationStatus {
        case .authorized:
            flipRunningCameraSession()
        case .denied, .restricted, .notDetermined:
            isCameraExpanded = true
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

}
