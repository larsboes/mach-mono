# boringNotch Feature Ideas

> **Design Principle:** Every feature is a plugin. No vendor lock-in. Data is exportable. APIs are local-first.
> 
> Last updated: 2025-12-30

---

## Core Philosophy

### Plugin-First Architecture
Every feature—including built-in ones like Music, Calendar, Shelf—should be implemented as plugins. This ensures:
- **Modularity:** Users enable only what they need
- **Extensibility:** Third-parties can build on the same APIs we use
- **Testability:** Isolated, well-defined boundaries
- **Maintainability:** No god objects, clear ownership

### Open Data Principles
1. **No Vendor Lock-in:** All user data exportable in standard formats (JSON, CSV, iCal, etc.)
2. **Local-First:** Data stays on device unless user explicitly opts for sync
3. **API Exposure:** Local HTTP/Unix socket API for other apps to integrate
4. **Standard Formats:** Use existing standards (CalDAV, WebDAV, ActivityPub) where possible

### Integration Philosophy
```
┌─────────────────────────────────────────────────────────────────┐
│                    boringNotch Core                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │ Plugin Host │  │ Data Layer  │  │ Local API   │             │
│  │             │  │ (Exportable)│  │ (REST/gRPC) │             │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘             │
└─────────┼────────────────┼────────────────┼─────────────────────┘
          │                │                │
    ┌─────▼─────┐    ┌─────▼─────┐    ┌─────▼─────┐
    │  Plugins  │    │  Export   │    │  External │
    │ (1st/3rd) │    │  Formats  │    │   Apps    │
    └───────────┘    └───────────┘    └───────────┘
```

---

## 1. Plugin System Architecture

### Plugin Protocol
```swift
protocol NotchPlugin: Identifiable {
    var id: String { get }
    var metadata: PluginMetadata { get }
    
    // Lifecycle
    func activate() async throws
    func deactivate() async
    
    // UI Slots
    func closedNotchView() -> AnyView?
    func openPanelView() -> AnyView?
    func settingsView() -> AnyView?
    func menuBarView() -> AnyView?  // Optional menu bar extra
    
    // Data & Export
    var dataStore: PluginDataStore? { get }
    func exportData(format: ExportFormat) async throws -> Data
    
    // Inter-plugin communication
    func handleMessage(_ message: PluginMessage) async -> PluginResponse?
}

struct PluginMetadata {
    let name: String
    let version: String
    let author: String
    let description: String
    let permissions: [PluginPermission]
    let dataFormats: [ExportFormat]  // What formats this plugin can export
}

enum ExportFormat: String, CaseIterable {
    case json, csv, xml, ical, markdown, html
}
```

### Plugin Slots System
```swift
enum PluginSlot {
    case closedNotch(position: ClosedNotchPosition)
    case openPanel(tab: String)
    case settingsPane
    case menuBarExtra
    case backgroundService  // No UI, just runs
    
    enum ClosedNotchPosition {
        case left, center, right
        case replacing(BuiltInElement)  // Replace battery, time, etc.
    }
}
```

### Plugin Manager
```swift
@MainActor
final class PluginManager: ObservableObject {
    private var loadedPlugins: [String: NotchPlugin] = [:]
    private let pluginDirectory: URL
    private let localAPI: LocalAPIServer
    
    // Discovery
    func discoverPlugins() async -> [PluginMetadata]
    func loadPlugin(id: String) async throws
    func unloadPlugin(id: String) async
    
    // Data Export (unified across all plugins)
    func exportAllData(format: ExportFormat) async throws -> URL
    func exportPluginData(pluginId: String, format: ExportFormat) async throws -> Data
    
    // Inter-plugin messaging
    func send(_ message: PluginMessage, to pluginId: String) async -> PluginResponse?
    func broadcast(_ message: PluginMessage) async
}
```

### Plugin Data Store
```swift
protocol PluginDataStore {
    associatedtype DataModel: Codable
    
    var data: DataModel { get set }
    
    // Persistence
    func save() async throws
    func load() async throws
    
    // Export (plugins implement these)
    func toJSON() -> Data
    func toCSV() -> String
    func toMarkdown() -> String
    
    // Sync (optional)
    var syncProvider: SyncProvider? { get }
}

protocol SyncProvider {
    func push() async throws
    func pull() async throws
    var lastSynced: Date? { get }
}
```

