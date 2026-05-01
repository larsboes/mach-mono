import Foundation
import EventKit
import SwiftUI

@MainActor
protocol CalendarServiceProtocol: Observable {
    var events: [EventModel] { get }
    var currentWeekStartDate: Date { get }
    var calendarAuthorizationStatus: EKAuthorizationStatus { get }
    var reminderAuthorizationStatus: EKAuthorizationStatus { get }
    var selectedCalendarIDs: Set<String> { get }
    var allCalendars: [CalendarModel] { get }
    var eventCalendars: [CalendarModel] { get }
    var reminderLists: [CalendarModel] { get }
    
    func checkCalendarAuthorization() async
    func checkReminderAuthorization() async
    func updateCurrentDate(_ date: Date) async
    func setCalendarSelected(_ calendar: CalendarModel, isSelected: Bool) async
    func setReminderCompleted(reminderID: String, completed: Bool) async
    func reloadCalendarAndReminderLists() async
    
    // Additional helper from CalendarManager
    func getCalendarSelected(_ calendar: CalendarModel) -> Bool
}
