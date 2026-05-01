//
//  MockAudioCaptureService.swift
//  boringNotch
//
//  Fallback capture service for macOS <13 or denied screen recording permission.
//  Generates composite sine waves to produce semi-realistic FFT output.
//

import Foundation

@Observable
@MainActor
final class MockAudioCaptureService: AudioCaptureServiceProtocol {

    private(set) var isCapturing = false
    private var timer: Timer?
    private var bufferHandler: (@MainActor ([Float]) -> Void)?
    private var phase: Float = 0

    func startCapture() async throws {
        guard !isCapturing else { return }
        isCapturing = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    func stopCapture() async {
        timer?.invalidate()
        timer = nil
        isCapturing = false
    }

    func setBufferHandler(_ handler: @escaping @MainActor ([Float]) -> Void) {
        bufferHandler = handler
    }

    private func tick() {
        phase += 0.1
        var samples = [Float](repeating: 0, count: 1024)
        for i in 0..<1024 {
            let t = Float(i) / 1024.0
            samples[i] = sinf(2.0 * .pi * 3.0 * t + phase) * 0.3
                + sinf(2.0 * .pi * 7.0 * t + phase * 1.3) * 0.2
                + sinf(2.0 * .pi * 13.0 * t + phase * 0.7) * 0.15
                + Float.random(in: -0.1...0.1)
        }
        bufferHandler?(samples)
    }
}