### Plugin Distribution
```
Formats:
├── .boringplugin        # Signed bundle (like .app)
├── Swift Package        # Source distribution via SPM
├── npm package          # For JS/WebView plugins
└── GitHub release       # Direct download

Discovery:
├── Built-in catalog     # Curated, reviewed plugins
├── GitHub topics        # #boringnotch-plugin
└── Local folder         # ~/Library/Application Support/boringNotch/Plugins/
```

---

## 2. Local API Server

### Purpose
Expose boringNotch functionality to external apps, scripts, and automations.

### Implementation
```swift
final class LocalAPIServer {
    private let port: UInt16 = 19384  // Or Unix socket
    
    // REST-ish endpoints
    // GET  /api/v1/plugins              - List plugins
    // GET  /api/v1/plugins/{id}/data    - Get plugin data
    // POST /api/v1/plugins/{id}/action  - Trigger action
    // GET  /api/v1/export/{format}      - Export all data
    // WS   /api/v1/events               - Real-time events stream
    
    // Authentication: Local-only by default, optional token for remote
}
```

### Event Stream (WebSocket)
```json
{
    "type": "notch.stateChanged",
    "data": {
        "state": "open",
        "trigger": "hover"
    }
}

{
    "type": "music.playbackChanged",
    "data": {
        "isPlaying": true,
        "track": "Song Name",
        "artist": "Artist"
    }
}

{
    "type": "plugin.dataChanged",
    "pluginId": "habit-tracker",
    "data": { ... }
}
```

### CLI Tool
```bash
# Ship a CLI for power users
$ boringnotch status
Notch: closed
Active plugins: music, calendar, shelf, habit-tracker

$ boringnotch export --format csv --output ~/Desktop/
Exported 4 plugins to ~/Desktop/boringnotch-export-2025-12-30/

$ boringnotch plugin install github:user/cool-plugin

$ boringnotch api start --port 19384
Local API server running at http://localhost:19384
```

---

## 3. Built-In Plugins (Refactored from Current Features)

### Music Plugin
```swift
struct MusicPlugin: NotchPlugin {
    let id = "com.boringnotch.music"
    
    // Data export
    func exportData(format: ExportFormat) async throws -> Data {
        // Export listening history, favorites, etc.
        switch format {
        case .json: return try JSONEncoder().encode(listeningHistory)
        case .csv: return listeningHistory.toCSV()
        }
    }
    
    // API endpoints this plugin adds
    // GET  /api/v1/music/now-playing
    // POST /api/v1/music/play
    // POST /api/v1/music/pause
    // GET  /api/v1/music/history
}
```

### Calendar Plugin
```swift
struct CalendarPlugin: NotchPlugin {
    let id = "com.boringnotch.calendar"
    
    // Export: iCal format for portability
    func exportData(format: ExportFormat) async throws -> Data {
        switch format {
        case .ical: return generateICalFeed()
        case .json: return try JSONEncoder().encode(events)
        }
    }
}
```

### Shelf Plugin
```swift
struct ShelfPlugin: NotchPlugin {
    let id = "com.boringnotch.shelf"
    
    // Export: File list, metadata
    func exportData(format: ExportFormat) async throws -> Data {
        // Export shelf contents metadata (not the files themselves)
    }
    
    // WebDAV-like API for other apps
    // GET  /api/v1/shelf/items
    // POST /api/v1/shelf/items    (add item)
    // DELETE /api/v1/shelf/items/{id}
}
```

---

## 4. New Feature Plugins

### 4.1 Habit Tracker Plugin

**Philosophy:** Your habit data belongs to you. Export anytime, sync anywhere.

