import Combine
import Observation
import SwiftUI

import NotchPluginCore

/// A complete third-party plugin, built against the public SDK only.
///
/// It implements the six required members, one optional UI slot, and shows the
/// three things every plugin needs: scoped services, namespaced settings, and
/// event subscriptions that are released on deactivation.
@MainActor
@Observable
public final class HelloPlugin: NotchPlugin {

    // MARK: - Identity

    public let id = "com.example.hello"

    public let metadata = PluginMetadata(
        name: "Hello",
        description: "Greets you, and follows the current track",
        icon: "hand.wave",
        version: "1.0.0",
        author: "Example",
        category: .utilities
    )

    public var isEnabled = false
    public private(set) var state: PluginState = .inactive

    // MARK: - Plugin state

    private var greeting = "Hello"
    private var nowPlaying: String?
    private var subscription: AnyCancellable?

    public init() {}

    // MARK: - Lifecycle

    public func activate(context: PluginContext) async throws {
        // Namespaced under the plugin id, so it cannot collide with another plugin.
        greeting = context.settings.get("greeting", default: "Hello")

        // Only reachable because the descriptor declares `.mediaServices`.
        nowPlaying = context.mediaServices.music.currentTrack?.title

        subscription = context.eventBus.subscribe(to: MusicTrackChangedEvent.self) { [weak self] event in
            self?.nowPlaying = event.newTrack?.title
        }

        state = .active
    }

    public func deactivate() async {
        // Release everything activate() acquired. A retained subscription here is
        // the most common leak in a plugin.
        subscription = nil
        nowPlaying = nil
        state = .inactive
    }

    // MARK: - UI

    public func expandedPanelContent() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(greeting), world")
                .font(.headline)

            if let nowPlaying {
                Text("Now playing: \(nowPlaying)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
