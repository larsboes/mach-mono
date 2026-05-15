//
//  NotchCalendar.swift
//  machNotch
//
//  Created by Harsh Vardhan  Goswami  on 08/09/24.
//

import AppKit
import SwiftUI

// MARK: - WeekDayPicker
/// Full 7-day week view (Mon-Sun) with compact styling
struct WeekDayPicker: View {
    @Binding var selectedDate: Date
    @Environment(\.settings) var settings
    @State private var haptics: Bool = false

    /// Get Mon-Sun of the week containing the selected date
    private var weekDays: [Date] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2  // Monday
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else { return [] }
        let monday = weekInterval.start
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: monday)
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(weekDays, id: \.self) { date in
                dayColumn(for: date)
            }
        }
        .sensoryFeedback(.selection, trigger: haptics)
    }

    private func dayColumn(for date: Date) -> some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)

        return Button(action: {
            selectedDate = date
            if settings.enableHaptics {
                haptics.toggle()
            }
        }) {
            VStack(spacing: 4) {
                Text(dayAbbreviation(for: date))
                    .font(.caption2)
                    .foregroundColor(Color(white: 0.65))
                ZStack {
                    if isToday {
                        Circle()
                            .fill(Color.effectiveAccent(from: settings))
                            .frame(width: 24, height: 24)
                    } else if isSelected {
                        Circle()
                            .fill(Color(white: 0.2))
                            .frame(width: 24, height: 24)
                    }
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isToday || isSelected ? .white : Color(white: 0.65))
                }
                .frame(width: 24, height: 24)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func dayAbbreviation(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"  // Single letter day
        return formatter.string(from: date)
    }
}

struct CalendarView: View {
    @Environment(PluginUIContext.self) var uiContext
    @Environment(\.settings) var settings
    @Environment(\.pluginManager) var pluginManager
    @State private var selectedDate = Date()

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(selectedDate.formatted(.dateTime.month(.abbreviated)))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    Text(selectedDate.formatted(.dateTime.year()))
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(Color(white: 0.65))
                }
                .frame(width: 34, alignment: .leading)
                WeekDayPicker(selectedDate: $selectedDate)
            }
            .padding(.horizontal, 8)

            if let calendarService = pluginManager?.services.calendar {
                let filteredEvents = EventListView.filteredEvents(
                    events: calendarService.events,
                    settings: settings
                )
                if filteredEvents.isEmpty {
                    EmptyEventsView(selectedDate: selectedDate)
                    Spacer(minLength: 0)
                } else {
                    EventListView(events: calendarService.events)
                        .padding(.leading, 46)
                }
            } else {
                EmptyEventsView(selectedDate: selectedDate)
                Spacer(minLength: 0)
            }
        }
        .listRowBackground(Color.clear)
        .frame(height: 120)
        .onChange(of: selectedDate) {
            Task {
                await pluginManager?.services.calendar.updateCurrentDate(selectedDate)
            }
        }
        .onChange(of: uiContext.notchState) { _, _ in
            Task {
                await pluginManager?.services.calendar.updateCurrentDate(Date.now)
                selectedDate = Date.now
            }
        }
        .onAppear {
            pluginManager?.services.calendar.refreshAuthorizationStatus()
            Task {
                await pluginManager?.services.calendar.updateCurrentDate(Date.now)
                selectedDate = Date.now
            }
        }
    }
}

struct EmptyEventsView: View {
    let selectedDate: Date
    @Environment(\.pluginManager) var pluginManager
    @Environment(\.settings) var settings

    var body: some View {
        if let service = pluginManager?.services.calendar {
            switch service.calendarAuthorizationStatus {
            case .notDetermined:
                calendarAccessView(
                    icon: "calendar.badge.exclamationmark",
                    iconColor: .orange,
                    label: "Calendar access needed",
                    buttonLabel: "Grant Access",
                    action: { Task { await service.checkCalendarAuthorization() } }
                )
            case .denied, .restricted:
                calendarAccessView(
                    icon: "calendar.badge.exclamationmark",
                    iconColor: .secondary,
                    label: "Access denied",
                    buttonLabel: "Open Settings",
                    action: {
                        if let url = URL(
                            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
                        {
                            NSWorkspace.shared.open(url)
                        }
                    }
                )
            default:
                noEventsContent
            }
        } else {
            noEventsContent
        }
    }

    private var noEventsContent: some View {
        VStack(spacing: 4) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.headline)
                .foregroundColor(Color(white: 0.45))
            Text(Calendar.current.isDateInToday(selectedDate) ? "No events today" : "No events")
                .font(.caption)
                .foregroundColor(Color(white: 0.55))
        }
    }

    @ViewBuilder
    private func calendarAccessView(
        icon: String,
        iconColor: Color,
        label: String,
        buttonLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 8) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(action: action) {
                Text(buttonLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.12))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}

#Preview {
    CalendarView()
        .frame(width: 215, height: 130)
        .background(.black)
        .environment(NotchViewModel())
}
