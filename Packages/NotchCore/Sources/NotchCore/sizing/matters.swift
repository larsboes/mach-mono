import Foundation
import CoreGraphics

public struct CornerRadiusInsets {
    public var opened: (top: CGFloat, bottom: CGFloat)
    public var closed: (top: CGFloat, bottom: CGFloat)
    
    public init(opened: (top: CGFloat, bottom: CGFloat), closed: (top: CGFloat, bottom: CGFloat)) {
        self.opened = opened
        self.closed = closed
    }
}

public enum MusicPlayerImageSizes {
    public static let cornerRadiusInset: (opened: CGFloat, closed: CGFloat) = (opened: 13, closed: 4)
    public static let size = (opened: CGSize(width: 90, height: 90), closed: CGSize(width: 20, height: 20))
}

public enum NotchGeometry {
    public static let downloadSneakSize = CGSize(width: 65, height: 1)
    public static let batterySneakSize = CGSize(width: 160, height: 1)
    public static let shadowPadding: CGFloat = 20
    public static let openSize = CGSize(width: 860, height: 250)
    public static let windowSize = CGSize(width: openSize.width, height: openSize.height + shadowPadding)
    public static let cornerRadiusInsets = CornerRadiusInsets(
        opened: (top: 19, bottom: 24),
        closed: (top: 6, bottom: 14)
    )

    public static let fallbackPhysicalNotchWidth: CGFloat = 220
    public static let fallbackRealNotchHeight: CGFloat = 38
    public static let fallbackMenuBarHeight: CGFloat = 43
    public static let fallbackNonNotchLiveHeight: CGFloat = 32

    public struct ScreenMetrics: Equatable {
        public let frame: CGRect
        public let visibleFrame: CGRect
        public let safeAreaTop: CGFloat
        public let auxiliaryTopLeftWidth: CGFloat?
        public let auxiliaryTopRightWidth: CGFloat?

        public init(
            frame: CGRect,
            visibleFrame: CGRect,
            safeAreaTop: CGFloat,
            auxiliaryTopLeftWidth: CGFloat? = nil,
            auxiliaryTopRightWidth: CGFloat? = nil
        ) {
            self.frame = frame
            self.visibleFrame = visibleFrame
            self.safeAreaTop = safeAreaTop
            self.auxiliaryTopLeftWidth = auxiliaryTopLeftWidth
            self.auxiliaryTopRightWidth = auxiliaryTopRightWidth
        }
    }

    public static func realNotchHeight(from screens: [ScreenMetrics]) -> CGFloat {
        screens.first { $0.safeAreaTop > 0 }?.safeAreaTop ?? fallbackRealNotchHeight
    }

    public static func menuBarHeight(from screens: [ScreenMetrics]) -> CGFloat {
        guard let notchedScreen = screens.first(where: { $0.safeAreaTop > 0 }) else {
            return fallbackMenuBarHeight
        }
        return notchedScreen.frame.maxY - notchedScreen.visibleFrame.maxY - 1
    }

    public static func physicalNotchWidth(metrics: ScreenMetrics?) -> CGFloat {
        guard
            let metrics,
            let left = metrics.auxiliaryTopLeftWidth,
            let right = metrics.auxiliaryTopRightWidth,
            left > 100,
            right > 100
        else {
            return fallbackPhysicalNotchWidth
        }

        return min(openSize.width, max(fallbackPhysicalNotchWidth, metrics.frame.width - left - right + 12))
    }

    @MainActor public static func closedSize(
        settings: any DisplaySettings,
        metrics: ScreenMetrics?,
        hasLiveActivity: Bool
    ) -> CGSize {
        CGSize(
            width: physicalNotchWidth(metrics: metrics),
            height: closedHeight(settings: settings, metrics: metrics, hasLiveActivity: hasLiveActivity)
        )
    }

    @MainActor public static func closedHeight(
        settings: any DisplaySettings,
        metrics: ScreenMetrics?,
        hasLiveActivity: Bool
    ) -> CGFloat {
        guard let metrics else { return settings.nonNotchHeight }
        guard metrics.safeAreaTop > 0 else {
            return nonNotchedHeight(settings: settings, metrics: metrics, hasLiveActivity: hasLiveActivity)
        }
        return notchedHeight(settings: settings, metrics: metrics, hasLiveActivity: hasLiveActivity)
    }

    @MainActor private static func notchedHeight(
        settings: any DisplaySettings,
        metrics: ScreenMetrics,
        hasLiveActivity: Bool
    ) -> CGFloat {
        guard hasLiveActivity else { return metrics.safeAreaTop }

        switch settings.notchHeightMode {
        case .matchRealNotchSize:
            return metrics.safeAreaTop
        case .matchMenuBar:
            return metrics.frame.maxY - metrics.visibleFrame.maxY
        case .custom:
            return settings.notchHeight
        }
    }

    @MainActor private static func nonNotchedHeight(
        settings: any DisplaySettings,
        metrics: ScreenMetrics,
        hasLiveActivity: Bool
    ) -> CGFloat {
        switch settings.nonNotchHeightMode {
        case .matchMenuBar:
            return metrics.frame.maxY - metrics.visibleFrame.maxY
        case .matchRealNotchSize:
            return fallbackNonNotchLiveHeight
        case .custom:
            return hasLiveActivity ? fallbackNonNotchLiveHeight : settings.nonNotchHeight
        }
    }
}

public let downloadSneakSize = NotchGeometry.downloadSneakSize
public let batterySneakSize = NotchGeometry.batterySneakSize
public let shadowPadding = NotchGeometry.shadowPadding
public let openNotchSize = NotchGeometry.openSize
public let windowSize = NotchGeometry.windowSize
public let cornerRadiusInsets = NotchGeometry.cornerRadiusInsets

