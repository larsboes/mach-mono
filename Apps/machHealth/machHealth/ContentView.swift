import SwiftUI
import HealthExportKit

struct ContentView: View {
    @State private var lastStatus = "No sync yet"

    var body: some View {
        NavigationStack {
            List {
                Section("Status") {
                    Text(lastStatus)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Metrics") {
                    ForEach(HealthMetricType.allCases, id: \.self) { metric in
                        Toggle(metric.rawValue, isOn: .constant(false))
                            .disabled(true)
                    }
                }
                .footer {
                    Text("Metrics default off. Opt in per type before export ships in H1.")
                }
            }
            .navigationTitle("machHealth")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Sync Now") {
                        lastStatus = "Exporter not wired — receiver stub ready on Mac"
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
