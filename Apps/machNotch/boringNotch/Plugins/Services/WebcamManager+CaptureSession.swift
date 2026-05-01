//
//  WebcamManager+CaptureSession.swift
//  boringNotch
//
//  Extracted capture session management from WebcamManager.
//

@preconcurrency import AVFoundation

extension WebcamManager {
    /// Sets up the capture session with a completion handler
    nonisolated func setupCaptureSession(completion: @escaping @Sendable (Bool) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else {
                completion(false)
                return
            }

            self.cleanupExistingSession()

            let session = AVCaptureSession()

            do {
                let discoverySession = AVCaptureDevice.DiscoverySession(
                    deviceTypes: [.external, .builtInWideAngleCamera],
                    mediaType: .video,
                    position: .unspecified
                )

                guard let videoDevice = discoverySession.devices.first else {
                    NSLog("No video devices available")
                    DispatchQueue.main.async {
                        self.isSessionRunning = false
                        self.cameraAvailable = false
                    }
                    completion(false)
                    return
                }

                NSLog("Using camera: \(videoDevice.localizedName)")

                try videoDevice.lockForConfiguration()
                defer { videoDevice.unlockForConfiguration() }

                let videoInput = try AVCaptureDeviceInput(device: videoDevice)
                guard session.canAddInput(videoInput) else {
                    throw NSError(domain: "BoringNotch.WebcamManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot add video input"])
                }

                session.beginConfiguration()
                session.sessionPreset = .high
                session.addInput(videoInput)

                let videoOutput = AVCaptureVideoDataOutput()
                videoOutput.setSampleBufferDelegate(nil, queue: nil)
                if session.canAddOutput(videoOutput) {
                    session.addOutput(videoOutput)
                }
                session.commitConfiguration()

                self.sessionContainer.session = session

                DispatchQueue.main.async {
                    self.cameraAvailable = true
                    let previewLayer = AVCaptureVideoPreviewLayer(session: session)
                    previewLayer.videoGravity = .resizeAspectFill
                    self.previewLayer = previewLayer
                    completion(true)
                }

                NSLog("Capture session setup completed successfully")
            } catch {
                NSLog("Failed to setup capture session: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isSessionRunning = false
                    self.cameraAvailable = false
                    self.previewLayer = nil
                }
                completion(false)
            }
        }
    }

    /// Cleans up an existing capture session
    nonisolated func cleanupExistingSession() {
        if let existingSession = self.sessionContainer.session {
            if existingSession.isRunning {
                existingSession.stopRunning()
            }
            existingSession.beginConfiguration()
            for input in existingSession.inputs {
                existingSession.removeInput(input)
            }
            for output in existingSession.outputs {
                existingSession.removeOutput(output)
            }
            existingSession.commitConfiguration()
            self.sessionContainer.session = nil
            DispatchQueue.main.async {
                self.previewLayer = nil
            }
        }
    }

    nonisolated func startRunningCaptureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, let session = self.sessionContainer.session, !session.isRunning else {
                return
            }
            session.startRunning()
            self.updateSessionState()
            NSLog("Capture session started successfully")
        }
    }

    nonisolated func updateSessionState() {
        let isRunning = self.sessionContainer.session?.isRunning ?? false
        DispatchQueue.main.async {
            self.isSessionRunning = isRunning
        }
    }
}
