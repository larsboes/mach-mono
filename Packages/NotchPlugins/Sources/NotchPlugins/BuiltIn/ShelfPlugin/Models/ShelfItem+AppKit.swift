import AppKit
import NotchCore

public extension ShelfItem {
    var icon: NSImage {
        guard case .file = kind else {
            return Self.thumbnailSymbolImage(systemName: kind.iconSymbolName) ?? NSImage()
        }
        if let resolvedURL = fileURL {
            return NSWorkspace.shared.icon(forFile: resolvedURL.path)
        }
        return NSImage()
    }

    private static func thumbnailSymbolImage(
        systemName: String,
        size: CGSize = CGSize(width: 64, height: 80),
        symbolPointSize: CGFloat = 38,
        backgroundColor: NSColor = NSColor.white,
        symbolColor: NSColor = NSColor.labelColor
    ) -> NSImage? {
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let rect = CGRect(origin: .zero, size: size)
        let cornerRadius = min(size.width, size.height) * 0.06
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2), xRadius: cornerRadius, yRadius: cornerRadius)
        backgroundColor.setFill()
        path.fill()

        if let symbol = NSImage(systemSymbolName: systemName, accessibilityDescription: nil) {
            let symbolSize = CGSize(width: symbolPointSize, height: symbolPointSize)
            let symbolOrigin = CGPoint(
                x: (size.width - symbolSize.width) / 2,
                y: (size.height - symbolSize.height) / 2
            )
            let symbolRect = CGRect(origin: symbolOrigin, size: symbolSize)
            symbol.draw(in: symbolRect)
        }

        return image
    }
}
