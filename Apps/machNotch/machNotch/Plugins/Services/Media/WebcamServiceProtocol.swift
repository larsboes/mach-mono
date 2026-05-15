//
//  WebcamServiceProtocol.swift
//  machNotch
//
//  Created by Agent on 01/01/26.
//

import AVFoundation
import Foundation
import SwiftUI

@MainActor
protocol WebcamServiceProtocol: Observable {
    var previewLayer: AVCaptureVideoPreviewLayer? { get }
    var isSessionRunning: Bool { get }
    var cameraAvailable: Bool { get }
    var authorizationStatus: AVAuthorizationStatus { get }
    var availableCameras: [WebcamDeviceDescriptor] { get }
    var selectedCameraID: String { get set }

    func startSession()
    func stopSession()
    func refreshAuthorizationStatus()
    func refreshCameraDevices()
    func checkAndRequestVideoAuthorization()
}
