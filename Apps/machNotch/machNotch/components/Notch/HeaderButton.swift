import SwiftUI

/// Reusable header button component — eliminates copy-paste boilerplate in BoringHeader.
struct HeaderButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            NSApp.keyWindow?.makeFirstResponder(nil)
            action()
        }) {
            ZStack {
                Color.black.opacity(0.001)
                Image(systemName: icon)
                    .foregroundColor(isActive ? .white : .gray)
                    .imageScale(.medium)
                    .frame(width: 30, height: 30)
                    .background(
                        Capsule().fill(isActive ? Color(nsColor: .secondarySystemFill) : .black)
                    )
            }
            .frame(width: 34, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Header button variant that is always styled as inactive (no toggle state).
struct HeaderActionButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            NSApp.keyWindow?.makeFirstResponder(nil)
            action()
        }) {
            ZStack {
                Color.black.opacity(0.001)
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .imageScale(.medium)
                    .frame(width: 30, height: 30)
                    .background(Capsule().fill(.black))
            }
            .frame(width: 34, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
