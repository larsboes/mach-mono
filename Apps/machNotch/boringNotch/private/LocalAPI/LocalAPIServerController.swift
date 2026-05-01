import Foundation
import Combine

@MainActor
final class LocalAPIServerController {
    private let eventBus: PluginEventBus
    private let pluginManager: PluginManager
    private let viewModelProvider: () -> BoringViewModel

    private var server: LocalAPIServer?
    private var cancellables = Set<AnyCancellable>()

    init(eventBus: PluginEventBus, pluginManager: PluginManager, viewModelProvider: @escaping () -> BoringViewModel) {
        self.eventBus = eventBus
        self.pluginManager = pluginManager
        self.viewModelProvider = viewModelProvider
    }

    func start() {
        guard server == nil else { return }

        let router = APIRouter()
        registerDefaultRoutes(on: router)
        PluginAPIRoutes.register(on: router, pluginManager: pluginManager)
        PluginAPIRoutes.registerMusic(on: router, musicService: pluginManager.services.music)

        // Expose router to plugins
        pluginManager.services.apiRouteRegistrar = router

        let server = LocalAPIServer(router: router)
        do {
            try server.start()
            self.server = server
            subscribeToEvents()
        } catch {
            print("Failed to start Local API server: \(error)")
        }
    }

    private func registerDefaultRoutes(on router: APIRouteRegistrar) {
        router.register(method: .get, path: "/api/v1/notch/state") { [weak self] _ in
            guard let self else {
                return .json(status: 500, APIResponseEnvelope<APIErrorData>.failure("Server unavailable"))
            }
            return await MainActor.run {
                .json(APIResponseEnvelope.success(self.currentNotchState()))
            }
        }

        router.register(method: .post, path: "/api/v1/notch/open") { [weak self] _ in
            guard let self else {
                return .json(status: 500, APIResponseEnvelope<APIErrorData>.failure("Server unavailable"))
            }
            await MainActor.run {
                self.viewModelProvider().open()
                self.server?.broadcast(APIEventPayload(type: "notch.opened", data: ["source": "api"]))
            }
            return .json(APIResponseEnvelope<APIErrorData>.success())
        }

        router.register(method: .post, path: "/api/v1/notch/close") { [weak self] _ in
            guard let self else {
                return .json(status: 500, APIResponseEnvelope<APIErrorData>.failure("Server unavailable"))
            }
            await MainActor.run {
                self.viewModelProvider().close(force: true)
                self.server?.broadcast(APIEventPayload(type: "notch.closed", data: ["source": "api"]))
            }
            return .json(APIResponseEnvelope<APIErrorData>.success())
        }

        router.register(method: .post, path: "/api/v1/notch/toggle") { [weak self] _ in
            guard let self else {
                return .json(status: 500, APIResponseEnvelope<APIErrorData>.failure("Server unavailable"))
            }
            await MainActor.run {
                self.toggle()
            }
            return .json(APIResponseEnvelope<APIErrorData>.success())
        }

        router.register(method: .get, path: "/api/v1/events") { _ in
            .json(status: 400, APIResponseEnvelope<APIErrorData>.failure("Use WebSocket upgrade for /api/v1/events"))
        }
    }

    func stop() {
        cancellables.removeAll()
        server?.stop()
        server = nil
    }

    private func currentNotchState() -> APINotchState {
        let vm = viewModelProvider()
        let phase: String = {
            switch vm.phase {
            case .closed: return "closed"
            case .opening: return "opening"
            case .open: return "open"
            case .closing: return "closing"
            }
        }()

        return APINotchState(
            phase: phase,
            screen: vm.screenUUID ?? "main",
            size: APISize(width: vm.notchSize.width, height: vm.notchSize.height)
        )
    }

    private func toggle() {
        let vm = viewModelProvider()
        if vm.phase == .closed || vm.phase == .closing {
            vm.open()
            server?.broadcast(APIEventPayload(type: "notch.opened", data: ["source": "api"]))
            return
        }

        vm.close(force: true)
        server?.broadcast(APIEventPayload(type: "notch.closed", data: ["source": "api"]))
    }

    private func subscribeToEvents() {
        eventBus.events
            .sink { [weak self] event in
                guard let self = self else { return }
                self.server?.broadcast(self.mapEvent(event))
            }
            .store(in: &cancellables)
    }

    private func mapEvent(_ event: any PluginEvent) -> APIEventPayload {
        var data: [String: String] = [
            "sourcePluginId": event.sourcePluginId,
            "timestamp": ISO8601DateFormatter().string(from: event.timestamp)
        ]

        // Add event-specific data
        if let musicEvent = event as? MusicTrackChangedEvent {
            if let track = musicEvent.newTrack {
                data["title"] = track.title
                data["artist"] = track.artist
                data["album"] = track.album
            }
        } else if let musicPlaybackEvent = event as? MusicPlaybackChangedEvent {
            data["isPlaying"] = String(musicPlaybackEvent.isPlaying)
            if let track = musicPlaybackEvent.track {
                data["title"] = track.title
                data["artist"] = track.artist
            }
        } else if let notchEvent = event as? NotchStateChangedEvent {
            data["phase"] = mapNotchPhase(notchEvent.state)
        } else if let batteryEvent = event as? BatteryStateChangedEvent {
            data["level"] = String(batteryEvent.level)
            data["isCharging"] = String(batteryEvent.isCharging)
        }

        return APIEventPayload(
            type: mapEventType(event.type),
            data: data
        )
    }

    private func mapEventType(_ type: PluginEventType) -> String {
        switch type {
        case .notchOpened:
            return "notch.opened"
        case .notchClosed:
            return "notch.closed"
        case .notchExpanded:
            return "notch.expanded"
        case .musicTrackChanged, .musicPlaybackStarted, .musicPlaybackPaused:
            return "music.changed"
        case .pluginActivated, .pluginDeactivated:
            return "plugin.stateChanged"
        case .batteryLevelChanged, .batteryChargingStateChanged:
            return "system.batteryChanged"
        default:
            return "plugin.event"
        }
    }

    private func mapNotchPhase(_ state: NotchDisplayState) -> String {
        switch state {
        case .closed: return "closed"
        case .open: return "open"
        case .helloAnimation: return "hello"
        case .sneakPeek: return "sneakPeek"
        case .expanding: return "expanding"
        }
    }
}
