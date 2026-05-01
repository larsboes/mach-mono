import SwiftUI

@MainActor
final class DisplaySurfacePlugin: NotchPlugin {
    let id = PluginID.displaySurface
    let metadata = PluginMetadata(
        name: "Display Surface",
        description: "Generic ambient display for remote triggers",
        icon: "rectangle.inset.filled",
        category: .utilities
    )
    
    var isEnabled: Bool = true
    var state: PluginState = .inactive
    
    private let displayState = DisplaySurfaceState()
    private var context: PluginContext?
    
    func activate(context: PluginContext) async throws {
        self.context = context
        self.state = .active
        
        // Register API routes
        context.services.apiRouteRegistrar?.register(method: .post, path: "/api/v1/display/text") { [weak self] request in
            struct TextRequest: Decodable {
                let text: String
                let ttl: TimeInterval?
            }
            do {
                let req = try JSONDecoder().decode(TextRequest.self, from: request.body)
                if let self { await MainActor.run { self.displayState.setContent(.text(req.text), ttl: req.ttl) } }
                return .json(APIResponseEnvelope<APIErrorData>.success())
            } catch {
                return .json(status: 400, APIResponseEnvelope<APIErrorData>.failure("Invalid text request"))
            }
        }

        context.services.apiRouteRegistrar?.register(method: .post, path: "/api/v1/display/progress") { [weak self] request in
            struct ProgressRequest: Decodable {
                let label: String
                let value: Double
                let ttl: TimeInterval?
            }
            do {
                let req = try JSONDecoder().decode(ProgressRequest.self, from: request.body)
                if let self { await MainActor.run { self.displayState.setContent(.progress(label: req.label, value: req.value), ttl: req.ttl) } }
                return .json(APIResponseEnvelope<APIErrorData>.success())
            } catch {
                return .json(status: 400, APIResponseEnvelope<APIErrorData>.failure("Invalid progress request"))
            }
        }

        context.services.apiRouteRegistrar?.register(method: .post, path: "/api/v1/display/clear") { [weak self] _ in
            if let self { await MainActor.run { self.displayState.setContent(.clear) } }
            return .json(APIResponseEnvelope<APIErrorData>.success())
        }
    }
    
    func deactivate() async {
        self.state = .inactive
        context?.services.apiRouteRegistrar?.unregister(path: "/api/v1/display/text")
        context?.services.apiRouteRegistrar?.unregister(path: "/api/v1/display/progress")
        context?.services.apiRouteRegistrar?.unregister(path: "/api/v1/display/clear")
    }
    
    @ViewBuilder
    func closedNotchContent() -> some View {
        DisplaySurfaceClosedView(state: displayState)
    }
    
    @ViewBuilder
    func expandedPanelContent() -> some View {
        DisplaySurfaceExpandedView(state: displayState)
    }
    
    var displayRequest: DisplayRequest? {
        guard !displayState.content.isEmpty else { return nil }
        return DisplayRequest(priority: .normal, category: DisplayRequest.utility)
    }
}
