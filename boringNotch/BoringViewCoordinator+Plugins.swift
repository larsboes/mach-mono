//
//  BoringViewCoordinator+Plugins.swift
//  boringNotch
//
//  Plugin integration logic extracted from BoringViewCoordinator.
//

import Foundation

extension BoringViewCoordinator {

    /// Configure the coordinator with the plugin event bus and dependencies.
    /// This replaces direct coupling to managers.
    func configure(eventBus: PluginEventBus, mediaKeyInterceptor: MediaKeyInterceptor) {
        self.mediaKeyInterceptor = mediaKeyInterceptor
        musicSneakPeekCancellable = eventBus.subscribe(to: SneakPeekRequestedEvent.self) { [weak self] event in
            guard let self = self else { return }
            let request = event.request
            if request.style == .standard {
                self.toggleSneakPeek(status: true, type: request.type, value: request.value)
            } else {
                self.toggleExpandingView(status: true, type: request.type, value: request.value)
            }
        }
    }
}
