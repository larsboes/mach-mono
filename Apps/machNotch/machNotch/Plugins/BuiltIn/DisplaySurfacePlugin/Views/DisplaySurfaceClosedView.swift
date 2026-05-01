import SwiftUI

struct DisplaySurfaceClosedView: View {
    let state: DisplaySurfaceState
    
    var body: some View {
        Group {
            switch state.content {
            case .text(let text):
                Text(text)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            case .progress(_, let value):
                ProgressView(value: value)
                    .progressViewStyle(.linear)
                    .frame(width: 40)
                    .scaleEffect(x: 1, y: 0.5)
            default:
                EmptyView()
            }
        }
        .padding(.horizontal, 8)
    }
}
