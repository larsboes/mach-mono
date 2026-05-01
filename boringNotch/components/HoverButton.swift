//
//  HoverButton.swift
//  boringNotch
//
//  Created by Kraigo on 04.09.2024.
//

import SwiftUI

struct HoverButton: View {
    var icon: String
    var iconColor: Color = .primary
    var scale: Image.Scale = .medium
    var action: () -> Void
    var contentTransition: ContentTransition = .symbolEffect
    
    @State private var isHovering = false

    var body: some View {
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
