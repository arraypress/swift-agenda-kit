//
//  AgendaEvent+OpenIn.swift
//  AgendaKit
//
//  Created by David Sherlock on 2026.
//
//  A link that opens one event in another calendar app. Delegates to
//  `CalendarLinks`.
//

import Foundation

extension AgendaEvent {

    /// A link that shows this event in `app`, or `nil` when one cannot be built.
    ///
    /// Only Calendar.app and BusyCal can be pointed at an event itself; the others open on
    /// the event's day, which is the closest they come:
    ///
    /// - ``CalendarApp/appleCalendar``: `ical://ekevent/<calendarItemId>?method=show&options=more`,
    ///   with the occurrence stamped in for repeating events. Needs ``calendarItemId``, so
    ///   `nil` for records built by hand or decoded from older JSON.
    /// - ``CalendarApp/busyCal``: `busycalevent://find/<calendar>/<title>/<start>` — BusyCal
    ///   searches by those three, having no link by identifier.
    /// - ``CalendarApp/googleCalendar``: the day view of ``startsAt``. Google's own event
    ///   link needs Google's event ID and the calendar's address, neither of which EventKit
    ///   exposes reliably.
    /// - ``CalendarApp/fantastical``: `x-fantastical://date/…` for ``startsAt``. Fantastical
    ///   documents no link for a single event.
    ///
    /// Days are worked out in ``Agenda/calendar``'s time zone.
    public func openURL(in app: CalendarApp) -> URL? {
        let zone = Agenda.calendar.timeZone
        let link: String?
        switch app {
        case .appleCalendar:
            link = calendarItemId.flatMap {
                CalendarLinks.appleCalendarEvent(calendarItemId: $0, start: startsAt, isAllDay: isAllDay,
                                                 isRecurring: isRecurring, timeZone: zone)
            }
        case .busyCal:
            link = CalendarLinks.busyCalEvent(calendarName: calendar, title: title, start: startsAt,
                                              isAllDay: isAllDay, timeZone: zone)
        case .googleCalendar:
            link = CalendarLinks.googleCalendar(date: startsAt, view: .day, timeZone: zone)
        case .fantastical:
            link = CalendarLinks.fantastical(date: startsAt, timeZone: zone)
        }
        return link.flatMap(URL.init(string:))
    }
}
