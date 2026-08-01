import SwiftUI

@MainActor
public final class TeleprompterPlugin: NotchPlugin {
    public let id = PluginID.teleprompter
    public let metadata = PluginMetadata(
        name: "Teleprompter",
        description: "Eye-contact friendly teleprompter",
        icon: "text.justify.left",
        category: .productivity
    )

    public var isEnabled: Bool = true
    public var state: PluginState = .inactive

    private let teleState = TeleprompterState()
    private var shortcutHandler: TeleprompterShortcutHandler?
    private var context: PluginContext?

    public init() {}

    public func activate(context: PluginContext) async throws {
        self.context = context
        self.state = .active

        // Wire keyboard shortcuts
        shortcutHandler = TeleprompterShortcutHandler(state: teleState)
        shortcutHandler?.register()

        // Register API routes
        context.pluginExtensionServices.apiRouteRegistrar?.register(
            method: .post, path: "/api/v1/teleprompter/load"
        ) { [weak self] request in
            guard let self else {
                return .json(
                    status: 500, APIResponseEnvelope<APIErrorData>.failure("Plugin unavailable"))
            }

            struct LoadRequest: Decodable {
                let text: String
                let speed: Double?
            }

            do {
                let loadReq = try JSONDecoder().decode(LoadRequest.self, from: request.body)
                await MainActor.run {
                    self.teleState.text = loadReq.text
                    if let speed = loadReq.speed {
                        self.teleState.config.speed = speed
                    }
                    self.teleState.reset()
                }
                return .json(APIResponseEnvelope<APIErrorData>.success())
            } catch {
                return .json(
                    status: 400, APIResponseEnvelope<APIErrorData>.failure("Invalid load request"))
            }
        }

        context.pluginExtensionServices.apiRouteRegistrar?.register(
            method: .post, path: "/api/v1/teleprompter/start"
        ) { [weak self] _ in
            if let self { await MainActor.run { self.teleState.isScrolling = true } }
            return .json(APIResponseEnvelope<APIErrorData>.success())
        }

        context.pluginExtensionServices.apiRouteRegistrar?.register(
            method: .post, path: "/api/v1/teleprompter/pause"
        ) { [weak self] _ in
            if let self { await MainActor.run { self.teleState.isScrolling = false } }
            return .json(APIResponseEnvelope<APIErrorData>.success())
        }

        context.pluginExtensionServices.apiRouteRegistrar?.register(
            method: .post, path: "/api/v1/teleprompter/stop"
        ) { [weak self] _ in
            if let self { await MainActor.run { self.teleState.reset() } }
            return .json(APIResponseEnvelope<APIErrorData>.success())
        }

        context.pluginExtensionServices.apiRouteRegistrar?.register(
            method: .get, path: "/api/v1/teleprompter/state"
        ) { [weak self] _ in
            guard let self else {
                return .json(
                    status: 500, APIResponseEnvelope<APIErrorData>.failure("Plugin unavailable"))
            }

            struct StateResponse: Encodable {
                let position: Double
                let isScrolling: Bool
                let text: String
            }

            let response = await MainActor.run {
                StateResponse(
                    position: self.teleState.scrollPosition,
                    isScrolling: self.teleState.isScrolling,
                    text: self.teleState.text
                )
            }
            return .json(APIResponseEnvelope.success(response))
        }

        nonisolated(unsafe) let aiService = context.pluginExtensionServices.ai
        context.pluginExtensionServices.apiRouteRegistrar?.register(
            method: .post, path: "/api/v1/teleprompter/ai-assist"
        ) { [weak self] request in
            guard let self else {
                return .json(
                    status: 500, APIResponseEnvelope<APIErrorData>.failure("Plugin unavailable"))
            }

            struct AIRequest: Decodable {
                let action: TeleprompterAIAction
            }

            do {
                let aiReq = try JSONDecoder().decode(AIRequest.self, from: request.body)
                try await self.teleState.aiAssist(action: aiReq.action, ai: aiService)
                return .json(APIResponseEnvelope<APIErrorData>.success())
            } catch _ as DecodingError {
                return .json(
                    status: 400,
                    APIResponseEnvelope<APIErrorData>.failure(
                        "Invalid action. Valid: refine, summarize, draft-intro"))
            } catch {
                return .json(
                    status: 500,
                    APIResponseEnvelope<APIErrorData>.failure(error.localizedDescription))
            }
        }
    }

    public func deactivate() async {
        self.state = .inactive
        self.teleState.reset()
        shortcutHandler?.unregister()
        shortcutHandler = nil
        context?.pluginExtensionServices.apiRouteRegistrar?.unregister(
            path: "/api/v1/teleprompter/load")
        context?.pluginExtensionServices.apiRouteRegistrar?.unregister(
            path: "/api/v1/teleprompter/start")
        context?.pluginExtensionServices.apiRouteRegistrar?.unregister(
            path: "/api/v1/teleprompter/pause")
        context?.pluginExtensionServices.apiRouteRegistrar?.unregister(
            path: "/api/v1/teleprompter/stop")
        context?.pluginExtensionServices.apiRouteRegistrar?.unregister(
            path: "/api/v1/teleprompter/state")
        context?.pluginExtensionServices.apiRouteRegistrar?.unregister(
            path: "/api/v1/teleprompter/ai-assist")
    }
    @ViewBuilder
    public func closedNotchContent() -> some View {
        TeleprompterClosedView(state: teleState)
    }

    @ViewBuilder
    public func expandedPanelContent() -> some View {
        TeleprompterExpandedView(state: teleState)
    }

    @ViewBuilder
    public func settingsContent() -> some View {
        TeleprompterSettingsView(state: teleState)
    }

    private static let readingAreaHeightMultiplier: CGFloat = 5.5

    public var displayRequest: DisplayRequest? {
        guard teleState.isScrolling || teleState.countdownState.isActive else { return nil }
        let physicalHeight = getRealNotchHeight()
        return DisplayRequest(
            priority: .critical,
            category: DisplayRequest.utility,
            preferredHeight: physicalHeight * Self.readingAreaHeightMultiplier
        )
    }
}
