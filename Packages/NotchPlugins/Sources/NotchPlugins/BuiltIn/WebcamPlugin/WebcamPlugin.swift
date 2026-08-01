//
//  WebcamPlugin.swift
//  machNotch
//
//  Built-in webcam plugin.
//  Wraps WebcamManager to provide camera mirror.
//

import SwiftUI

@MainActor
@Observable
public final class WebcamPlugin: NotchPlugin {

    // MARK: - NotchPlugin

    public let id = PluginID.webcam

    public let metadata = PluginMetadata(
        name: "Webcam Mirror",
        description: "Mirror your camera in the notch",
        icon: "camera.fill",
        version: "1.0.0",
        author: "machNotch",
        category: .utilities
    )

    public var isEnabled: Bool = true

    public private(set) var state: PluginState = .inactive

    // MARK: - Dependencies

    public var webcamService: (any WebcamServiceProtocol)?
    private var settings: PluginSettings?

    // MARK: - Initialization

    public init() {}

    // MARK: - Lifecycle

    public func activate(context: PluginContext) async throws {
        state = .activating

        self.webcamService = context.uiServices.webcam
        self.settings = context.settings

        self.webcamService?.refreshAuthorizationStatus()
        self.webcamService?.refreshCameraDevices()

        state = .active
    }

    public func deactivate() async {
        webcamService?.stopSession()
        webcamService = nil
        settings = nil
        state = .inactive
    }

    // MARK: - UI Slots

    @ViewBuilder
    public func expandedPanelContent() -> some View {
        if isEnabled, state.isActive, let service = webcamService {
            CameraPreviewView(webcamManager: service)
        }
    }
}
