//
//  WebcamPlugin.swift
//  boringNotch
//
//  Built-in webcam plugin.
//  Wraps WebcamManager to provide camera mirror.
//

import SwiftUI

@MainActor
@Observable
final class WebcamPlugin: NotchPlugin {
    
    // MARK: - NotchPlugin
    
    let id = PluginID.webcam
    
    let metadata = PluginMetadata(
        name: "Webcam Mirror",
        description: "Mirror your camera in the notch",
        icon: "camera.fill",
        version: "1.0.0",
        author: "boringNotch",
        category: .utilities
    )
    
    var isEnabled: Bool = true
    
    private(set) var state: PluginState = .inactive
    
    // MARK: - Dependencies
    
    var webcamService: (any WebcamServiceProtocol)?
    private var settings: PluginSettings?
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Lifecycle
    
    func activate(context: PluginContext) async throws {
        state = .activating
        
        self.webcamService = context.services.webcam
        self.settings = context.settings
        
        // Check for camera availability
        self.webcamService?.checkAndRequestVideoAuthorization()
        
        state = .active
    }
    
    func deactivate() async {
        webcamService?.stopSession()
        webcamService = nil
        settings = nil
        state = .inactive
    }
    
    // MARK: - UI Slots
    
    @ViewBuilder
    func expandedPanelContent() -> some View {
        if isEnabled, state.isActive, let service = webcamService {
            CameraPreviewView(webcamManager: service)
        }
    }
}
