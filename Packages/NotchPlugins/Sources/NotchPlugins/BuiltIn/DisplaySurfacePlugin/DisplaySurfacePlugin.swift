import SwiftUI

@MainActor
public final class DisplaySurfacePlugin: NotchPlugin {
    public let id = PluginID.displaySurface
    public let metadata = PluginMetadata(
        name: "Display Surface",
        description: "Generic ambient display for remote triggers",
        icon: "rectangle.inset.filled",
        category: .utilities
    )

    public var isEnabled: Bool = true
    public var state: PluginState = .inactive

    private let displayState = DisplaySurfaceState()
    private var context: PluginContext?

    public init() {}

    public func activate(context: PluginContext) async throws {
        self.context = context
        self.state = .active

        // Register API routes
        context.pluginExtensionServices.apiRouteRegistrar?.register(
            method: .post, path: "/api/v1/display/text"
        ) { [weak self] request in
            struct TextRequest: Decodable {
                let text: String
                let ttl: TimeInterval?
            }
            do {
                let req = try JSONDecoder().decode(TextRequest.self, from: request.body)
                if let self {
                    await MainActor.run {
                        self.displayState.setContent(.text(req.text), ttl: req.ttl)
                    }
                }
                return .json(APIResponseEnvelope<APIErrorData>.success())
            } catch {
                return .json(
                    status: 400, APIResponseEnvelope<APIErrorData>.failure("Invalid text request"))
            }
        }

        context.pluginExtensionServices.apiRouteRegistrar?.register(
            method: .post, path: "/api/v1/display/progress"
        ) { [weak self] request in
            struct ProgressRequest: Decodable {
                let label: String
                let value: Double
                let ttl: TimeInterval?
            }
            do {
                let req = try JSONDecoder().decode(ProgressRequest.self, from: request.body)
                if let self {
                    await MainActor.run {
                        self.displayState.setContent(
                            .progress(label: req.label, value: req.value), ttl: req.ttl)
                    }
                }
                return .json(APIResponseEnvelope<APIErrorData>.success())
            } catch {
                return .json(
                    status: 400,
                    APIResponseEnvelope<APIErrorData>.failure("Invalid progress request"))
            }
        }

        context.pluginExtensionServices.apiRouteRegistrar?.register(
            method: .post, path: "/api/v1/display/clear"
        ) { [weak self] _ in
            if let self { await MainActor.run { self.displayState.setContent(.clear) } }
            return .json(APIResponseEnvelope<APIErrorData>.success())
        }
    }

    public func deactivate() async {
        self.state = .inactive
        context?.pluginExtensionServices.apiRouteRegistrar?.unregister(path: "/api/v1/display/text")
        context?.pluginExtensionServices.apiRouteRegistrar?.unregister(
            path: "/api/v1/display/progress")
        context?.pluginExtensionServices.apiRouteRegistrar?.unregister(
            path: "/api/v1/display/clear")
    }

    @ViewBuilder
    public func closedNotchContent() -> some View {
        DisplaySurfaceClosedView(state: displayState)
    }

    @ViewBuilder
    public func expandedPanelContent() -> some View {
        DisplaySurfaceExpandedView(state: displayState)
    }

    public var displayRequest: DisplayRequest? {
        guard !displayState.content.isEmpty else { return nil }
        return DisplayRequest(priority: .normal, category: DisplayRequest.utility)
    }
}
