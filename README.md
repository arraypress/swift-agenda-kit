# swift-agenda-kit

Apple Calendar and Reminders, as types rather than EventKit.

```swift
import AgendaKit

try await Agenda.requestAccess(to: .event)

let today = try Agenda.events(from: .now, to: .now.addingTimeInterval(86_400))
let gaps  = try Agenda.freeSlots(ofAtLeast: 1800, through: .now.addingTimeInterval(604_800))
let due   = try await Agenda.reminders(matching: ReminderFilter(overdueOnly: true))
```

`AgendaEvent`, `AgendaReminder`, `AgendaCalendar`, `AgendaAlarm`, `AgendaAttendee` — value
types, `Codable`, no `EKObject` in sight. Dates parse from plain language (`tomorrow 9am`,
`next friday`, `+2d`) as well as ISO 8601, and durations from `30m`, `4h`, `2w`, `6mo`.

The CLI on top of it is [`agenda`](../swift-agenda-cli).

## Repeating events

Writing to one takes an explicit `span` — `.thisEvent` or `.futureEvents` — so a whole series
is never rewritten because a caller forgot there was one. `.futureEvents` cannot be undone and
is never the default.

## What EventKit will not show you

**Not every calendar Calendar.app displays.** Measured on a real machine: Calendar.app listed
eight, `EKEventStore.calendars(for: .event)` returned six. The missing two were **Siri
Suggestions** and **Scheduled Reminders**, which macOS fills in from Mail — a flight from a
booking confirmation sits there until it is accepted.

`store.events(matching:)` over a window containing one of those, with **no calendar filter**,
returns zero events. It is not a filter this library could lift; EventKit cannot reach them.
Nothing here can fix it, and the failure is silent — an empty answer that is wrong looks
exactly like an empty answer that is right. `agenda doctor` reports the gap by asking
Calendar.app directly.

## Swift 5 language mode

Deliberate. `EKEventStore` is not `Sendable` and is legitimately one shared object for the
process — EventKit is built that way, and this library is single-threaded by design. Swift 6
mode turns that into an error rather than a question, and answering it properly means an actor
around the store and an async boundary on every call: a rewrite, not a setting. Callers above
this can and do use Swift 6.

## Requirements

macOS 15+, Swift 6.2 tools. EventKit and Foundation — nothing vendored, nothing fetched.

Calendar and Reminders are separate privacy permissions. `Agenda.access(to:)` reports each,
and `requestAccess(to:)` prompts. A binary with no bundle has no usage strings for TCC to
find, so anything shipping this needs the purpose keys embedded — see how `agenda` does it
with `-sectcreate __TEXT __info_plist`.

## Tested

121 tests, none of which need a calendar: date and duration parsing, recurrence rules, alarm
and location-alarm construction, time-zone handling, and the search and edit filters. The
store itself is not mocked — what is tested is everything that decides *what* to ask it.

## Licence

MIT.
