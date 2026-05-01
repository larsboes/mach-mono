//
//  AccentCircleButton.swift
//  boringNotch
//
//  Extracted from AdvancedSettingsView.swift.
//

import SwiftUI

struct AccentCircleButton: View {
    let isSelected: Bool
    let color: Color
    var isSystemDefault: Bool = false
    var isMulticolor: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 32, height: 32)
                Circle()
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    .frame(width: 32, height: 32)
                if isSelected {
                    Circle()
                        .strokeBorder(
                            Color.white.opacity(0.5),
                            lineWidth: 2
                        )
                        .frame(width: 28, height: 28)
                }
            }
        }
        .buttonStyle(.plain)
        .help(isSystemDefault ? "Use your macOS system accent color" : "")
    }
}
