//
//  MusicPlugin+AudioPipeline.swift
//  boringNotch
//
//  Audio capture + FFT pipeline for MusicPlugin.
//  Runs synchronously on MainActor — no extra dispatch hops.
//  SCK is only started when the visualizer is enabled in realAudio mode.
//

import Foundation

extension MusicPlugin {

    // MARK: - Setup

    func setupAudioPipeline() {
        guard let settings = mediaSettings else { return }
        let bandCount = settings.visualizerBandCount.rawValue
        let processor = AudioFFTProcessor(bandCount: bandCount)
        processor.smoothingFactor = Self.smoothingFactor(for: settings.visualizerSensitivity)
        fftProcessor = processor
        frequencyBands = Array(repeating: 0, count: bandCount)
        peakBands = Array(repeating: 0, count: bandCount)

        let service: any AudioCaptureServiceProtocol
        if #available(macOS 13.0, *) {
            service = ScreenCaptureKitAudioService()
        } else {
            service = MockAudioCaptureService()
        }

        service.setBufferHandler { [weak self] samples in
            guard let self, let result = self.fftProcessor?.process(samples) else { return }
            self.frequencyBands = result.bands
            self.peakBands = result.peaks
        }

        audioCaptureService = service
    }

    // MARK: - Capture Control

    func startAudioCapture() async {
        guard let settings = mediaSettings else { return }
        // Only run SCK + FFT for realAudio mode — simulated mode needs no audio capture.
        guard settings.ambientVisualizerEnabled,
              settings.ambientVisualizerMode == .realAudio else { return }

        fftProcessor?.smoothingFactor = Self.smoothingFactor(for: settings.visualizerSensitivity)

        guard let service = audioCaptureService, !service.isCapturing else { return }
        do {
            try await service.startCapture()
        } catch {
            // Screen recording permission denied — fall back to mock
            let mock = MockAudioCaptureService()
            mock.setBufferHandler { [weak self] samples in
                guard let self, let result = self.fftProcessor?.process(samples) else { return }
                self.frequencyBands = result.bands
                self.peakBands = result.peaks
            }
            audioCaptureService = mock
            try? await mock.startCapture()
        }
    }

    func stopAudioCapture() async {
        // Respect "show when paused" — keep capture running if enabled.
        if mediaSettings?.visualizerShowWhenPaused == true { return }
        await audioCaptureService?.stopCapture()
        let bandCount = fftProcessor?.bandCount ?? 32
        frequencyBands = Array(repeating: 0, count: bandCount)
        peakBands = Array(repeating: 0, count: bandCount)
    }

    // MARK: - Helpers

    /// Maps sensitivity [0, 1] to FFT smoothingFactor [0.7, 0.05].
    /// Higher sensitivity = less smoothing = snappier response.
    static func smoothingFactor(for sensitivity: Double) -> Float {
        Float(0.7 - sensitivity * 0.65)
    }
}
