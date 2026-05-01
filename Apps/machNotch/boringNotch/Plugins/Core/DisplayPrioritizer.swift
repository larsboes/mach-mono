import Foundation

/// Determines which plugin should be displayed in the closed notch
/// based on display request priorities.
/// Extracted from PluginManager to separate display arbitration from registry management (SRP).
@MainActor
struct DisplayPrioritizer {
    /// Returns the plugin ID with the highest priority display request.
    static func highestPriority(among plugins: [AnyNotchPlugin]) -> String? {
        let requests = plugins.compactMap { plugin -> (id: String, request: DisplayRequest)? in
            guard let request = plugin.displayRequest else { return nil }
            return (plugin.id, request)
        }

        return requests
            .sorted { $0.request.priority > $1.request.priority }
            .first?.id
    }
}
