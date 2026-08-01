//
//  CustomSlider.swift
//  machNotch
//
//  Created by Refactoring Agent on 2025-12-30.
//

import SwiftUI

public struct CustomSlider: View {
    @Binding public var value: Double
    public var range: ClosedRange<Double>
    public var color: Color
    @Binding public var dragging: Bool
    @Binding public var lastDragged: Date
    public var onValueChange: ((Double) -> Void)?
    public var onDragChange: ((Double) -> Void)?

    public init(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        color: Color = .white,
        dragging: Binding<Bool>,
        lastDragged: Binding<Date>,
        onValueChange: ((Double) -> Void)? = nil,
        onDragChange: ((Double) -> Void)? = nil
    ) {
        self._value = value
        self.range = range
        self.color = color
        self._dragging = dragging
        self._lastDragged = lastDragged
        self.onValueChange = onValueChange
        self.onDragChange = onDragChange
    }

    public var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = CGFloat(dragging ? 6 : 4)
            let rangeSpan = range.upperBound - range.lowerBound

            let progress = rangeSpan == .zero ? 0 : (value - range.lowerBound) / rangeSpan
            let filledTrackWidth = min(max(progress, 0), 1) * width

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.gray.opacity(0.25))
                    .frame(height: height)

                Rectangle()
                    .fill(color)
                    .frame(width: filledTrackWidth, height: height)
            }
            .cornerRadius(height / 2)
            .frame(height: 8)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        withAnimation(.easeOut(duration: 0.15)) {
                            dragging = true
                        }
                        let newValue = range.lowerBound + Double(gesture.location.x / width) * rangeSpan
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                        onDragChange?(value)
                    }
                    .onEnded { _ in
                        onValueChange?(value)
                        withAnimation(.easeOut(duration: 0.15)) {
                            dragging = false
                        }
                        lastDragged = Date()
                    }
            )
            .animation(.easeOut(duration: 0.15), value: dragging)
        }
    }
}
