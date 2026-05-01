//
//  CalendarPlugin.swift
//  boringNotch
//
//  Built-in calendar plugin.
//  Wraps CalendarService to provide events and reminders.
//

import SwiftUI

@MainActor
@Observable
final class CalendarPlugin: NotchPlugin, ExportablePlugin {
    
    // MARK: - NotchPlugin
    
    let id = PluginID.calendar
    
    let metadata = PluginMetadata(
        name: "Calendar",
        description: "View upcoming events and reminders",
        icon: "calendar",
        version: "1.0.0",
        author: "boringNotch",
        category: .productivity
    )
    
    var isEnabled: Bool = true
    
    private(set) var state: PluginState = .inactive
    
    // MARK: - Dependencies
    
    var calendarService: (any CalendarServiceProtocol)?
    private var settings: PluginSettings?
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Lifecycle
    
    func activate(context: PluginContext) async throws {
        state = .activating
        
        self.calendarService = context.services.calendar
        
        // Sync enabled state with legacy setting for now
        // In the future, this should be bi-directional or migrated
        if self.settings != nil {
            // We can read 'showCalendar' from global defaults or plugin settings
            // For now, let's assume the plugin is enabled by default in the manager,
            // but the view logic in NotchHomeView controls visibility.
        }
        
        state = .active
    }
    
    func deactivate() async {
        calendarService = nil
        settings = nil
        state = .inactive
    }
    
    // MARK: - UI Slots
    
    @ViewBuilder
    func expandedPanelContent() -> some View {
        if isEnabled, state.isActive {
            // CalendarView uses Environment(\.pluginManager) to access the service
            CalendarView()
        }
    }
    
    @ViewBuilder
    func settingsContent() -> some View {
        CalendarSettings()
    }

    // MARK: - ExportablePlugin

    var supportedExportFormats: [ExportFormat] { [.json, .csv, .ical] }

    func exportData(format: ExportFormat) async throws -> Data {
        guard let events = calendarService?.events else {
            throw PluginError.exportFailed("No calendar data available")
        }

        switch format {
        case .json:
            return try exportJSON(events: events)
        case .csv:
            return exportCSV(events: events)
        case .ical:
            return exportICal(events: events)
        default:
            throw PluginError.exportFailed("Unsupported format: \(format.displayName)")
        }
    }

    private func exportJSON(events: [EventModel]) throws -> Data {
        let exportEvents = events.map { CalendarExportEvent(from: $0) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(exportEvents)
    }

    private func exportCSV(events: [EventModel]) -> Data {
        let formatter = ISO8601DateFormatter()
        var csv = "title,start,end,location,all_day,type\n"
        for event in events {
            let title = event.title.replacingOccurrences(of: ",", with: ";")
            let location = (event.location ?? "").replacingOccurrences(of: ",", with: ";")
            csv += "\(title),\(formatter.string(from: event.start)),\(formatter.string(from: event.end)),\(location),\(event.isAllDay),\(event.type)\n"
        }
        return Data(csv.utf8)
    }

    private func exportICal(events: [EventModel]) -> Data {
        let formatter = icalDateFormatter()
        var ical = "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//boringNotch//Calendar Export//EN\r\n"
        for event in events {
            ical += "BEGIN:VEVENT\r\n"
            ical += "UID:\(event.id)\r\n"
            ical += "DTSTART:\(formatter.string(from: event.start))\r\n"
            ical += "DTEND:\(formatter.string(from: event.end))\r\n"
            ical += "SUMMARY:\(escapeICal(event.title))\r\n"
            if let location = event.location {
                ical += "LOCATION:\(escapeICal(location))\r\n"
            }
            ical += "END:VEVENT\r\n"
        }
        ical += "END:VCALENDAR\r\n"
        return Data(ical.utf8)
    }

    private func icalDateFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }

    private func escapeICal(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}

// MARK: - Export DTO

private struct CalendarExportEvent: Codable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let location: String?
    let notes: String?
    let isAllDay: Bool
    let type: String
    let calendar: String

    init(from event: EventModel) {
        self.id = event.id
        self.title = event.title
        self.start = event.start
        self.end = event.end
        self.location = event.location
        self.notes = event.notes
        self.isAllDay = event.isAllDay
        self.type = "\(event.type)"
        self.calendar = event.calendar.title
    }
}
