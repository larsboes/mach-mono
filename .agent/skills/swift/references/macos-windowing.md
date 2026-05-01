# macOS Window Management in SwiftUI

Patterns for custom window behavior in macOS apps.

## Window Styles

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)  // No title bar
        .windowResizability(.contentSize)  // Size to fit content
        .defaultPosition(.center)  // Initial position
    }
}
```

## Menu Bar Extra

```swift
@main
struct MyApp: App {
    @State private var isShowing = false
    
    var body: some Scene {
        MenuBarExtra("App", systemImage: "menubar.dock.rectangle") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
        .defaultSize(width: 300, height: 200)
    }
}
```

## Panel Window

Floating panel that doesn't activate app:

```swift
WindowGroup {
    NotchView()
}
.windowStyle(.hiddenTitleBar)
.windowResizability(.contentSize)
.commands {
    CommandGroup(replacing: .appInfo) { }
}
```

## Window Controller (AppKit)

For advanced control, use NSWindowController:

```swift
final class NotchWindowController: NSWindowController {
    init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        super.init(window: panel)
    }
    
    func show(at point: NSPoint) {
        window?.setFrameOrigin(point)
        window?.makeKeyAndOrderFront(nil)
    }
}
```

## SwiftUI Integration

Bridge to AppKit for window control:

```swift
struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow?) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            callback(view.window)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// Usage
ContentView()
    .background(WindowAccessor { window in
        window?.isOpaque = false
        window?.backgroundColor = .clear
    })
```

## Screen Detection

```swift
import AppKit

func screenContainingNotch() -> NSScreen? {
    NSScreen.screens.first { screen in
        // Check if screen has notch (MacBook Pro)
        screen.safeAreaInsets.top > 0
    }
}

func notchRect(on screen: NSScreen) -> NSRect {
    let frame = screen.frame
    let safeFrame = screen.visibleFrame
    
    // Notch is in the gap between frame and safeFrame
    let notchHeight = frame.maxY - safeFrame.maxY - screen.safeAreaInsets.top
    let notchWidth: CGFloat = 200  // Approximate
    
    return NSRect(
        x: frame.midX - notchWidth / 2,
        y: safeFrame.maxY,
        width: notchWidth,
        height: screen.safeAreaInsets.top
    )
}
```
