//
//  AmbientGlowVisualizer.swift
//  boringNotch
//
//  Endel-inspired generative visualization below the closed notch.
//  Canvas-based for performance — particles, orbital curves, and waves.
//
//  Supports two drive modes:
//  - Pure generative (frequencyBands empty): time-based animation only
//  - Audio-reactive (frequencyBands provided): FFT energy modulates amplitude,
//    orbit speed, wave scale, and particle brightness
//

import SwiftUI

struct AmbientGlowVisualizer: View {
    let albumColor: Color
    let isPlaying: Bool
    let height: CGFloat
    var frequencyBands: [Float] = []

    var body: some View {
        if isPlaying {
            TimelineView(.animation(minimumInterval: 1.0 / 8)) { timeline in
                Canvas { context, size in
                    draw(in: &context, size: size, time: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
            .frame(height: height)
            .clipped()
        }
    }

    // MARK: - Audio Energy Helpers

    /// Overall RMS energy [0..1]
    private var energy: Double {
        guard !frequencyBands.isEmpty else { return 0 }
        let sum = frequencyBands.reduce(0.0) { $0 + Double($1) }
        return min(1, sum / Double(frequencyBands.count))
    }

    /// Bass energy (bands 0–3) [0..1]
    private var bassEnergy: Double {
        guard frequencyBands.count >= 4 else { return 0 }
        return Double(frequencyBands[0...3].reduce(0, +)) / 4.0
    }

    /// Mid energy (bands 8–16) [0..1]
    private var midEnergy: Double {
        guard frequencyBands.count >= 17 else { return 0 }
        return Double(frequencyBands[8...16].reduce(0, +)) / 9.0
    }

    /// Treble energy (bands 17–31) [0..1]
    private var trebleEnergy: Double {
        guard frequencyBands.count >= 32 else { return 0 }
        return Double(frequencyBands[17...31].reduce(0, +)) / 15.0
    }

    // MARK: - Draw

    private func draw(in ctx: inout GraphicsContext, size: CGSize, time: Double) {
        drawWaves(in: &ctx, size: size, time: time)
        drawOrbits(in: &ctx, size: size, time: time)
        drawSweep(in: &ctx, size: size, time: time)
        drawParticles(in: &ctx, size: size, time: time)
    }

    // MARK: - Undulating waves

    private func drawWaves(in ctx: inout GraphicsContext, size: CGSize, time: Double) {
        // Bass drives wave amplitude in audio-reactive mode
        let ampScale = frequencyBands.isEmpty ? 1.0 : (1.0 + bassEnergy * 2.5)

        for layer in 0..<3 {
            let seed = Double(layer) * 1.3
            let yBase = size.height * (0.6 + Double(layer) * 0.13)
            let amp = size.height * 0.035 * ampScale
            let freq = 0.012 + Double(layer) * 0.004
            let spd = 0.25 + seed * 0.08

            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height))
            for x in stride(from: 0, through: size.width, by: 5) {
                let y = yBase
                    + sin(x * freq + time * spd + seed) * amp
                    + cos(x * freq * 0.6 + time * spd * 0.4) * amp * 0.5
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.closeSubpath()

            let opacity = (0.04 + Double(layer) * 0.02) * (frequencyBands.isEmpty ? 1.0 : (1.0 + bassEnergy * 1.5))
            ctx.fill(path, with: .color(albumColor.opacity(min(0.3, opacity))))
        }
    }

    // MARK: - Orbital elliptical curves

    private func drawOrbits(in ctx: inout GraphicsContext, size: CGSize, time: Double) {
        // Mid energy speeds up orbit rotation
        let speedMult = frequencyBands.isEmpty ? 1.0 : (1.0 + midEnergy * 1.5)

        for i in 0..<2 {
            let seed = Double(i) * 2.71
            let cx = size.width * 0.5
            let cy = size.height * (0.3 + Double(i) * 0.12)
            let rx = size.width * (0.3 + sin(time * 0.07 + seed) * 0.1)
            let ry = size.height * (0.1 + cos(time * 0.05 + seed) * 0.04)
            let rot = time * 0.04 * speedMult * (i == 0 ? 1.0 : -1.0) + seed
            let arcLen = Double.pi * 1.5 + sin(time * 0.08 + seed) * 0.4

            var path = Path()
            let steps = 30
            for j in 0...steps {
                let t = Double(j) / Double(steps) * arcLen
                let px = cx + cos(t + rot) * rx
                let py = cy + sin(t + rot) * ry
                if j == 0 { path.move(to: CGPoint(x: px, y: py)) } else { path.addLine(to: CGPoint(x: px, y: py)) }
            }

            let alpha = 0.1 + sin(time * 0.15 + seed) * 0.05 + (frequencyBands.isEmpty ? 0 : midEnergy * 0.12)
            ctx.stroke(path, with: .color(.white.opacity(min(0.45, alpha))), lineWidth: 0.8)
        }
    }

    // MARK: - Sweeping bezier

    private func drawSweep(in ctx: inout GraphicsContext, size: CGSize, time: Double) {
        let phase = time * 0.03
        let startX = size.width * (0.05 + sin(phase) * 0.1)
        let startY = size.height * (0.45 + cos(phase * 0.7) * 0.1)
        let endX = size.width * (0.95 + cos(phase * 0.8) * 0.1)
        let endY = size.height * (0.7 + sin(phase * 1.1) * 0.15)
        let cp1 = CGPoint(x: size.width * 0.35, y: size.height * (0.25 + sin(phase * 0.6) * 0.15))
        let cp2 = CGPoint(x: size.width * 0.7, y: size.height * (0.8 + cos(phase * 0.9) * 0.1))

        var path = Path()
        path.move(to: CGPoint(x: startX, y: startY))
        path.addCurve(to: CGPoint(x: endX, y: endY), control1: cp1, control2: cp2)

        let alpha = 0.08 + (frequencyBands.isEmpty ? 0 : energy * 0.10)
        ctx.stroke(path, with: .color(.white.opacity(min(0.3, alpha))), lineWidth: 1.0)
    }

    // MARK: - Floating particles

    private func drawParticles(in ctx: inout GraphicsContext, size: CGSize, time: Double) {
        // Treble energy adds extra particle brightness
        let brightBoost = frequencyBands.isEmpty ? 0.0 : trebleEnergy * 0.15

        for i in 0..<8 {
            let seed = Double(i) * 1.618
            let x = size.width * (0.08 + 0.84 * (sin(time * 0.04 * (1 + seed * 0.07) + seed * 2.1) + 1) / 2)
            let y = size.height * (0.05 + 0.9 * (cos(time * 0.03 * (1 + seed * 0.06) + seed * 1.7) + 1) / 2)
            let r = 2.0 + sin(seed * 3.14) * 2.5
            let isRing = i % 3 != 0
            let alpha = min(0.5, 0.15 + sin(time * 0.25 + seed * 0.7) * 0.12 + brightBoost)

            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            let circle = Circle().path(in: rect)

            if isRing {
                ctx.stroke(circle, with: .color(.white.opacity(alpha)), lineWidth: 1)
            } else {
                ctx.fill(circle, with: .color(albumColor.opacity(alpha)))
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black
        VStack(spacing: 0) {
            Rectangle().fill(.black).frame(width: 300, height: 38)
            AmbientGlowVisualizer(albumColor: .purple, isPlaying: true, height: 160)
                .frame(width: 300)
        }
    }
    .frame(width: 400, height: 300)
}
