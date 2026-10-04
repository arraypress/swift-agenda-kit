//
//  CalendarApp.swift
//  AgendaKit
//
//  Created by David Sherlock on 2026.
//
//  The calendar apps a day, week or event can be handed to, and the
//  view to ask for. The links themselves are built in
//  `Support/CalendarLinks.swift`.
//

import Foundation

/// A calendar app that can be asked to show a date or an event.
///
/// Each app accepts a different amount: see ``Agenda/openURL(in:at:view:)`` and
/// ``AgendaEvent/openURL(in:)`` for what each one can and cannot be pointed at.
public enum CalendarApp: String, Codable, Sendable, Equatable, CaseIterable {

    /// Apple's Calendar.app. Opens an event by link; has no link for a date — use
    /// ``Agenda/calendarScript(showing:view:)`` for that.
    case appleCalendar = "apple-calendar"

    /// Google Calendar on the web, in the browser's signed-in account.
    case googleCalendar = "google-calendar"

    /// Flexibits' Fantastical.
    case fantastical

    /// BusyMac's BusyCal.
    case busyCal = "busycal"

    /// The app's name as its makers write it.
    public var displayName: String {
        switch self {
        case .appleCalendar:  return "Calendar"
        case .googleCalendar: return "Google Calendar"
        case .fantastical:    return "Fantastical"
        case .busyCal:        return "BusyCal"
        }
    }
}

/// How much time a calendar should show around a date.
///
/// Only some apps take this — Google Calendar and Calendar.app (by script) do; Fantastical
/// and BusyCal links reveal a date in whatever view the app is already in.
public enum CalendarView: String, Codable, Sendable, Equatable, CaseIterable {
    case day
    case week
    case month
}
