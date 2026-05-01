//
//  PluginMusicPlayerView.swift
//  boringNotch
//
//  Refactored Music Player View for the Plugin Architecture.
//  Uses MusicServiceProtocol instead of MusicManager singleton.
//

import SwiftUI
import Defaults

struct PluginMusicPlayerView: View {
    let plugin: MusicPlugin
    let albumArtNamespace: Namespace.ID?
    @Environment(BoringViewModel.self) var vm
    @Environment(\.cornerRadiusInsets) var cornerRadiusInsets

    private var openEdgeSafeInset: CGFloat {
        max(10, cornerRadiusInsets.opened.top + 4)
    }

    var body: some View {
        if let service = plugin.musicService {
            HStack(spacing: 10) {
                PluginAlbumArtView(service: service, albumArtNamespace: albumArtNamespace)
                    .frame(width: 100, height: 100)
                    .padding(.leading, openEdgeSafeInset)

                PluginMusicControlsView(service: service, plugin: plugin)
            }
            .padding(.vertical, 4)
        } else {
            Text("Music Service Unavailable")
                .foregroundStyle(.secondary)
        }
    }
}

struct PluginAlbumArtView: View {
    let service: any MusicServiceProtocol
    let albumArtNamespace: Namespace.ID?

    @Environment(BoringViewModel.self) var vm
    @Environment(\.settings) var settings

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Suppress lighting glow during transition — the blur/rotate decoration
            // creates ghost artifacts while the shell is still morphing.
            // Only appears once the notch has settled into its final state.
            if settings.lightingEffect && !vm.phase.isTransitioning {
                albumArtBackground
            }
            albumArtButton
        }
    }

    private var albumArtBackground: some View {
        Image(nsImage: service.artwork ?? NSImage())
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: MusicPlayerImageSizes.cornerRadiusInset.opened)
            )
            .scaleEffect(x: 1.3, y: 1.4)
            .rotationEffect(.degrees(92))
            .blur(radius: 35)
            .opacity(service.playbackState.isPlaying ? 0.45 : 0)
    }

    private var albumArtButton: some View {
        ZStack {
            Button {
                Task { await service.openMusicApp() }
            } label: {
                albumArtImage
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(service.playbackState.isPlaying ? 1 : 0.9)
            .animation(.easeOut(duration: 0.2), value: service.playbackState.isPlaying)

            albumArtDarkOverlay
        }
    }

    private var albumArtDarkOverlay: some View {
        RoundedRectangle(cornerRadius: MusicPlayerImageSizes.cornerRadiusInset.opened)
            .foregroundColor(Color.black)
            .opacity(service.playbackState.isPlaying ? 0 : 0.6)
            .animation(.easeOut(duration: 0.25), value: service.playbackState.isPlaying)
    }

    private var albumArtImage: some View {
        GeometryReader { geo in
            Image(nsImage: service.artwork ?? NSImage())
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.width)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: MusicPlayerImageSizes.cornerRadiusInset.opened
                    )
                )
                .clipped()
                .ifLet(albumArtNamespace) { view, ns in
                    view.matchedGeometryEffect(id: "albumArt", in: ns)
                }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
