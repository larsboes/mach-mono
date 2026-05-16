import SwiftUI

struct NotchHomeView: View {
    private let horizontalPadding: CGFloat = 32
    private let musicPanelWidth: CGFloat = 330
    private let openPanelWidth: CGFloat = 860

    @Environment(NotchViewModel.self) var vm
    @Environment(\.settings) var settings
    @Environment(\.pluginManager) var pluginManager
    @Environment(NotchViewCoordinator.self) var coordinator
    @Environment(\.contentProgress) var contentProgress
    let albumArtNamespace: Namespace.ID

    var body: some View {
        mainContent
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 4)
            .transition(.opacity)
            .environment(\.albumArtNamespace, albumArtNamespace)
    }

    private var shouldShowCamera: Bool {
        settings.showMirror && vm.isCameraExpanded
    }

    private var shouldShowCalendar: Bool {
        settings.showCalendar
    }

    private var additionalItemsCount: Int {
        [shouldShowCalendar, shouldShowCamera].filter { $0 }.count
    }

    private var itemWidth: CGFloat {
        let sidePanelArea = openPanelWidth - (horizontalPadding * 2) - musicPanelWidth
        guard additionalItemsCount > 0 else { return sidePanelArea }
        return min(max(sidePanelArea / CGFloat(additionalItemsCount) - 10, 80), 300)
    }

    private var mainContent: some View {
        HStack(alignment: .top, spacing: additionalItemsCount >= 2 ? 10 : 15) {
            if let pluginManager {
                pluginManager.expandedPanelView(for: PluginID.music)
                    .contentReveal(progress: contentProgress, staggerIndex: 0)
            }

            if shouldShowCalendar {
                if let pluginManager {
                    pluginManager.expandedPanelView(for: PluginID.calendar)
                        .frame(width: itemWidth)
                        .clipped()
                        .onHover { isHovering in
                            vm.isHoveringCalendar = isHovering
                        }
                        .environment(vm)
                        .contentReveal(progress: contentProgress, staggerIndex: 1)
                }
            }

            if shouldShowCamera {
                if let pluginManager {
                    pluginManager.expandedPanelView(for: PluginID.webcam)
                        .scaledToFit()
                        .contentReveal(progress: contentProgress, staggerIndex: 2, useBlur: false)
                }
            }
        }
        .padding(.horizontal, horizontalPadding)
        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
    }
}