```swift
struct HabitTrackerPlugin: NotchPlugin {
    let id = "com.boringnotch.habits"
    
    struct HabitData: Codable {
        var habits: [Habit]
        var completions: [HabitCompletion]
        var streaks: [String: Int]
    }
    
    struct Habit: Codable, Identifiable {
        let id: UUID
        var name: String
        var frequency: Frequency
        var createdAt: Date
        var archivedAt: Date?
    }
    
    struct HabitCompletion: Codable {
        let habitId: UUID
        let date: Date
        let notes: String?
    }
    
    // Export formats
    func exportData(format: ExportFormat) async throws -> Data {
        switch format {
        case .csv:
            return """
            habit_id,habit_name,date,completed,notes
            \(completions.map { "\($0.habitId),\(habit(for: $0).name),\($0.date),true,\($0.notes ?? "")" }.joined(separator: "\n"))
            """.data(using: .utf8)!
        case .json:
            return try JSONEncoder().encode(data)
        case .markdown:
            return generateMarkdownReport()
        }
    }
    
    // Sync options (user chooses, we don't lock in)
    var syncProviders: [SyncProvider] {
        [
            iCloudSyncProvider(),
            FileSyncProvider(path: userChosenPath),  // Obsidian vault, Dropbox, etc.
            CalDAVSyncProvider(),  // Sync as calendar events
        ]
    }
    
    // API
    // GET  /api/v1/habits
    // POST /api/v1/habits/{id}/complete
    // GET  /api/v1/habits/export?format=csv
}
```

**UI:**
- Closed notch: Today's habits as dots (filled = done)
- Open panel: Full habit list with check buttons
- Settings: Reminder times, export options, sync setup

---

### 4.2 Pomodoro/Focus Timer Plugin

```swift
struct PomodoroPlugin: NotchPlugin {
    let id = "com.boringnotch.pomodoro"
    
    struct SessionData: Codable {
        var sessions: [PomodoroSession]
        var settings: PomodoroSettings
    }
    
    struct PomodoroSession: Codable {
        let id: UUID
        let startTime: Date
        let duration: TimeInterval
        let type: SessionType  // work, shortBreak, longBreak
        let completed: Bool
        let tag: String?  // "coding", "writing", etc.
    }
    
    // Export for time tracking apps
    func exportData(format: ExportFormat) async throws -> Data {
        switch format {
        case .csv:
            // Compatible with Toggl, Clockify CSV imports
            return """
            Start,End,Duration,Type,Tag
            \(sessions.map { "\($0.startTime),\($0.endTime),\($0.duration),\($0.type),\($0.tag ?? "")" }.joined(separator: "\n"))
            """.data(using: .utf8)!
        case .json:
            return try JSONEncoder().encode(sessions)
        }
    }
    
    // Integration with Focus modes
    func activate() async throws {
        // Optionally enable Focus mode during work sessions
    }
    
    // API
    // POST /api/v1/pomodoro/start
    // POST /api/v1/pomodoro/stop
    // GET  /api/v1/pomodoro/status
    // GET  /api/v1/pomodoro/history
}
```

---

### 4.3 System Stats Plugin

```swift
struct SystemStatsPlugin: NotchPlugin {
    let id = "com.boringnotch.stats"
    
    // Real-time metrics
    struct SystemMetrics: Codable {
        let timestamp: Date
        let cpu: CPUMetrics
        let memory: MemoryMetrics
        let network: NetworkMetrics
        let disk: DiskMetrics
    }
    
    // Historical data (for graphs, export)
    var metricsHistory: [SystemMetrics] = []
    
    func exportData(format: ExportFormat) async throws -> Data {
        // Export for analysis in other tools
        switch format {
        case .csv:
            return metricsToCSV()  // Timestamp, CPU%, RAM%, Network In/Out
        case .json:
            return try JSONEncoder().encode(metricsHistory)
        }
    }
    
    // API (for other monitoring tools)
    // GET /api/v1/stats/current
    // GET /api/v1/stats/history?since=2025-01-01
    // WS  /api/v1/stats/stream  (real-time updates)
}
```

---

### 4.4 Quick Notes Plugin

