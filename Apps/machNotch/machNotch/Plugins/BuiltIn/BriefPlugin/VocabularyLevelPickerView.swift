//
//  VocabularyLevelPickerView.swift
//  machNotch
//

import MachBriefKit
import SwiftUI

struct VocabularyLevelPickerView: View {
    let onSelect: (VocabularyLevel) -> Void

    @State private var hovered: VocabularyLevel? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Pick your level")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("We'll tailor your daily word.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            HStack(spacing: 10) {
                ForEach(VocabularyLevel.allCases, id: \.self) { level in
                    LevelCard(level: level, isHovered: hovered == level)
                        .onHover { hovering in hovered = hovering ? level : nil }
                        .onTapGesture { onSelect(level) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: hovered)
    }
}

private struct LevelCard: View {
    let level: VocabularyLevel
    let isHovered: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: level.systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isHovered ? .white : Color(white: 0.6))
            Text(level.displayName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isHovered ? .white : Color(white: 0.75))
            Text(level.description)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(white: isHovered ? 0.18 : 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color(white: isHovered ? 0.35 : 0.18), lineWidth: 1)
                )
        )
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .contentShape(Rectangle())
    }
}
