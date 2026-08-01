//
//  WebcamManager.swift
//  machNotch
//
//  Created by Harsh Vardhan  Goswami  on 19/08/24.
//
@preconcurrency import AVFoundation
import SwiftUI

@MainActor public final class WebcamManager: NSObject, WebcamServiceProtocol {
    public var previewLayer: AVCaptureVideoPreviewLayer?
    public var availableCameras: [WebcamDeviceDescriptor] = []

    final class SessionContainer: @unchecked Sendable {
        var session: AVCaptureSession?
    }

    nonisolated let sessionContainer = SessionContainer()

    private var captureSession: AVCaptureSession? {
        get { sessionContainer.session }
        set { sessionContainer.session = newValue }
    }

    public var isSessionRunning: Bool = false
    public var authorizationStatus: AVAuthorizationStatus = .notDetermined
    public var cameraAvailable: Bool = false
    let sessionQueue = DispatchQueue(label: "MachNotch.WebcamManager.SessionQueue", qos: .userInitiated)
    private var isCleaningUp: Bool = false
    private var settings: (any MediaSettings)?
    private var storedSelectedCameraID: String = ""

    public var selectedCameraID: String {
        get { settings?.selectedWebcamDeviceID ?? storedSelectedCameraID }
        set {
            if settings != nil {
                settings?.selectedWebcamDeviceID = newValue
            } else {
                storedSelectedCameraID = newValue
            }

            if isSessionRunning {
                stopSession()
                startSession()
            }
        }
    }

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

    public init(settings: (any MediaSettings)? = nil) {
        self.settings = settings
        super.init()
        NotificationCenter.default.addObserver(
            self, selector: #selector(deviceWasDisconnected), name: AVCaptureDevice.wasDisconnectedNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(deviceWasConnected), name: AVCaptureDevice.wasConnectedNotification, object: nil)
        refreshAuthorizationStatus()
        refreshCameraDevices()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if let session = sessionContainer.session {
            if session.isRunning { session.stopRunning() }
        }
    }

    // MARK: - Camera Management
    public func refreshAuthorizationStatus() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    public func refreshCameraDevices() {
        let devices = WebcamDeviceDescriptor.discover()
        availableCameras = devices
        cameraAvailable = !devices.isEmpty

        if !selectedCameraID.isEmpty, !devices.contains(where: { $0.id == selectedCameraID }) {
            selectedCameraID = ""
        }
    }

    public func checkAndRequestVideoAuthorization() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        Task { @MainActor in
            self.authorizationStatus = status
        }

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
        let availableDevices = WebcamDeviceDescriptor.discover()
        let hasAvailableDevices = !availableDevices.isEmpty
        Task { @MainActor in
            self.availableCameras = availableDevices
            self.cameraAvailable = hasAvailableDevices
        }
    }

    @objc private func deviceWasDisconnected(notification: Notification) {
        NSLog("Camera device was disconnected")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.sessionContainer.session?.stopRunning()
            Task { @MainActor in
                self.isSessionRunning = self.sessionContainer.session?.isRunning ?? false
            }
            Task { @MainActor in
                self.cameraAvailable = false
            }
        }
    }

    @objc private func deviceWasConnected(notification: Notification) {
        NSLog("Camera device was connected")
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            Task { @MainActor [weak self] in self?.checkCameraAvailability() }
        }
    }

    public func startSession() {
        let preferredDeviceID = selectedCameraID
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.sessionContainer.session == nil {
                self.setupCaptureSession(preferredDeviceID: preferredDeviceID) { success in
                    if success { self.startRunningCaptureSession() }
                }
            } else {
                self.startRunningCaptureSession()
            }
        }
    }

    public func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.isSessionRunning = false
            }
            self.cleanupExistingSession()
            NSLog("Capture session stopped and cleaned up")
        }
    }
}
