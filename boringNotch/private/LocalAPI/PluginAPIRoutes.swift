import Foundation

@MainActor
enum PluginAPIRoutes {
    static func register(on registrar: APIRouteRegistrar, pluginManager: PluginManager) {
        // GET /api/v1/plugins
        registrar.register(method: .get, path: "/api/v1/plugins") { _ in
            let plugins = await MainActor.run {
                pluginManager.allPlugins.map { plugin in
                    APIPluginInfo(
                        id: plugin.id,
                        name: plugin.metadata.name,
                        isEnabled: plugin.isEnabled,
                        isActive: plugin.state.isActive,
                        category: plugin.metadata.category.rawValue
                    )
                }
            }
            return .json(APIResponseEnvelope.success(plugins))
        }

        // GET /api/v1/plugins/{id}
        registrar.register(method: .get, path: "/api/v1/plugins/{id}") { request in
            guard let id = request.pathParam("id") else {
                return .json(status: 400, APIResponseEnvelope<APIErrorData>.failure("Missing plugin id"))
            }

            let info = await MainActor.run { () -> APIPluginInfo? in
                guard let plugin = pluginManager.plugin(id: id) else { return nil }
                return APIPluginInfo(
                    id: plugin.id,
                    name: plugin.metadata.name,
                    isEnabled: plugin.isEnabled,
                    isActive: plugin.state.isActive,
                    category: plugin.metadata.category.rawValue
                )
            }

            guard let info else {
                return .json(status: 404, APIResponseEnvelope<APIErrorData>.failure("Plugin not found"))
            }
            return .json(APIResponseEnvelope.success(info))
        }

        // POST /api/v1/plugins/{id}/toggle
        registrar.register(method: .post, path: "/api/v1/plugins/{id}/toggle") { request in
            guard let id = request.pathParam("id") else {
                return .json(status: 400, APIResponseEnvelope<APIErrorData>.failure("Missing plugin id"))
            }

            do {
                try await pluginManager.togglePlugin(id)
                return .json(APIResponseEnvelope<APIErrorData>.success())
            } catch {
                return .json(status: 500, APIResponseEnvelope<APIErrorData>.failure(error.localizedDescription))
            }
        }
    }

    static func registerMusic(on registrar: APIRouteRegistrar, musicService: any MusicServiceProtocol) {
        nonisolated(unsafe) let musicService = musicService
        // GET /api/v1/music/now-playing
        registrar.register(method: .get, path: "/api/v1/music/now-playing") { _ in
            let info = await MainActor.run { musicService.currentTrack }
            return .json(APIResponseEnvelope.success(info))
        }

        // POST /api/v1/music/play-pause
        registrar.register(method: .post, path: "/api/v1/music/play-pause") { _ in
            await musicService.togglePlayPause()
            return .json(APIResponseEnvelope<APIErrorData>.success())
        }

        // POST /api/v1/music/next
        registrar.register(method: .post, path: "/api/v1/music/next") { _ in
            await musicService.next()
            return .json(APIResponseEnvelope<APIErrorData>.success())
        }

        // POST /api/v1/music/previous
        registrar.register(method: .post, path: "/api/v1/music/previous") { _ in
            await musicService.previous()
            return .json(APIResponseEnvelope<APIErrorData>.success())
        }
    }
}

struct APIPluginInfo: Encodable {
    let id: String
    let name: String
    let isEnabled: Bool
    let isActive: Bool
    let category: String
}
