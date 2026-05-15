//
//  WebcamDeviceDescriptor.swift
//  machNotch
//

import AVFoundation

struct WebcamDeviceDescriptor: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let isBuiltIn: Bool

    var displayName: String {
        isBuiltIn ? "\(name) (Built-in)" : name
    }

    static func discover() -> [WebcamDeviceDescriptor] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external, .builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
        .devices
        .map {
            WebcamDeviceDescriptor(
                id: $0.uniqueID,
                name: $0.localizedName,
                isBuiltIn: $0.deviceType == .builtInWideAngleCamera
            )
        }
    }
}
