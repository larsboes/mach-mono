//
//  WebcamManager.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 19/08/24.
//
@preconcurrency import AVFoundation
import SwiftUI

@MainActor class WebcamManager: NSObject, WebcamServiceProtocol {
    var previewLayer: AVCaptureVideoPreviewLayer?

    final class SessionContainer: @unchecked Sendable {
        var session: AVCaptureSession?
    }

    nonisolated let sessionContainer = SessionContainer()

    private var captureSession: AVCaptureSession? {
        get { sessionContainer.session }
        set { sessionContainer.session = newValue }
    }

    var isSessionRunning: Bool = false
    var authorizationStatus: AVAuthorizationStatus = .notDetermined
    var cameraAvailable: Bool = false
    let sessionQueue = DispatchQueue(label: "BoringNotch.WebcamManager.SessionQueue", qos: .userInitiated)
    private var isCleaningUp: Bool = false

    enum WebcamError: Error, LocalizedError {
        case deviceUnavailable
        case accessDenied
        case configurationFailed(String)

        var errorDescription: String? {
            switch self {
            case .deviceUnavailable: return "No camera devices available"
            case .accessDenied: return "Camera access denied"
            case .configurationFailed(let message): return "Camera configuration failed: \(message)"
            }
        }
    }

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(deviceWasDisconnected), name: AVCaptureDevice.wasDisconnectedNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(deviceWasConnected), name: AVCaptureDevice.wasConnectedNotification, object: nil)
        checkCameraAvailability()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if let session = sessionContainer.session {
            if session.isRunning { session.stopRunning() }
        }
    }

    // MARK: - Camera Management
    func checkAndRequestVideoAuthorization() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        DispatchQueue.main.async { self.authorizationStatus = status }

        switch status {
        case .authorized: checkCameraAvailability()
        case .notDetermined: requestVideoAccess()
        case .denied, .restricted: NSLog("Camera access denied or restricted")
        @unknown default: NSLog("Unknown authorization status")
        }
    }

    private func requestVideoAccess() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            Task { @MainActor in
                self?.authorizationStatus = granted ? .authorized : .denied
                if granted { self?.checkCameraAvailability() }
            }
        }
    }

    func checkCameraAvailability() {
        let availableDevices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external, .builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        ).devices
        let hasAvailableDevices = !availableDevices.isEmpty
        DispatchQueue.main.async { self.cameraAvailable = hasAvailableDevices }
    }

    @objc private func deviceWasDisconnected(notification: Notification) {
        NSLog("Camera device was disconnected")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.sessionContainer.session?.stopRunning()
            Task { @MainActor in
                self.isSessionRunning = self.sessionContainer.session?.isRunning ?? false
            }
            DispatchQueue.main.async { self.cameraAvailable = false }
        }
    }

    @objc private func deviceWasConnected(notification: Notification) {
        NSLog("Camera device was connected")
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in self.checkCameraAvailability() }
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.sessionContainer.session == nil {
                self.setupCaptureSession { success in
                    if success { self.startRunningCaptureSession() }
                }
            } else {
                self.startRunningCaptureSession()
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async { self.isSessionRunning = false }
            self.cleanupExistingSession()
            NSLog("Capture session stopped and cleaned up")
        }
    }
}
