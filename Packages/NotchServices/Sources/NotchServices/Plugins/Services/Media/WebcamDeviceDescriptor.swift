//
//  WebcamDeviceDescriptor.swift
//  machNotch
//

import AVFoundation

public struct WebcamDeviceDescriptor: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let isBuiltIn: Bool

    public var displayName: String {
        isBuiltIn ? "\(name) (Built-in)" : name
    }

    public init(id: String, name: String, isBuiltIn: Bool) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
    }

    public static func discover() -> [WebcamDeviceDescriptor] {
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
