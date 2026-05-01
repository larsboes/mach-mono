//
//  CalendarSettingsView.swift
//  boringNotch
//
//  Created by Richard Kunkli on 07/08/2024.
//

import EventKit
import SwiftUI

struct CalendarSettings: View {
    @Environment(\.pluginManager) var pluginManager
    @Environment(\.bindableSettings) var settings

    var body: some View {
        @Bindable var settings = settings
        // Safe unwrap of calendar service
        let calendarService = pluginManager?.services.calendar
        
        Form {
            Toggle(isOn: $settings.showCalendar) {
                Text("Show calendar")
            }
            Toggle(isOn: $settings.hideCompletedReminders) {
                Text("Hide completed reminders")
            }
            Toggle(isOn: $settings.hideAllDayEvents) {
                Text("Hide all-day events")
            }
            Toggle(isOn: $settings.autoScrollToNextEvent) {
                Text("Auto-scroll to next event")
            }
            Toggle(isOn: $settings.showFullEventTitles) {
                Text("Always show full event titles")
            }
            Section(header: Text("Calendars")) {
                if let service = calendarService {
                    if service.calendarAuthorizationStatus == .notDetermined {
                        Button("Request Calendar Access") {
                            Task {
                                await service.checkCalendarAuthorization()
                            }
                        }
                    } else if service.calendarAuthorizationStatus != .fullAccess {
                        Text("Calendar access is denied. Please enable it in System Settings.")
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Open Calendar Settings") {
                            if let settingsURL = URL(
                                string:
                                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
                            ) {
                                NSWorkspace.shared.open(settingsURL)
                            }
                        }
                    } else {
                        List {
                            ForEach(service.eventCalendars, id: \.id) { calendar in
                                Toggle(
                                    isOn: Binding(
                                        get: { service.getCalendarSelected(calendar) },
                                        set: { isSelected in
                                            Task {
                                                await service.setCalendarSelected(
                                                    calendar, isSelected: isSelected)
                                            }
                                        }
                                    )
                                ) {
                                    Text(calendar.title)
                                }
                                .accentColor(lighterColor(from: calendar.color))
                                .disabled(!settings.showCalendar)
                            }
                        }
                    }
                }
            }
            Section(header: Text("Reminders")) {
                if let service = calendarService {
                    if service.reminderAuthorizationStatus == .notDetermined {
                        Button("Request Reminders Access") {
                            Task {
                                await service.checkReminderAuthorization()
                            }
                        }
                    } else if service.reminderAuthorizationStatus != .fullAccess {
                        Text("Reminder access is denied. Please enable it in System Settings.")
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Open Reminder Settings") {
                            if let settingsURL = URL(
                                string:
                                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders"
                            ) {
                                NSWorkspace.shared.open(settingsURL)
                            }
                        }
                    } else {
                        List {
                            ForEach(service.reminderLists, id: \.id) { calendar in
                                Toggle(
                                    isOn: Binding(
                                        get: { service.getCalendarSelected(calendar) },
                                        set: { isSelected in
                                            Task {
                                                await service.setCalendarSelected(
                                                    calendar, isSelected: isSelected)
                                            }
                                        }
                                    )
                                ) {
                                    Text(calendar.title)
                                }
                                .accentColor(lighterColor(from: calendar.color))
                                .disabled(!settings.showCalendar)
                            }
                        }
                    }
                }
            }
        }
        .accentColor(.effectiveAccent(from: settings))
        .navigationTitle("Calendar")
        .onAppear {
            Task {
                if let service = calendarService {
                    print("CalendarSettingsView: Checking authorization...")
                    await service.checkCalendarAuthorization()
                    await service.checkReminderAuthorization()
                    print("CalendarSettingsView: Status - Calendar: \(service.calendarAuthorizationStatus.rawValue), Reminders: \(service.reminderAuthorizationStatus.rawValue)")
                } else {
                    print("CalendarSettingsView: CalendarService is NIL")
                }
            }
        }
    }
}

func lighterColor(from nsColor: NSColor, amount: CGFloat = 0.14) -> Color {
    let srgb = nsColor.usingColorSpace(.sRGB) ?? nsColor
    var (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
    srgb.getRed(&r, green: &g, blue: &b, alpha: &a)

    func lighten(_ c: CGFloat) -> CGFloat {
        let increased = c + (1.0 - c) * amount
        return min(max(increased, 0), 1)
    }

    let nr = lighten(r)
    let ng = lighten(g)
    let nb = lighten(b)

    return Color(red: Double(nr), green: Double(ng), blue: Double(nb), opacity: Double(a))
}
