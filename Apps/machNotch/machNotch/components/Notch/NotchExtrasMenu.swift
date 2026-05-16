import SwiftUI

private struct NotchMenuTile: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .medium))
                    .frame(height: 22)
                Text(title)
                    .font(.body)
            }
            .foregroundStyle(.white)
            .frame(width: 70, height: 70)
            .background(.black, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.5), radius: 10)
        }
        .buttonStyle(.plain)
    }
}

struct NotchExtrasMenu: View {
    var vm: NotchViewModel
    @Environment(\.showSettingsWindow) var showSettingsWindow

    var body: some View {
        HStack(spacing: 20) {
            NotchMenuTile(
                title: "Hide",
                systemImage: "arrow.down.forward.and.arrow.up.backward"
            ) {
                vm.close(force: true)
            }

            NotchMenuTile(title: "Settings", systemImage: "gear") {
                showSettingsWindow()
            }

            NotchMenuTile(title: "Exit", systemImage: "xmark") {
                NSApp.terminate(nil)
            }
        }
    }
}

#Preview {
    NotchExtrasMenu(vm: .init())
}
