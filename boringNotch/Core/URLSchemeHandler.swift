import Foundation

@MainActor
enum URLSchemeHandler {
    static func handle(_ url: URL, graph: AppObjectGraph) {
        guard url.scheme == "boringnotch" else { return }

        let path = url.host ?? ""

        switch path {
        case "open":
            NotificationCenter.default.post(name: .openNotchIntent, object: nil)
        case "close":
            NotificationCenter.default.post(name: .closeNotchIntent, object: nil)
        case "toggle":
            let isOpen = graph.vm.notchState == .open
            let notification: NSNotification.Name = isOpen ? .closeNotchIntent : .openNotchIntent
            NotificationCenter.default.post(name: notification, object: nil)
        case "plugins":
            // boringnotch://plugins?id=music
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems,
               let pluginId = queryItems.first(where: { $0.name == "id" })?.value {
                Task {
                    try? await graph.pluginManager.enablePlugin(pluginId)
                }
            }
        default:
            break
        }
    }
}
