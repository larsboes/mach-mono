import SwiftUI

struct TeleprompterSettingsView: View {
    @Bindable var state: TeleprompterState

    var body: some View {
        Form {
            Section("Speed") {
                HStack {
                    Text("Scroll speed")
                    Spacer()
                    Button {
                        state.decreaseSpeed()
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Text("\(Int(state.config.speed)) px/s")
                        .font(.system(size: 12, design: .monospaced))
                        .frame(minWidth: 56, alignment: .center)

                    Button {
                        state.increaseSpeed()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Section("Display") {
                Slider(value: $state.config.fontSize, in: 10...40, step: 1) {
                    Text("Font size: \(Int(state.config.fontSize))pt")
                }

                HStack {
                    Text("Text color")
                    Spacer()
                    PrompterColorPicker(selection: $state.textColor)
                }
            }

            Section("Presentation") {
                Stepper("Countdown: \(state.countdownDuration)s", value: $state.countdownDuration, in: 0...10)

                Toggle("Pause at paragraph breaks", isOn: $state.config.pauseAtParagraph)

                if state.config.pauseAtParagraph {
                    Slider(value: $state.config.pauseDuration, in: 0.5...5, step: 0.5) {
                        Text("Pause duration: \(String(format: "%.1f", state.config.pauseDuration))s")
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
