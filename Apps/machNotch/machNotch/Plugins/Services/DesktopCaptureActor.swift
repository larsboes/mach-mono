//
//  DesktopCaptureActor.swift
//  boringNotch
//
//  Metal Liquid Glass - ScreenCaptureKit integration for desktop capture.
//  Captures the desktop behind the notch window, excluding the notch itself.
//

import AppKit
import ScreenCaptureKit

/// A Swift actor that manages ScreenCaptureKit streaming for thread-safe desktop capture.
/// Captures the desktop region behind the notch, excluding the notch window itself.
actor DesktopCaptureActor {
    // MARK: - Types
    
    struct CaptureConfiguration {
        let screen: SCDisplay
        let excludedWindowIDs: [CGWindowID]
        let captureRect: CGRect // Region to capture (notch area)
        let frameRate: Int // Target frame rate
    }
    
    enum CaptureError: Error, LocalizedError {
        case notAuthorized
        case noDisplayFound
        case streamCreationFailed
        case captureNotRunning
        
        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Screen recording permission not granted"
            case .noDisplayFound:
                return "Could not find display for capture"
            case .streamCreationFailed:
                return "Failed to create capture stream"
            case .captureNotRunning:
                return "Capture stream is not running"
            }
        }
    }
    
    // MARK: - Properties
    
    private var stream: SCStream?
    private var streamOutput: StreamOutput?
    private var isCapturing = false
    private var currentConfiguration: CaptureConfiguration?
    
    /// Continuation for delivering frames
    private var frameContinuation: AsyncStream<CVPixelBuffer>.Continuation?
    
    /// The async stream of captured frames
    private(set) var frameStream: AsyncStream<CVPixelBuffer>?
    
    // MARK: - Authorization
    
    /// Check if screen recording is authorized (without triggering a prompt)
    static func isAuthorized() async -> Bool {
        // CGPreflightScreenCaptureAccess checks WITHOUT triggering the permission dialog
        return CGPreflightScreenCaptureAccess()
    }
    
    /// Request screen recording permission by triggering the system dialog
    /// Only call this when user explicitly requests permission (e.g., clicks a button)
    static func requestPermission() async -> Bool {
        // First check if already authorized (silent check)
        if CGPreflightScreenCaptureAccess() {
            return true
        }
        
        // Request permission - this triggers the dialog
        // CGRequestScreenCaptureAccess() only shows dialog once, subsequent calls are silent
        let granted = CGRequestScreenCaptureAccess()
        
        // If first dialog was shown, user needs to grant in System Settings
        // Return current state
        return granted
    }
    
    // MARK: - Capture Control
    
    /// Start capturing the desktop for a specific screen
    /// - Parameters:
    ///   - screen: The NSScreen to capture
    ///   - excludingWindow: Optional window to exclude (the notch window)
    ///   - captureRect: The region to capture in screen coordinates
    ///   - frameRate: Target frame rate (default 30)
    func startCapture(
        screen: NSScreen,
        excludingWindowID: CGWindowID?,
        captureRect: CGRect,
        frameRate: Int = 30
    ) async throws {
        // Stop any existing capture
        if isCapturing {
            await stopCapture()
        }
        
        // Get shareable content
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            throw CaptureError.notAuthorized
        }
        
        // Find the display matching our screen
        guard let display = content.displays.first(where: { display in
            display.displayID == screen.displayID
        }) else {
            throw CaptureError.noDisplayFound
        }
        
        // Get windows to exclude
        var excludedWindows: [SCWindow] = []
        if let windowID = excludingWindowID {
            if let scWindow = content.windows.first(where: { $0.windowID == windowID }) {
                excludedWindows.append(scWindow)
            }
        }
        
        // Create content filter - capture entire display, excluding our windows
        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)
        
        // Configure stream
        let streamConfig = SCStreamConfiguration()
        
        // Set capture size to the notch region
        streamConfig.width = Int(captureRect.width * screen.backingScaleFactor)
        streamConfig.height = Int(captureRect.height * screen.backingScaleFactor)
        
        // Set source rect to capture only the notch region
        streamConfig.sourceRect = captureRect
        
        // Configure frame rate
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        
        // Pixel format - use BGRA for Metal compatibility
        streamConfig.pixelFormat = kCVPixelFormatType_32BGRA
        
        // Color settings
        streamConfig.colorSpaceName = CGColorSpace.sRGB
        
        // Don't show cursor in capture
        streamConfig.showsCursor = false
        
        // Create the stream
        let newStream = SCStream(filter: filter, configuration: streamConfig, delegate: nil)
        
        // Create frame stream
        let (stream, continuation) = AsyncStream<CVPixelBuffer>.makeStream()
        self.frameStream = stream
        self.frameContinuation = continuation
        
        // Create and add output
        let output = StreamOutput { [weak self] pixelBuffer in
            Task { [weak self] in
                await self?.handleFrame(pixelBuffer)
            }
        }
        self.streamOutput = output
        
        try newStream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
        
        // Start the stream
        try await newStream.startCapture()
        
        self.stream = newStream
        self.isCapturing = true
        self.currentConfiguration = CaptureConfiguration(
            screen: display,
            excludedWindowIDs: excludedWindows.map { $0.windowID },
            captureRect: captureRect,
            frameRate: frameRate
        )
        
        print("DesktopCaptureActor: Started capture for display \(display.displayID)")
    }
    
    /// Stop capturing
    func stopCapture() async {
        guard isCapturing, let stream = stream else { return }
        
        do {
            try await stream.stopCapture()
        } catch {
            print("DesktopCaptureActor: Error stopping capture: \(error)")
        }
        
        // Clean up
        self.stream = nil
        self.streamOutput = nil
        self.isCapturing = false
        self.currentConfiguration = nil
        self.frameContinuation?.finish()
        self.frameContinuation = nil
        
        print("DesktopCaptureActor: Stopped capture")
    }
    
    // MARK: - Private Methods
    
    private func handleFrame(_ pixelBuffer: CVPixelBuffer) {
        frameContinuation?.yield(pixelBuffer)
    }
}

// MARK: - Stream Output Handler

private class StreamOutput: NSObject, SCStreamOutput {
    private let frameHandler: (CVPixelBuffer) -> Void
    
    init(frameHandler: @escaping (CVPixelBuffer) -> Void) {
        self.frameHandler = frameHandler
        super.init()
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        frameHandler(pixelBuffer)
    }
}

// MARK: - NSScreen Extension for Display ID

private extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID ?? 0
    }
}
