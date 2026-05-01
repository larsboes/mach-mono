import SwiftUI

struct DisplaySurfaceExpandedView: View {
    let state: DisplaySurfaceState
    
    var body: some View {
        VStack(spacing: 12) {
            switch state.content {
            case .text(let text):
                Text(text)
                    .font(.system(size: 14, weight: .medium))
                    .multilineTextAlignment(.center)
            case .markdown(let md):
                Text(md) // Simplified for MVP
                    .font(.system(size: 14))
            case .progress(let label, let value):
                VStack(spacing: 8) {
                    Text(label)
                        .font(.system(size: 12, weight: .bold))
                    ProgressView(value: value)
                        .progressViewStyle(.linear)
                    Text("\(Int(value * 100))%")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            case .keyValue(let pairs):
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(pairs, id: \.0) { key, value in
                        HStack {
                            Text(key).bold()
                            Spacer()
                            Text(value).foregroundStyle(.secondary)
                        }
                        .font(.system(size: 12))
                    }
                }
            case .clear:
                Text("Inactive")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 280)
    }
}
