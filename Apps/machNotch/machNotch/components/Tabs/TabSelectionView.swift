//
//  TabSelectionView.swift
//  machNotch
//
//  Created by Hugo Persson on 2024-08-25.
//

import SwiftUI

struct TabModel: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let view: NotchViews
}

private let coreTabs = [
    TabModel(label: "Home", icon: "house.fill", view: .home),
    TabModel(label: "Notifications", icon: "bell.fill", view: .notifications),
    TabModel(label: "Shelf", icon: "tray.fill", view: .shelf),
    TabModel(label: "Clipboard", icon: "doc.on.clipboard.fill", view: .clipboard),
    TabModel(label: "Notes", icon: "note.text", view: .notes),
]

private let weatherTab = TabModel(label: "Weather", icon: "cloud.sun.fill", view: .weather)
private let systemStatsTab = TabModel(label: "Stats", icon: "gauge.with.dots.needle.50percent", view: .systemStats)
private let briefTab = TabModel(label: "Brief", icon: "text.book.closed.fill", view: .brief)
private let soundscapeTab = TabModel(label: "Soundscape", icon: "waveform.path", view: .soundscape)

struct TabSelectionView: View {
    @Environment(NotchViewModel.self) var vm
    @Environment(\.settings) var settings
    @Environment(\.pluginManager) var pluginManager
    @Namespace var animation

    private var visibleTabs: [TabModel] {
        var tabs = coreTabs
        if settings.showWeather {
            tabs.insert(weatherTab, at: 2)  // After Notifications
        }
        if pluginManager?.hasPlugin(id: PluginID.brief) == true {
            tabs.append(briefTab)
        }
        if pluginManager?.hasPlugin(id: PluginID.soundscape) == true {
            tabs.append(soundscapeTab)
        }
        if pluginManager?.hasPlugin(id: PluginID.systemStats) == true {
            tabs.append(systemStatsTab)
        }
        return tabs
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(visibleTabs) { tab in
                TabButton(label: tab.label, icon: tab.icon, selected: vm.currentView == tab.view) {
                    vm.navigate(to: tab.view)
                }
                .padding(.leading, tab.view == .home ? 4 : 0)
                .padding(.trailing, tab.view == visibleTabs.last?.view ? 4 : 0)
                .frame(height: 26)
                .foregroundStyle(tab.view == vm.currentView ? .white : .gray)
                .background {
                    if tab.view == vm.currentView {
                        Capsule()
                            .fill(vm.currentView == tab.view ? Color(nsColor: .secondarySystemFill) : Color.clear)
                            .matchedGeometryEffect(id: "capsule", in: animation)
                    } else {
                        Capsule()
                            .fill(vm.currentView == tab.view ? Color(nsColor: .secondarySystemFill) : Color.clear)
                            .matchedGeometryEffect(id: "capsule", in: animation)
                            .hidden()
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .clipShape(Capsule())
    }
}

#Preview {
    NotchHeader().environment(NotchViewModel())
}
