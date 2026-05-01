import SwiftUI

private struct ShowSettingsWindowKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var showSettingsWindow: () -> Void {
        get { self[ShowSettingsWindowKey.self] }
        set { self[ShowSettingsWindowKey.self] = newValue }
    }
}
