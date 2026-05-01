//
//  SpectrumBarsView.swift
//  boringNotch
//
//  CAGradientLayer-based spectrum bar renderer driven by FFT frequency bands.
//  Uses Core Animation transforms for smooth, low-overhead bar scaling.
//

import AppKit
import SwiftUI

// MARK: - NSView Renderer

final class SpectrumBarsRenderer: NSView {

    private var barLayers: [CAGradientLayer] = []
    private(set) var configuredBarCount: Int = 0
    private(set) var currentTintColor: NSColor = .systemBlue

    private let barSpacing: CGFloat = 1.5
    private let cornerRadiusFraction: CGFloat = 0.5

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.masksToBounds = true
    }

    func configure(barCount: Int) {
        guard barCount != configuredBarCount else { return }
        configuredBarCount = barCount
        barLayers.forEach { $0.removeFromSuperlayer() }
        barLayers.removeAll()

        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        for _ in 0..<barCount {
            let bar = CAGradientLayer()
            bar.anchorPoint = CGPoint(x: 0.5, y: 1.0)
            bar.startPoint = CGPoint(x: 0.5, y: 1)
            bar.endPoint = CGPoint(x: 0.5, y: 0)
            bar.contentsScale = scale
            bar.colors = gradientColors(for: currentTintColor)
            layer?.addSublayer(bar)
            barLayers.append(bar)
        }
        layoutBars()
    }

    override func layout() {
        super.layout()
        layoutBars()
    }

    private func layoutBars() {
        guard configuredBarCount > 0, bounds.width > 0 else { return }
        let totalSpacing = barSpacing * CGFloat(configuredBarCount - 1)
        let barWidth = max(1, (bounds.width - totalSpacing) / CGFloat(configuredBarCount))
        let radius = barWidth * cornerRadiusFraction

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (i, bar) in barLayers.enumerated() {
            let x = CGFloat(i) * (barWidth + barSpacing)
            bar.cornerRadius = radius
            bar.frame = CGRect(x: x, y: 0, width: barWidth, height: bounds.height)
            bar.transform = CATransform3DMakeScale(1.0, 0.05, 1.0)
        }
        CATransaction.commit()
    }

    func updateBands(_ bands: [Float]) {
        guard bands.count == barLayers.count else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (i, bar) in barLayers.enumerated() {
            bar.transform = CATransform3DMakeScale(1.0, CGFloat(max(0.05, min(1.0, bands[i]))), 1.0)
        }
        CATransaction.commit()
    }

    func setTintColor(_ color: NSColor) {
        guard !color.isApproximatelyEqual(to: currentTintColor) else { return }
        currentTintColor = color
        let colors = gradientColors(for: color)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        barLayers.forEach { $0.colors = colors }
        CATransaction.commit()
    }

    private func gradientColors(for color: NSColor) -> [CGColor] {
        [color.withAlphaComponent(0.4).cgColor, color.cgColor]
    }
}

// MARK: - SwiftUI Bridge

struct SpectrumBarsView: NSViewRepresentable {
    let bands: [Float]
    let barCount: Int
    let tintColor: Color

    func makeNSView(context: Context) -> SpectrumBarsRenderer {
        let view = SpectrumBarsRenderer()
        view.configure(barCount: barCount)
        view.setTintColor(NSColor(tintColor))
        return view
    }

    func updateNSView(_ nsView: SpectrumBarsRenderer, context: Context) {
        if nsView.configuredBarCount != barCount {
            nsView.configure(barCount: barCount)
        }
        nsView.updateBands(bands)
        nsView.setTintColor(NSColor(tintColor))
    }
}

// MARK: - NSColor Approximate Equality

private extension NSColor {
    func isApproximatelyEqual(to other: NSColor, threshold: CGFloat = 0.02) -> Bool {
        guard let c1 = usingColorSpace(.deviceRGB),
              let c2 = other.usingColorSpace(.deviceRGB) else { return false }
        return abs(c1.redComponent - c2.redComponent) < threshold
            && abs(c1.greenComponent - c2.greenComponent) < threshold
            && abs(c1.blueComponent - c2.blueComponent) < threshold
    }
}
