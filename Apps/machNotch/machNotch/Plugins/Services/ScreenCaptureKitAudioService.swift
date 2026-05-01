//
//  ScreenCaptureKitAudioService.swift
//  boringNotch
//
//  Captures system audio via ScreenCaptureKit.
//  Requires macOS 13+. Uses minimal dummy video to satisfy SCStream requirements.
//

import Foundation
import ScreenCaptureKit
import AVFoundation

@available(macOS 13.0, *)
@Observable
@MainActor
final class ScreenCaptureKitAudioService: AudioCaptureServiceProtocol {

    private(set) var isCapturing = false
    private var stream: SCStream?
    private var audioOutput: AudioStreamOutput?
    private var videoOutput: DummyVideoOutput?
    private var bufferHandler: (@MainActor ([Float]) -> Void)?

    func startCapture() async throws {
        guard !isCapturing else { return }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first else {
            throw AudioCaptureError.noDisplay
        }

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = false
        config.channelCount = 1
        config.sampleRate = 44100
        // Minimize video overhead — we only want audio
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 60, timescale: 1) // ~0.017fps

        let filter = SCContentFilter(display: display, excludingWindows: [])

        let audio = AudioStreamOutput { [weak self] samples in
            Task { @MainActor [weak self] in
                self?.bufferHandler?(samples)
            }
        }
        let video = DummyVideoOutput()

        // Serial queue ensures AudioStreamOutput's batch accumulator is accessed safely.
        let audioQueue = DispatchQueue(label: "com.boringnotch.sck.audio", qos: .userInteractive)
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(audio, type: .audio, sampleHandlerQueue: audioQueue)
        try stream.addStreamOutput(video, type: .screen, sampleHandlerQueue: .global(qos: .background))
        try await stream.startCapture()

        self.stream = stream
        self.audioOutput = audio
        self.videoOutput = video
        self.isCapturing = true
    }

    func stopCapture() async {
        guard isCapturing, let stream else { return }
        try? await stream.stopCapture()
        self.stream = nil
        self.audioOutput = nil
        self.videoOutput = nil
        self.isCapturing = false
    }

    func setBufferHandler(_ handler: @escaping @MainActor ([Float]) -> Void) {
        bufferHandler = handler
    }
}

// MARK: - Stream Outputs

@available(macOS 13.0, *)
private final class AudioStreamOutput: NSObject, SCStreamOutput, @unchecked Sendable {
    private let onSamples: @Sendable ([Float]) -> Void
    /// Accumulate samples on the serial audio queue before dispatching to MainActor.
    /// Reduces Task { @MainActor } creation from ~86/sec to ~21/sec.
    private var pending: [Float] = []
    private let dispatchThreshold = 2048

    init(onSamples: @escaping @Sendable ([Float]) -> Void) {
        self.onSamples = onSamples
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio,
              let blockBuffer = buffer.dataBuffer else { return }

        let totalLength = blockBuffer.dataLength
        guard totalLength > 0 else { return }

        var dataPointer: UnsafeMutablePointer<Int8>?
        var lengthAtOffset = 0
        var outLength = 0
        let status = CMBlockBufferGetDataPointer(
            blockBuffer, atOffset: 0,
            lengthAtOffsetOut: &lengthAtOffset,
            totalLengthOut: &outLength,
            dataPointerOut: &dataPointer
        )
        guard status == kCMBlockBufferNoErr, let dataPointer else { return }

        let formatDesc = CMSampleBufferGetFormatDescription(buffer)
        let bytesPerFrame = formatDesc
            .flatMap { CMAudioFormatDescriptionGetStreamBasicDescription($0)?.pointee }
            .map { Int($0.mBytesPerFrame) }
            ?? MemoryLayout<Float>.size

        let sampleCount = bytesPerFrame > 0 ? outLength / bytesPerFrame : outLength / MemoryLayout<Float>.size
        guard sampleCount > 0 else { return }

        let floatPointer = UnsafeRawPointer(dataPointer).bindMemory(to: Float.self, capacity: sampleCount)
        pending.append(contentsOf: UnsafeBufferPointer(start: floatPointer, count: sampleCount))

        guard pending.count >= dispatchThreshold else { return }
        let batch = pending
        pending.removeAll(keepingCapacity: true)
        onSamples(batch)
    }
}

@available(macOS 13.0, *)
private final class DummyVideoOutput: NSObject, SCStreamOutput, @unchecked Sendable {
    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {}
}

// MARK: - Errors

enum AudioCaptureError: Error {
    case noDisplay
}
