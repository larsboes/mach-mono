import Foundation
import EventKit
import SwiftUI

@MainActor
@Observable
class CalendarService: CalendarServiceProtocol {
    // MARK: - Properties
    
    var events: [EventModel] = []
    var currentWeekStartDate: Date
    var allCalendars: [CalendarModel] = []
    var eventCalendars: [CalendarModel] = []
    var reminderLists: [CalendarModel] = []
    var selectedCalendarIDs: Set<String> = []
    var calendarAuthorizationStatus: EKAuthorizationStatus = .notDetermined
    var reminderAuthorizationStatus: EKAuthorizationStatus = .notDetermined
    
    private var selectedCalendars: [CalendarModel] = []
    private let dataProvider = CalendarDataProvider()
    
    // Wrapper to handle non-Sendable observers safely
    private final class ObserverContainer: @unchecked Sendable {
        var observer: NSObjectProtocol?
    }
    
    @ObservationIgnored nonisolated private let observerContainer = ObserverContainer()
    
    // MARK: - Settings Protocol
    
    private var settings: any NotchCalendarSettings
    
    // MARK: - Initialization
    
    init(settings: any NotchCalendarSettings) {
        self.settings = settings
        self.currentWeekStartDate = Calendar.current.startOfDay(for: Date())
        setupEventStoreChangedObserver()
        Task {
            await reloadCalendarAndReminderLists()
        }
    }
    
    deinit {
        if let observer = observerContainer.observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Setup
    
    private func setupEventStoreChangedObserver() {
        observerContainer.observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.reloadCalendarAndReminderLists()
            }
        }
    }
    
    // MARK: - Methods
    
    func reloadCalendarAndReminderLists() async {
        let all = await dataProvider.calendars()
        self.eventCalendars = all.filter { !$0.isReminder }
        self.reminderLists = all.filter { $0.isReminder }
        self.allCalendars = all
        updateSelectedCalendars()
    }
    
    func checkCalendarAuthorization() async {
        let status = EKEventStore.authorizationStatus(for: .event)
        self.calendarAuthorizationStatus = status
        
        switch status {
        case .notDetermined:
            do {
                let granted = try await dataProvider.requestAccess(to: .event)
                self.calendarAuthorizationStatus = granted ? .fullAccess : .denied
                if granted {
                    await reloadCalendarAndReminderLists()
                    await updateEvents()
                }
            } catch {
                print("Failed to request calendar access: \(error)")
                self.calendarAuthorizationStatus = .denied
            }
        case .fullAccess, .authorized:
            print("Calendar access already granted (fullAccess/authorized)")
            self.calendarAuthorizationStatus = .fullAccess
            await reloadCalendarAndReminderLists()
            await updateEvents()
        case .denied, .restricted, .writeOnly:
            print("Calendar access denied, restricted, or write-only")
            self.calendarAuthorizationStatus = .denied
        @unknown default:
            print("Unknown calendar authorization status: \(status.rawValue)")
            break
        }
    }
    
    func checkReminderAuthorization() async {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        self.reminderAuthorizationStatus = status
        
        switch status {
        case .notDetermined:
            do {
                let granted = try await dataProvider.requestAccess(to: .reminder)
                self.reminderAuthorizationStatus = granted ? .fullAccess : .denied
                if granted {
                    await reloadCalendarAndReminderLists()
                }
            } catch {
                print("Failed to request reminder access: \(error)")
                self.reminderAuthorizationStatus = .denied
            }
        case .fullAccess, .authorized:
            print("Reminder access already granted (fullAccess/authorized)")
            self.reminderAuthorizationStatus = .fullAccess
            await reloadCalendarAndReminderLists()
        case .denied, .restricted, .writeOnly:
            print("Reminder access denied, restricted, or write-only")
            self.reminderAuthorizationStatus = .denied
        @unknown default:
            print("Unknown reminder authorization status: \(status.rawValue)")
            break
        }
    }
    
    func updateSelectedCalendars() {
        // Populate selectedCalendarIDs based on settings
        switch settings.calendarSelectionState {
        case .all:
            selectedCalendarIDs = Set(allCalendars.map { $0.id })
        case .selected(let identifiers):
            selectedCalendarIDs = identifiers
        }
        
        // Update the local calendar objects that correspond to the selected ids
        selectedCalendars = allCalendars.filter { selectedCalendarIDs.contains($0.id) }
        
        Task {
            await updateEvents()
        }
    }
    
    func getCalendarSelected(_ calendar: CalendarModel) -> Bool {
        return selectedCalendarIDs.contains(calendar.id)
    }
    
    func setCalendarSelected(_ calendar: CalendarModel, isSelected: Bool) async {
        var selectionState = settings.calendarSelectionState
        
        switch selectionState {
        case .all:
            if !isSelected {
                let identifiers = Set(allCalendars.map { $0.id }).subtracting([calendar.id])
                selectionState = .selected(identifiers)
            }
            
        case .selected(var identifiers):
            if isSelected {
                identifiers.insert(calendar.id)
            } else {
                identifiers.remove(calendar.id)
            }
            
            selectionState = identifiers.isEmpty
                ? .all 
                : (identifiers.count == allCalendars.count ? .all : .selected(identifiers))
        }
        
        settings.calendarSelectionState = selectionState
        updateSelectedCalendars()
    }
    
    func updateCurrentDate(_ date: Date) async {
        currentWeekStartDate = Calendar.current.startOfDay(for: date)
        await updateEvents()
    }
    
    private func updateEvents() async {
        let calendarIDs = selectedCalendars.map { $0.id }
        let eventsResult = await dataProvider.events(
            from: currentWeekStartDate,
            to: Calendar.current.date(byAdding: .day, value: 1, to: currentWeekStartDate)!,
            calendars: calendarIDs
        )
        self.events = eventsResult
    }
    
    func setReminderCompleted(reminderID: String, completed: Bool) async {
        await dataProvider.setReminderCompleted(reminderID: reminderID, completed: completed)
        await updateEvents()
    }
}
