# Plugin Development Guide

This guide explains how to create a plugin for boringNotch, demonstrating how to build a first-class feature that integrates seamlessly with the notch.

## ⚡️ The Philosophy

**"Everything is a Plugin."**

Whether it's the core Music player or a simple Battery indicator, all features are built using the same API available to third-party developers. This ensures the API is robust and capable.

## 🛠 Step-by-Step Implementation

### 1. Create the Plugin Struct

Create a new file in `Plugins/BuiltIn/{MyFeature}Plugin/`. It must conform to `NotchPlugin`.

```swift
import SwiftUI

@MainActor
@Observable
final class MyFeaturePlugin: NotchPlugin {
    // 1. Identity
    let id = "com.boringnotch.myfeature"
    
    let metadata = PluginMetadata(
        name: "My Feature",
        description: "Does something amazing",
        icon: "star.fill", // SF Symbol
        category: .productivity
    )
    
    var isEnabled: Bool = true
    private(set) var state: PluginState = .inactive
    
    // 2. Dependencies
    private var settings: PluginSettings?
    
    // 3. Lifecycle
    func activate(context: PluginContext) async throws {
        state = .activating
        self.settings = context.settings
        state = .active
    }
    
    func deactivate() async {
        state = .inactive
    }
}
```

### 2. Define the UI

Plugins can implement two UI slots:

#### A. Closed Notch (Compact)
Shown inside the black notch bar. Space is limited.

```swift
func closedNotchContent() -> AnyView? {
    guard isEnabled, state.isActive else { return nil }
    
    return AnyView(
        HStack {
            Image(systemName: "star.fill")
            Text("Active")
        }
        .foregroundStyle(.white)
    )
}
```

#### B. Expanded Panel (Interactive)
Shown when the user hovers/clicks the notch. This provides a full canvas.

```swift
func expandedPanelContent() -> AnyView? {
    guard isEnabled, state.isActive else { return nil }
    
    return AnyView(
        VStack {
            Text("My Amazing Feature")
                .font(.headline)
            Button("Do Action") {
                // ...
            }
        }
        .padding()
    )
}
```

### 3. Requesting Display Time

The closed notch is a shared resource. Display must be **requested**.

Implement the `displayRequest` property:

```swift
var displayRequest: DisplayRequest? {
    guard isEnabled, state.isActive else { return nil }
    
    // logic: only show if something important is happening
    if myFeatureIsRunning {
        return DisplayRequest(
            priority: .normal, // .background, .normal, .high, .critical
            category: .utility
        )
    }
    
    return nil
}
```

### 4. Accessing System Services

System APIs (like `EventKit` or `CoreAudio`) should **not** be accessed directly. Use the `PluginContext`.

```swift
func activate(context: PluginContext) async throws {
    // Get the shared calendar service
    let calendar = context.services.calendar
    
    // Get the shared music service
    let music = context.services.music
}
```

### 5. Settings

Each plugin receives a sandboxed settings store.

```swift
func activate(context: PluginContext) async throws {
    self.settings = context.settings
    
    // Read
    let showIcon = settings?.get("showIcon", default: true)
}

func toggleIcon() {
    // Write
    settings?.set("showIcon", value: false)
}
```

## 🧪 Testing Your Plugin

Testing is mandatory. Since the plugin is a class, it can be unit tested easily.

```swift
@MainActor
final class MyPluginTests: XCTestCase {
    func testActivation() async throws {
        let plugin = MyFeaturePlugin()
        
        // Use mocks!
        let context = PluginContext.mock()
        
        try await plugin.activate(context: context)
        
        XCTAssertEqual(plugin.state, .active)
    }
}
```

## 📦 Registration

Finally, add the plugin to `AppObjectGraph.swift` (the DI composition root) to register it:

```swift
// AppObjectGraph.swift
lazy var pluginManager: PluginManager = {
    PluginManager(
        services: ServiceContainer(),
        // ...
        builtInPlugins: [
            MusicPlugin(),
            MyFeaturePlugin() // <--- Add this
        ]
    )
}()
```