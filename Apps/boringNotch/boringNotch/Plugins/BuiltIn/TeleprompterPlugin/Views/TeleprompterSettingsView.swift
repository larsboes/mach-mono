import SwiftUI

struct TeleprompterSettingsView: View {
    let state: TeleprompterState
    
    var body: some View {
        Form {
            Section("Display") {
                Slider(value: .init(get: { state.config.fontSize }, set: { state.config.fontSize = $0 }), in: 12...32, step: 1) {
                    Text("Font Size: \(Int(state.config.fontSize))pt")
                }
            }
            
            Section("Behavior") {
                Toggle("Pause at paragraph breaks", isOn: .init(get: { state.config.pauseAtParagraph }, set: { state.config.pauseAtParagraph = $0 }))
                
                if state.config.pauseAtParagraph {
                    Slider(value: .init(get: { state.config.pauseDuration }, set: { state.config.pauseDuration = $0 }), in: 0.5...5, step: 0.5) {
                        Text("Pause Duration: \(String(format: "%.1f", state.config.pauseDuration))s")
                    }
                }
            }
        }
        .padding()
    }
}
