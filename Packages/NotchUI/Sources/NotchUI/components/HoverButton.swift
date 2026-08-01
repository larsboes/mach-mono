//
//  HoverButton.swift
//  machNotch
//
//  Created by Kraigo on 04.09.2024.
//

import SwiftUI

public struct HoverButton: View {
    public var icon: String
    public var iconColor: Color
    public var scale: Image.Scale
    public var action: () -> Void
    public var contentTransition: ContentTransition

    @State private var isHovering = false

    public init(
        icon: String,
        iconColor: Color = .primary,
        scale: Image.Scale = .medium,
        contentTransition: ContentTransition = .symbolEffect,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.scale = scale
        self.contentTransition = contentTransition
        self.action = action
    }

    public var body: some View {
        let size = CGFloat(scale == .large ? 36 : 28)

        Button(action: action) {
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .frame(width: size, height: size)
                .overlay {
                    Capsule()
                        .fill(isHovering ? Color.gray.opacity(0.2) : .clear)
                        .frame(width: size, height: size)
                        .overlay {
                            Image(systemName: icon)
                                .foregroundColor(iconColor)
                                .contentTransition(contentTransition)
                                .font(.system(size: scale == .large ? 20 : 14, weight: .medium))
                        }
                }
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}
