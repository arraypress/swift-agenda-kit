//
//  Agenda+OpenIn.swift
//  AgendaKit
//
//  Created by David Sherlock on 2026.
//
//  Links that open a day, week or month in another calendar app.
//  Delegates to `CalendarLinks`; what each app accepts, and how
//  each form was checked, is recorded there.
//

import Foundation

extension Agenda {

    /// A link that opens `app` at `date`, or `nil` when the app has no such link.
    ///
    /// The day is worked out in ``calendar``'s time zone, so an instant late on Sunday in
    /// New York opens Sunday there and Monday in Tokyo.
    ///
    /// | App | Link | View honoured |
    /// |---|---|---|
    /// | ``CalendarApp/googleCalendar`` | `https://calendar.google.com/calendar/r/week/2026/10/4` | yes |
    /// | ``CalendarApp/fantastical`` | `x-fantastical://date/2026-10-04` | no |
    /// | ``CalendarApp/busyCal`` | `busycalevent://date/2026-10-04` | no |
    /// | ``CalendarApp/appleCalendar`` | none — returns `nil` | — |
    ///
    /// Calendar.app registers only `ical://` and offers no form of it for a date; reach a
    /// date there with ``calendarScript(showing:view:)``. (`calshow:` is iOS-only.)
    public static func openURL(in app: CalendarApp, at date: Date, view: CalendarView = .day) -> URL? {
        let zone = calendar.timeZone
        let link: String?
        switch app {
        case .googleCalendar: link = CalendarLinks.googleCalendar(date: date, view: view, timeZone: zone)
        case .fantastical:    link = CalendarLinks.fantastical(date: date, timeZone: zone)
        case .busyCal:        link = CalendarLinks.busyCal(date: date, timeZone: zone)
        case .appleCalendar:  link = nil
        }
        return link.flatMap(URL.init(string:))
    }

    /// AppleScript source that brings Calendar.app to `date` in the given view.
    ///
    /// Run it with `NSAppleScript` or `osascript`; the first run prompts for the
    /// Automation permission over Calendar. The date is built from numbers, not a date
    /// literal, so it means the same day whatever the user's region settings. It
    /// activates Calendar and waits a second first, because recent macOS restores
    /// Calendar's previous date just after activation and would undo a quicker jump.
    public static func calendarScript(showing date: Date, view: CalendarView = .day) -> String {
        CalendarLinks.appleCalendarScript(date: date, view: view, timeZone: calendar.timeZone)
    }
}