```swift
struct QuickNotesPlugin: NotchPlugin {
    let id = "com.boringnotch.notes"
    
    struct Note: Codable, Identifiable {
        let id: UUID
        var content: String
        var createdAt: Date
        var modifiedAt: Date
        var tags: [String]
        var linkedNoteIds: [UUID]  // Bi-directional links
    }
    
    // Export: Standard formats for note apps
    func exportData(format: ExportFormat) async throws -> Data {
        switch format {
        case .markdown:
            // Each note as .md file in a zip
            return try await exportAsMarkdownZip()
        case .json:
            // Obsidian-compatible JSON
            return try JSONEncoder().encode(notes)
        case .html:
            return generateHTMLExport()
        }
    }
    
    // Sync: File-based for Obsidian/iA Writer/etc.
    var syncProviders: [SyncProvider] {
        [
            FileSyncProvider(path: "~/Documents/boringNotch Notes"),
            ObsidianVaultProvider(vaultPath: userVaultPath),
            AppleNotesProvider(),  // Via Shortcuts
        ]
    }
    
    // API
    // POST /api/v1/notes          (create note)
    // GET  /api/v1/notes          (list notes)
    // GET  /api/v1/notes/search?q=query
}
```

---

### 4.5 Clipboard History Plugin

```swift
struct ClipboardPlugin: NotchPlugin {
    let id = "com.boringnotch.clipboard"
    
    struct ClipboardEntry: Codable, Identifiable {
        let id: UUID
        let content: ClipboardContent
        let timestamp: Date
        let sourceApp: String?
        var pinned: Bool
        var tags: [String]
    }
    
    enum ClipboardContent: Codable {
        case text(String)
        case image(Data)  // PNG data
        case file(URL)
        case richText(Data)  // RTF data
    }
    
    // Export
    func exportData(format: ExportFormat) async throws -> Data {
        switch format {
        case .json:
            return try JSONEncoder().encode(history)
        case .csv:
            // Text entries only
            return textEntriesToCSV()
        }
    }
    
    // Privacy: Auto-clear options
    var settings: ClipboardSettings {
        autoClearAfter: .hours(24),
        excludeApps: ["1Password", "Keychain"],
        excludeTypes: [.password]  // Detect and exclude passwords
    }
    
    // API
    // GET  /api/v1/clipboard/history
    // POST /api/v1/clipboard/paste/{id}
    // DELETE /api/v1/clipboard/clear
}
```

---

### 4.6 Audio Visualizer Plugin

```swift
struct AudioVisualizerPlugin: NotchPlugin {
    let id = "com.boringnotch.visualizer"
    
    // Visualizer presets (extendable)
    var presets: [VisualizerPreset] = [
        .bars,
        .waveform,
        .particles,
        .blob,        // Endel-style organic shapes
        .custom(...)  // User-defined Metal shaders
    ]
    
    // Audio analysis (shared with other plugins)
    struct AudioAnalysis: Codable {
        let spectrum: [Float]     // FFT frequency bins
        let waveform: [Float]     // Time-domain samples
        let tempo: Double?        // BPM estimate
        let energy: Float         // Overall loudness 0-1
        let dominantFrequency: Float
    }
    
    // API for other plugins to use audio data
    // GET /api/v1/audio/analysis  (current analysis)
    // WS  /api/v1/audio/stream    (real-time analysis stream)
    
    // Custom shader support
    func loadCustomShader(at path: URL) throws -> VisualizerPreset
}

// Third-party visualizer plugins can implement:
protocol VisualizerPreset {
    var name: String { get }
    func render(analysis: AudioAnalysis, in context: GraphicsContext, size: CGSize)
}
```

---

### 4.7 Meeting Mode Plugin

```swift
struct MeetingModePlugin: NotchPlugin {
    let id = "com.boringnotch.meeting"
    
    struct MeetingSession: Codable {
        let id: UUID
        let startTime: Date
        let endTime: Date?
        let calendarEventId: String?
        let actions: [MeetingAction]  // What was auto-enabled
    }
    
    enum MeetingAction: Codable {
        case enabledDND
        case mutedNotifications
        case startedWebcam
        case startedRecording
    }
    
    // Export meeting history
    func exportData(format: ExportFormat) async throws -> Data {
        switch format {
        case .csv:
            return """
            Date,Duration,Actions
            \(sessions.map { "\($0.startTime),\($0.duration),\($0.actions.description)" }.joined(separator: "\n"))
            """.data(using: .utf8)!
        }
    }
    
    // Integration with calendar
    func upcomingMeetings() async -> [CalendarEvent] {
        // Query calendar plugin
        await pluginManager.send(.query("upcoming-events"), to: "com.boringnotch.calendar")
    }
}
```

