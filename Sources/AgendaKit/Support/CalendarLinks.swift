//
//  CalendarLinks.swift
//  AgendaKit
//
//  Created by David Sherlock on 2026.
//
//  Links that open a date or an event in another calendar app. Every
//  builder takes the time zone explicitly, because "which day is this
//  instant on" is the whole question and the answer moves with the zone.
//
//  What was checked, and how (2026-10):
//  - Google Calendar `/calendar/r/<view>/<y>/<m>/<d>`: undocumented by
//    Google, but it is the form Chromium's own ChromeOS tray opens and
//    pins in a browser test. Unpadded month and day.
//  - Fantastical `x-fantastical://date/yyyy-MM-dd`: Flexibits' current
//    integration help page. Earlier versions documented
//    `x-fantastical3://show/calendar/yyyy-MM-dd`; not tested against an
//    installed copy here.
//  - BusyCal `busycalevent://date/…` and `busycalevent://find/…`:
//    BusyMac's URL-handler help page, examples matched character for
//    character. Not tested against an installed copy here.
//  - Calendar.app `ical://ekevent/<id>?method=show&options=more`:
//    undocumented by Apple. It is the form MeetingBar and Calendr open,
//    including Calendr's occurrence-date rule for repeating events.
//    `ical` is the only app scheme Calendar.app registers (read from
//    its Info.plist), and there is no form of it for a date.
//  - Calendar.app by AppleScript: `switch view to` and `view calendar
//    at` are in Calendar's scripting dictionary; the script compiles
//    with `osacompile`. It was not run, to leave the calendar alone.
//

import Foundation

/// Link and script builders for showing a date or event in another calendar app.
enum CalendarLinks {

    // MARK: - Dates

    /// Google Calendar's web view of the day, week or month containing `date`:
    /// `https://calendar.google.com/calendar/r/week/2026/10/4`.
    ///
    /// Google picks the week or month around the given day itself, so the date is passed
    /// as is in every view.
    static func googleCalendar(date: Date, view: CalendarView, timeZone: TimeZone) -> String {
        let day = gregorianDay(of: date, in: timeZone)
        return "https://calendar.google.com/calendar/r/\(view.rawValue)/\(day.year)/\(day.month)/\(day.day)"
    }

    /// Fantastical revealing `date`: `x-fantastical://date/2026-10-04`. Fantastical has
    /// no view parameter; it stays in the view it was last left in.
    static func fantastical(date: Date, timeZone: TimeZone) -> String {
        "x-fantastical://date/\(isoDay(of: date, in: timeZone))"
    }

    /// BusyCal highlighting `date`: `busycalevent://date/2026-10-04`. No view parameter.
    static func busyCal(date: Date, timeZone: TimeZone) -> String {
        "busycalevent://date/\(isoDay(of: date, in: timeZone))"
    }

    /// An AppleScript that brings Calendar.app to `date` in the given view.
    ///
    /// Calendar.app has no URL for a date, so this is the only way to land it on one. The
    /// date is assembled from numbers rather than written as a date literal: AppleScript
    /// parses `date "…"` with the user's locale settings, so a literal that works in one
    /// region silently means another day elsewhere. Day is set to 1 before the month
    /// changes so that moving from the 31st to a shorter month cannot roll over.
    ///
    /// The script activates Calendar and waits a second before navigating. Since around
    /// macOS 14.5 Calendar restores its previous date just after activation, undoing a
    /// navigation sent too early — the workaround Itsycal ships.
    ///
    /// Running it needs the Automation permission for Calendar, prompted on first use.
    static func appleCalendarScript(date: Date, view: CalendarView, timeZone: TimeZone) -> String {
        let day = gregorianDay(of: date, in: timeZone)
        return """
        set targetDate to current date
        set day of targetDate to 1
        set year of targetDate to \(day.year)
        set month of targetDate to \(day.month)
        set day of targetDate to \(day.day)
        set time of targetDate to 0
        tell application "Calendar"
        \tactivate
        \tdelay 1
        \tswitch view to \(view.rawValue) view
        \tview calendar at targetDate
        end tell
        """
    }

    // MARK: - Events

    /// Calendar.app showing one event, with its detail popover open:
    /// `ical://ekevent/<calendarItemIdentifier>?method=show&options=more`.
    ///
    /// For a repeating event the occurrence goes between, as
    /// `ical://ekevent/20261004T080000Z/<id>?…` — otherwise Calendar opens the series'
    /// first occurrence. The stamp is the occurrence's start in UTC for a timed event; for
    /// an all-day one it is local midnight written with a `Z` regardless, since an all-day
    /// event has no instant to convert.
    static func appleCalendarEvent(calendarItemId: String, start: Date, isAllDay: Bool,
                                   isRecurring: Bool, timeZone: TimeZone) -> String? {
        guard let id = calendarItemId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        guard isRecurring else { return "ical://ekevent/\(id)?method=show&options=more" }
        let stamp = formatted(start, "yyyyMMdd'T'HHmmss'Z'",
                              in: isAllDay ? timeZone : TimeZone(identifier: "UTC")!)
        return "ical://ekevent/\(stamp)/\(id)?method=show&options=more"
    }

    /// BusyCal selecting one event by calendar, title and occurrence:
    /// `busycalevent://find/Work/Standup/2026-10-04T09%3A00%3A00+0100`.
    ///
    /// BusyCal has no link by identifier, so it searches. A timed occurrence is written
    /// `yyyy-MM-dd'T'HH:mm:ssZ` with the zone's offset; an all-day one as the bare date,
    /// which is BusyMac's documented form for date-only items. The stamp is encoded the
    /// way BusyMac's own examples are — colons escaped, the offset's `+` left bare — and
    /// calendar and title are percent-encoded down to the slash, which would otherwise
    /// split the path. Two events with the same title and start on the same calendar are
    /// indistinguishable to it.
    static func busyCalEvent(calendarName: String, title: String, start: Date, isAllDay: Bool,
                             timeZone: TimeZone) -> String {
        let when = isAllDay
            ? isoDay(of: start, in: timeZone)
            : formatted(start, "yyyy-MM-dd'T'HH:mm:ssZ", in: timeZone)
        let stamp = when.replacingOccurrences(of: ":", with: "%3A")
        return "busycalevent://find/\(pathEncoded(calendarName))/\(pathEncoded(title))/\(stamp)"
    }

    // MARK: - Helpers

    /// Year, month and day of `date` on the Gregorian calendar in `timeZone`.
    ///
    /// Gregorian on purpose, not the user's calendar: these links are read by other
    /// programs, and a Buddhist- or Japanese-calendar year would name a different day.
    static func gregorianDay(of date: Date, in timeZone: TimeZone) -> (year: Int, month: Int, day: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return (parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }

    /// `date` as `yyyy-MM-dd` in `timeZone`.
    static func isoDay(of date: Date, in timeZone: TimeZone) -> String {
        formatted(date, "yyyy-MM-dd", in: timeZone)
    }

    /// `date` in a fixed pattern — POSIX locale, Gregorian, so the output never depends on
    /// the machine's region settings.
    private static func formatted(_ date: Date, _ pattern: String, in timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    /// Percent-encodes everything outside RFC 3986's unreserved set, `/` included.
    private static func pathEncoded(_ text: String) -> String {
        let unreserved = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? text
    }
}
