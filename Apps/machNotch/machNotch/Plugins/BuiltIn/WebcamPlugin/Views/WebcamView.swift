//
//  WebcamView.swift
//  machNotch
//
//  Created by Harsh Vardhan  Goswami  on 19/08/24.
//

import AVFoundation
import AppKit
import SwiftUI

struct CameraPreviewView: View {
    @Environment(PluginUIContext.self) var uiContext
    @Environment(\.settings) var settings
    let webcamManager: any WebcamServiceProtocol

    // Track if authorization request is in progress to avoid multiple requests
    @State private var isRequestingAuthorization: Bool = false

    var body: some View {
        GeometryReader { geometry in
            Button(action: handleCameraTap) {
                ZStack {
                    if let previewLayer = webcamManager.previewLayer, webcamManager.isSessionRunning {
                        CameraPreviewLayerView(previewLayer: previewLayer)
                            .scaleEffect(x: -1, y: 1)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                            .frame(width: geometry.size.width, height: geometry.size.width)
                    } else {
                        mirrorPlaceholder(size: geometry.size.width)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.width)
            }
            .buttonStyle(.plain)
            .onDisappear {
                webcamManager.stopSession()
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var cornerRadius: CGFloat {
        settings.mirrorShape == .rectangle ? MusicPlayerImageSizes.cornerRadiusInset.opened : 100
    }

    @ViewBuilder
    private func mirrorPlaceholder(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(red: 20/255, green: 20/255, blue: 20/255))
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)

            VStack(spacing: 7) {
                Image(systemName: placeholderIcon)
                    .foregroundStyle(placeholderIconColor)
                    .font(.system(size: max(size / 4.2, 22), weight: .medium))

                Text(placeholderTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primary.opacity(0.84))
                    .lineLimit(1)

                Text(placeholderSubtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 10)
            }
        }
    }

    private var placeholderIcon: String {
        switch webcamManager.authorizationStatus {
        case .authorized:
            webcamManager.cameraAvailable ? "web.camera" : "video.slash"
        case .denied, .restricted:
            "lock.shield"
        case .notDetermined:
            isRequestingAuthorization ? "hourglass" : "web.camera"
        @unknown default:
            "exclamationmark.triangle"
        }
    }

    private var placeholderIconColor: Color {
        switch webcamManager.authorizationStatus {
        case .denied, .restricted:
            .orange
        default:
            .gray
        }
    }

    private var placeholderTitle: String {
        switch webcamManager.authorizationStatus {
        case .authorized:
            webcamManager.cameraAvailable ? "Start Mirror" : "No Camera"
        case .denied, .restricted:
            "Camera Blocked"
        case .notDetermined:
            isRequestingAuthorization ? "Waiting..." : "Enable Mirror"
        @unknown default:
            "Camera Unavailable"
        }
    }

    private var placeholderSubtitle: String {
        switch webcamManager.authorizationStatus {
        case .authorized:
            webcamManager.cameraAvailable ? "Tap to open a private live preview." : "Connect a camera to use mirror mode."
        case .denied, .restricted:
            "Tap to open Camera privacy settings."
        case .notDetermined:
            isRequestingAuthorization ? "Confirm the macOS camera prompt." : "Tap once to allow camera access."
        @unknown default:
            "Camera status could not be read."
        }
    }

    private func handleCameraTap() {
        if isRequestingAuthorization {
            return // Prevent multiple authorization requests
        }
        
        switch webcamManager.authorizationStatus {
        case .authorized:
            if webcamManager.isSessionRunning {
                webcamManager.stopSession()
            } else if webcamManager.cameraAvailable {
                webcamManager.startSession()
            } else {
                webcamManager.refreshCameraDevices()
            }
        case .denied, .restricted:
            if let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                NSWorkspace.shared.open(settingsURL)
            }
        case .notDetermined:
            isRequestingAuthorization = true
            webcamManager.checkAndRequestVideoAuthorization()
            // Reset the request flag after a reasonable delay
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                webcamManager.refreshAuthorizationStatus()
                webcamManager.refreshCameraDevices()
                isRequestingAuthorization = false
            }
        @unknown default:
            break
        }
    }
}

struct CameraPreviewLayerView: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer = previewLayer
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = nsView.bounds
        CATransaction.commit()
    }
}

#Preview {
    CameraPreviewView(webcamManager: WebcamManager())
}