---

## 5. AI Integration (Local-First)

### Philosophy
- **On-device first:** Use Core ML, CreateML for privacy
- **User controls cloud:** Explicit opt-in for cloud AI features
- **Transparent:** Show what data is sent where
- **Exportable models:** Users can export/replace AI models

### 5.1 Clipboard Intelligence (Local)

```swift
struct ClipboardAI {
    // Local Core ML model for classification
    let classifier: ClipboardClassifier  // CreateML text classifier
    
    func classify(_ text: String) -> ClipboardClassification {
        // Runs entirely on-device
        return classifier.predict(text)
    }
    
    enum ClipboardClassification {
        case url(URL)
        case email(String)
        case phone(String)
        case address(String)
        case code(language: String)
        case plainText
    }
    
    func suggestedActions(for classification: ClipboardClassification) -> [QuickAction] {
        switch classification {
        case .url(let url):
            return [.openInBrowser, .addToShelf, .copyAsMarkdownLink]
        case .code(let language):
            return [.formatCode, .runInTerminal, .addToSnippets]
        // ...
        }
    }
}
```

### 5.2 Context Engine (Local)

```swift
struct ContextEngine {
    // Gather context from various sources
    func currentContext() async -> UserContext {
        UserContext(
            activeApp: NSWorkspace.shared.frontmostApplication,
            clipboard: ClipboardManager.shared.latest,
            timeOfDay: Date(),
            calendarContext: await calendarPlugin.upcomingEvents(limit: 3),
            focusMode: await getFocusMode(),
            recentFiles: await getRecentFiles()
        )
    }
    
    // Local rules engine (no AI needed for basic suggestions)
    func suggestions(for context: UserContext) -> [ContextualSuggestion] {
        var suggestions: [ContextualSuggestion] = []
        
        // Rule: Meeting starting soon
        if let meeting = context.upcomingMeeting, meeting.startsIn < .minutes(10) {
            suggestions.append(.joinMeeting(meeting))
        }
        
        // Rule: Coding context
        if context.activeApp?.bundleIdentifier == "com.apple.dt.Xcode" {
            suggestions.append(.openTerminal)
            suggestions.append(.openDocumentation)
        }
        
        return suggestions
    }
}
```

### 5.3 Smart Summaries (Opt-in Cloud)

```swift
struct SmartSummaries {
    enum Provider: String, CaseIterable {
        case local      // Smaller on-device model
        case openai     // GPT API
        case anthropic  // Claude API
        case ollama     // Local Ollama server
        case custom     // User-provided endpoint
    }
    
    var provider: Provider = .local
    var apiEndpoint: URL?  // For custom providers
    
    // User controls what data is sent
    struct SummaryRequest {
        let text: String
        let maxTokens: Int
        let provider: Provider
        
        var privacyNote: String {
            switch provider {
            case .local, .ollama:
                return "Processed entirely on your device"
            case .openai, .anthropic:
                return "Text will be sent to \(provider.rawValue) servers"
            case .custom:
                return "Text will be sent to \(apiEndpoint?.host ?? "custom endpoint")"
            }
        }
    }
    
    func summarize(_ request: SummaryRequest) async throws -> String {
        // Show privacy note before sending
        // Process with chosen provider
    }
}
```

---

## 6. Integration Ecosystem

### 6.1 App Intents (Shortcuts)

