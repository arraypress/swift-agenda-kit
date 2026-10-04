//
//  OpenInTests.swift
//  AgendaKitTests
//
//  Created by David Sherlock on 2026.
//
//  The "open in" links and script, as exact strings for fixed instants
//  in pinned zones — the day a link names is the whole point, and it
//  moves with the zone.
//

import XCTest
@testable import AgendaKit

final class OpenDateInAppTests: TimeZonedTestCase {

    func testGoogleCalendarViews() {
        use("Europe/London")
        let day = date(2026, 10, 4, 15)
        XCTAssertEqual(Agenda.openURL(in: .googleCalendar, at: day)?.absoluteString,
                       "https://calendar.google.com/calendar/r/day/2026/10/4")
        XCTAssertEqual(Agenda.openURL(in: .googleCalendar, at: day, view: .week)?.absoluteString,
                       "https://calendar.google.com/calendar/r/week/2026/10/4")
        XCTAssertEqual(Agenda.openURL(in: .googleCalendar, at: day, view: .month)?.absoluteString,
                       "https://calendar.google.com/calendar/r/month/2026/10/4")
    }

    func testFantasticalAndBusyCalReveal() {
        use("Europe/London")
        let day = date(2026, 3, 7, 9)
        XCTAssertEqual(Agenda.openURL(in: .fantastical, at: day)?.absoluteString, "x-fantastical://date/2026-03-07")
        XCTAssertEqual(Agenda.openURL(in: .busyCal, at: day)?.absoluteString, "busycalevent://date/2026-03-07")
        // Neither takes a view, so asking for one changes nothing.
        XCTAssertEqual(Agenda.openURL(in: .busyCal, at: day, view: .month)?.absoluteString, "busycalevent://date/2026-03-07")
    }

    func testAppleCalendarHasNoDateLink() {
        use("Europe/London")
        XCTAssertNil(Agenda.openURL(in: .appleCalendar, at: date(2026, 10, 4)))
    }

    func testTheDayFollowsThePinnedZone() {
        // 23:30 on Sunday 4 October in New York is already Monday in Tokyo.
        use("America/New_York")
        let instant = date(2026, 10, 4, 23, 30)
        XCTAssertEqual(Agenda.openURL(in: .fantastical, at: instant)?.absoluteString, "x-fantastical://date/2026-10-04")

        use("Asia/Tokyo")
        XCTAssertEqual(Agenda.openURL(in: .fantastical, at: instant)?.absoluteString, "x-fantastical://date/2026-10-05")
        XCTAssertEqual(Agenda.openURL(in: .googleCalendar, at: instant)?.absoluteString,
                       "https://calendar.google.com/calendar/r/day/2026/10/5")
    }

    func testANonGregorianUserCalendarStillNamesTheGregorianDay() {
        use("Asia/Tokyo")
        let instant = date(2026, 10, 4, 12)
        var japanese = Calendar(identifier: .japanese)
        japanese.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        Agenda.calendar = japanese
        XCTAssertEqual(Agenda.openURL(in: .busyCal, at: instant)?.absoluteString, "busycalevent://date/2026-10-04")
    }

    func testCalendarScript() {
        use("Europe/London")
        let expected = """
        set targetDate to current date
        set day of targetDate to 1
        set year of targetDate to 2026
        set month of targetDate to 10
        set day of targetDate to 4
        set time of targetDate to 0
        tell application "Calendar"
        \tactivate
        \tdelay 1
        \tswitch view to week view
        \tview calendar at targetDate
        end tell
        """
        XCTAssertEqual(Agenda.calendarScript(showing: date(2026, 10, 4, 18), view: .week), expected)
        XCTAssertTrue(Agenda.calendarScript(showing: date(2026, 10, 4)).contains("switch view to day view"))
    }
}

final class OpenEventInAppTests: TimeZonedTestCase {

    private func event(start: Date, allDay: Bool = false, recurring: Bool = false,
                       calendarItemId: String? = "ABC-123", calendar: String = "Work",
                       title: String = "Stand-up") -> AgendaEvent {
        AgendaEvent(id: "evt", title: title, calendar: calendar, startsAt: start,
                    endsAt: start.addingTimeInterval(allDay ? 86_400 : 1_800), isAllDay: allDay,
                    calendarItemId: calendarItemId,
                    recurrence: recurring ? Recurrence(frequency: .daily) : nil)
    }

    func testAppleCalendarSingleEvent() {
        use("Europe/London")
        XCTAssertEqual(event(start: date(2026, 10, 4, 9)).openURL(in: .appleCalendar)?.absoluteString,
                       "ical://ekevent/ABC-123?method=show&options=more")
    }

    func testAppleCalendarRepeatingTimedEventStampsTheOccurrenceInUTC() {
        use("Europe/London")
        // 09:00 BST is 08:00 UTC.
        XCTAssertEqual(event(start: date(2026, 10, 4, 9), recurring: true).openURL(in: .appleCalendar)?.absoluteString,
                       "ical://ekevent/20261004T080000Z/ABC-123?method=show&options=more")
    }

    func testAppleCalendarRepeatingAllDayEventStampsLocalMidnight() {
        use("America/Los_Angeles")
        XCTAssertEqual(event(start: date(2026, 10, 4), allDay: true, recurring: true)
                        .openURL(in: .appleCalendar)?.absoluteString,
                       "ical://ekevent/20261004T000000Z/ABC-123?method=show&options=more")
    }

    func testAppleCalendarNeedsTheCalendarItemId() {
        use("Europe/London")
        XCTAssertNil(event(start: date(2026, 10, 4, 9), calendarItemId: nil).openURL(in: .appleCalendar))
    }

    func testBusyCalFindsTimedEventWithItsOffset() {
        use("Europe/London")
        let standup = event(start: date(2026, 10, 4, 9), calendar: "Work/Home", title: "Stand-up & sync")
        XCTAssertEqual(standup.openURL(in: .busyCal)?.absoluteString,
                       "busycalevent://find/Work%2FHome/Stand-up%20%26%20sync/2026-10-04T09%3A00%3A00+0100")
    }

    func testBusyCalFindsAllDayEventByDate() {
        use("America/New_York")
        let holiday = event(start: date(2026, 12, 25), allDay: true, calendar: "Holidays", title: "Christmas Day")
        XCTAssertEqual(holiday.openURL(in: .busyCal)?.absoluteString,
                       "busycalevent://find/Holidays/Christmas%20Day/2026-12-25")
    }

    func testGoogleAndFantasticalOpenTheEventsDay() {
        use("Asia/Tokyo")
        let late = event(start: date(2026, 10, 5, 0, 30))
        XCTAssertEqual(late.openURL(in: .googleCalendar)?.absoluteString,
                       "https://calendar.google.com/calendar/r/day/2026/10/5")
        XCTAssertEqual(late.openURL(in: .fantastical)?.absoluteString, "x-fantastical://date/2026-10-05")
    }

    func testDisplayNames() {
        XCTAssertEqual(CalendarApp.appleCalendar.displayName, "Calendar")
        XCTAssertEqual(CalendarApp.busyCal.displayName, "BusyCal")
        XCTAssertEqual(CalendarView.allCases.map(\.rawValue), ["day", "week", "month"])
    }
}
