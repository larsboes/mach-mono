//
//  AudioCaptureServiceProtocol.swift
//  boringNotch
//
//  Protocol for capturing system audio output as PCM samples.
//

import Foundation

@MainActor
protocol AudioCaptureServiceProtocol: AnyObject, Observable {
    var isCapturing: Bool { get }

    /// Start capturing. May trigger screen recording permission dialog on first call.
    func startCapture() async throws

    func stopCapture() async

    /// Handler receives Float PCM arrays on MainActor.
    func setBufferHandler(_ handler: @escaping @MainActor ([Float]) -> Void)
}
