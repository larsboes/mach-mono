//
//  NotchCameraController.swift
//  machNotch
//
//  Extracted from NotchViewModel - handles camera preview toggle
//

import SwiftUI

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

        case .denied, .restricted, .notDetermined:
            isCameraExpanded = true

        default:
            break
        }
    }
}
