//
//  WebcamServiceProtocol.swift
//  boringNotch
//
//  Created by Agent on 01/01/26.
//

import Foundation
import AVFoundation
import SwiftUI

@MainActor
protocol WebcamServiceProtocol: Observable {
    var previewLayer: AVCaptureVideoPreviewLayer? { get }
    var isSessionRunning: Bool { get }
    var cameraAvailable: Bool { get }
    var authorizationStatus: AVAuthorizationStatus { get }
    
    func startSession()
    func stopSession()
    func checkAndRequestVideoAuthorization()
}
