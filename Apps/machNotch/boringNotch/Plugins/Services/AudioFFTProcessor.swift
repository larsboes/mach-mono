//
//  AudioFFTProcessor.swift
//  boringNotch
//
//  Converts raw PCM samples into normalized frequency band magnitudes.
//  Uses Accelerate vDSP for real-time performance.
//
//  Not actor-isolated — call exclusively from a single serial context (MainActor is fine).
//

import Accelerate
import Foundation

@MainActor
final class AudioFFTProcessor {

    let bandCount: Int

    /// 0 = no smoothing, values close to 1 = very sluggish.
    var smoothingFactor: Float = 0.3
    var peakDecayRate: Float = 0.015

    private let fftSize: Int = 1024
    /// Samples to advance between windows. 2048 → ~21fps at 44100Hz.
    private let hopSize: Int = 2048
    private let log2n: vDSP_Length
    private let fftSetup: FFTSetup?
    private let window: [Float]
    private var previousBands: [Float]
    private var peakBands: [Float]
    /// Accumulates incoming PCM samples across calls until we have a full window.
    private var sampleAccumulator: [Float] = []

    init(bandCount: Int = 32) {
        self.bandCount = bandCount
        self.previousBands = [Float](repeating: 0, count: bandCount)
        self.peakBands = [Float](repeating: 0, count: bandCount)

        let n = vDSP_Length(log2(Double(1024)))
        self.log2n = n
        self.fftSetup = vDSP_create_fftsetup(n, FFTRadix(kFFTRadix2))

        var w = [Float](repeating: 0, count: 1024)
        vDSP_hann_window(&w, vDSP_Length(1024), Int32(vDSP_HANN_NORM))
        self.window = w
    }

    deinit { 
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup) 
        }
    }

    /// Returns (bands, peaks) once a full hop-aligned window is ready; nil while accumulating.
    func process(_ samples: [Float]) -> (bands: [Float], peaks: [Float])? {
        guard let setup = fftSetup else {
            return (bands: [Float](repeating: 0, count: bandCount), peaks: [Float](repeating: 0, count: bandCount))
        }

        sampleAccumulator.append(contentsOf: samples)
        guard sampleAccumulator.count >= hopSize else { return nil }

        // Use first fftSize samples as the analysis window; advance by hopSize.
        let windowSamples = Array(sampleAccumulator.prefix(fftSize))
        sampleAccumulator.removeFirst(hopSize)
        if sampleAccumulator.count > hopSize * 4 {
            sampleAccumulator.removeFirst(sampleAccumulator.count - hopSize * 2)
        }

        var windowed = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(windowSamples, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        let halfN = fftSize / 2
        var realPart = [Float](repeating: 0, count: halfN)
        var imagPart = [Float](repeating: 0, count: halfN)
        var rawBands = [Float](repeating: 0, count: bandCount)

        realPart.withUnsafeMutableBufferPointer { rBuf in
            imagPart.withUnsafeMutableBufferPointer { iBuf in
                var split = DSPSplitComplex(realp: rBuf.baseAddress!, imagp: iBuf.baseAddress!)
                windowed.withUnsafeBufferPointer { wBuf in
                    wBuf.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { cPtr in
                        vDSP_ctoz(cPtr, 2, &split, 1, vDSP_Length(halfN))
                    }
                }
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                var magnitudes = [Float](repeating: 0, count: halfN)
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(halfN))
                rawBands = mapToBands(magnitudes: magnitudes, halfN: halfN)
            }
        }

        return applySmoothing(rawBands: rawBands)
    }

    private func mapToBands(magnitudes: [Float], halfN: Int) -> [Float] {
        var rawBands = [Float](repeating: 0, count: bandCount)
        for band in 0..<bandCount {
            let lowFrac = pow(Float(band) / Float(bandCount), 2.0)
            let highFrac = pow(Float(band + 1) / Float(bandCount), 2.0)
            let lowBin = Int(lowFrac * Float(halfN))
            let highBin = min(Int(highFrac * Float(halfN)), halfN - 1)
            guard highBin >= lowBin else { continue }
            var sum: Float = 0
            var count: Float = 0
            for bin in lowBin...highBin {
                sum += magnitudes[bin]
                count += 1
            }
            if count > 0 {
                let normFactor = 1.0 / Float(halfN * halfN)
                let normalizedPower = (sum / count) * normFactor
                let db = 10.0 * log10f(max(normalizedPower, 1e-10))
                rawBands[band] = max(0, min(1, (db + 80) / 80))
            }
        }
        return rawBands
    }

    private func applySmoothing(rawBands: [Float]) -> (bands: [Float], peaks: [Float]) {
        var bands = [Float](repeating: 0, count: bandCount)
        for i in 0..<bandCount {
            bands[i] = smoothingFactor * previousBands[i] + (1 - smoothingFactor) * rawBands[i]
            previousBands[i] = bands[i]
            if bands[i] > peakBands[i] {
                peakBands[i] = bands[i]
            } else {
                peakBands[i] = max(0, peakBands[i] - peakDecayRate)
            }
        }
        return (bands, peakBands)
    }
}