```swift
struct OpenNotchIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Notch"
    static var description = IntentDescription("Opens the boringNotch panel")
    
    @Parameter(title: "Tab")
    var tab: NotchTab?
    
    func perform() async throws -> some IntentResult {
        await NotchController.shared.open(tab: tab)
        return .result()
    }
}

struct ExportDataIntent: AppIntent {
    static var title: LocalizedStringResource = "Export boringNotch Data"
    
    @Parameter(title: "Plugin")
    var plugin: String?
    
    @Parameter(title: "Format")
    var format: ExportFormat
    
    func perform() async throws -> some IntentResult & ReturnsValue<FileEntity> {
        let url = try await PluginManager.shared.exportData(
            plugin: plugin,
            format: format
        )
        return .result(value: FileEntity(url: url))
    }
}

// More intents:
// - AddToShelfIntent
// - CompleteHabitIntent
// - StartPomodoroIntent
// - ToggleMeetingModeIntent
```

### 6.2 URL Scheme

```
boringnotch://open                     # Open notch
boringnotch://open?tab=calendar        # Open specific tab
boringnotch://plugin/habits/complete?id=xxx
boringnotch://export?format=json&plugin=all
boringnotch://shelf/add?url=file:///path/to/file
```

### 6.3 AppleScript/JXA Support

```applescript
tell application "boringNotch"
    open notch
    set current tab to "calendar"
    
    -- Plugin commands
    tell plugin "habits"
        complete habit "Exercise"
    end tell
    
    -- Export
    export all data to "~/Desktop/" as CSV
end tell
```

### 6.4 Raycast Extension

```typescript
// raycast-extension/src/open-notch.ts
import { showHUD } from "@raycast/api";

export default async function Command() {
  const response = await fetch("http://localhost:19384/api/v1/notch/open");
  if (response.ok) {
    await showHUD("Notch opened");
  }
}
```

### 6.5 Browser Extension

```javascript
// For "Send to Shelf" from browser
browser.contextMenus.create({
  id: "send-to-shelf",
  title: "Send to boringNotch Shelf",
  contexts: ["link", "image", "selection"]
});

browser.contextMenus.onClicked.addListener(async (info) => {
  await fetch("http://localhost:19384/api/v1/shelf/add", {
    method: "POST",
    body: JSON.stringify({ url: info.linkUrl || info.srcUrl })
  });
});
```

---

## 7. Data Portability Standards

### Export Formats by Plugin

| Plugin | JSON | CSV | iCal | Markdown | HTML |
|--------|------|-----|------|----------|------|
| Habits | ✓ | ✓ | ✓* | ✓ | - |
| Pomodoro | ✓ | ✓ | - | - | - |
| Notes | ✓ | - | - | ✓ | ✓ |
| Clipboard | ✓ | ✓ | - | - | - |
| Calendar | ✓ | - | ✓ | - | - |
| Stats | ✓ | ✓ | - | - | - |

*Habits can export as calendar events for visualization

### Import Support

```swift
protocol ImportablePlugin {
    func supportedImportFormats() -> [ExportFormat]
    func importData(from url: URL, format: ExportFormat) async throws -> ImportResult
    func previewImport(from url: URL) async throws -> ImportPreview
}

struct ImportPreview {
    let itemCount: Int
    let conflicts: [ImportConflict]
    let sample: [Any]  // First few items
}
```

### Sync Provider Protocol

```swift
protocol SyncProvider: Identifiable {
    var id: String { get }
    var name: String { get }
    var icon: Image { get }
    
    func configure() async throws  // OAuth, path selection, etc.
    func push(_ data: Data) async throws
    func pull() async throws -> Data
    func resolveConflict(_ conflict: SyncConflict) async throws
    
    var status: SyncStatus { get }
}

// Built-in providers
struct iCloudSyncProvider: SyncProvider { }
struct FileSystemSyncProvider: SyncProvider { }  // Any folder
struct GitSyncProvider: SyncProvider { }  // Commit on change
struct WebDAVSyncProvider: SyncProvider { }
```

---

## 8. Security & Privacy

### Plugin Sandboxing

```swift
struct PluginPermission: OptionSet {
    static let network = PluginPermission(rawValue: 1 << 0)
    static let fileSystem = PluginPermission(rawValue: 1 << 1)
    static let clipboard = PluginPermission(rawValue: 1 << 2)
    static let notifications = PluginPermission(rawValue: 1 << 3)
    static let calendar = PluginPermission(rawValue: 1 << 4)
    static let microphone = PluginPermission(rawValue: 1 << 5)
    static let camera = PluginPermission(rawValue: 1 << 6)
    static let systemStats = PluginPermission(rawValue: 1 << 7)
}

// Plugins declare permissions, users approve
struct PluginManifest {
    let permissions: [PluginPermission]
    let permissionReasons: [PluginPermission: String]  // Why it needs each
}
```

### Local API Security

```swift
struct LocalAPIConfig {
    var bindAddress: String = "127.0.0.1"  // Local only by default
    var port: UInt16 = 19384
    var requireAuth: Bool = false  // Local doesn't need it
    var authToken: String?  // For remote access if enabled
    var allowedOrigins: [String] = ["*"]  // CORS
    var rateLimiting: RateLimitConfig?
}
```

### Data Encryption

```swift
struct DataEncryption {
    // At-rest encryption for sensitive plugin data
    var encryptionEnabled: Bool = true
    var keychain: KeychainAccess
    
    func encrypt(_ data: Data) throws -> Data
    func decrypt(_ data: Data) throws -> Data
}
```

---

## 9. Implementation Roadmap

### Phase 1: Plugin Foundation (2 weeks)
- [ ] Define `NotchPlugin` protocol
- [ ] Create `PluginManager`
- [ ] Refactor Music as first plugin
- [ ] Refactor Calendar as plugin
- [ ] Refactor Shelf as plugin
- [ ] Basic plugin settings UI

### Phase 2: Data Layer (1 week)
- [ ] Implement `PluginDataStore` protocol
- [ ] Add JSON export for all plugins
- [ ] Add CSV export where applicable
- [ ] Create unified export UI

### Phase 3: Local API (1 week)
- [ ] Implement REST API server
- [ ] Add WebSocket event stream
- [ ] Create CLI tool
- [ ] Document API endpoints

### Phase 4: New Plugins (2 weeks each)
- [ ] Habit Tracker plugin
- [ ] Pomodoro plugin
- [ ] Quick Notes plugin
- [ ] Clipboard History plugin

### Phase 5: Integrations (1 week)
- [ ] App Intents / Shortcuts
- [ ] URL scheme handler
- [ ] AppleScript dictionary

### Phase 6: AI Features (2 weeks)
- [ ] Clipboard classification (local ML)
- [ ] Context engine
- [ ] Optional cloud AI integration

### Phase 7: External Plugins (2 weeks)
- [ ] Plugin packaging format
- [ ] Plugin discovery UI
- [ ] Security review process
- [ ] Documentation for plugin developers

---

## 10. Developer Experience

### Plugin SDK

```bash
# Install plugin development tools
$ brew install boringnotch-sdk

# Create new plugin
$ boringnotch-sdk create my-plugin
Creating plugin at ./my-plugin...
├── Package.swift
├── Sources/
│   └── MyPlugin/
│       ├── MyPlugin.swift
│       └── Views/
├── Tests/
└── README.md

# Build and test
$ boringnotch-sdk build
$ boringnotch-sdk test

# Run in dev mode (hot reload)
$ boringnotch-sdk dev

# Package for distribution
$ boringnotch-sdk package
Created: my-plugin.boringplugin
```

### Plugin Documentation Template

```markdown
# My Plugin

## Installation
...

## Features
...

## Data Export
This plugin exports the following data formats:
- JSON: Full data export
- CSV: Tabular data for spreadsheets

## API Endpoints
- `GET /api/v1/my-plugin/data` - Get all data
- `POST /api/v1/my-plugin/action` - Perform action

## Privacy
This plugin:
- ✅ Stores all data locally
- ✅ Never sends data to external servers
- ✅ Supports full data export
```

---

## Summary

**Core Principles:**
1. **Everything is a plugin** - Even built-in features
2. **Your data, your choice** - Export anytime, any format
3. **Local-first** - Data stays on device unless you choose otherwise
4. **Open APIs** - Other apps can integrate freely
5. **No lock-in** - Standard formats, easy migration

This architecture ensures boringNotch remains a **platform** that respects user autonomy while enabling a rich ecosystem of extensions and integrations.
