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

## Video calls

`event.videoCall` names the service and the link — `VideoCall(service: .zoom, url: …)` — for
53 services: Zoom, Teams, Meet, Webex, FaceTime, Slack huddles and the long tail (8x8, Chime,
Dialpad, Doxy.me, Gather, Huddle01, Jitsi, Lark, LiveKit, Pop, Signal, Tuple, VooV, Whereby,
Zoho Cliq and the rest — `VideoCallService.allCases`). The shapes are data, one pattern per
service, each written against a join path rather than a bare host, so a link to a vendor's
pricing page is not a meeting. `Agenda.videoCall(notes:location:url:)` does the same for text
you hold.

Calendar servers rarely hand over a clean link, so before matching:

- **Redirects are unwrapped.** Outlook Safe Links (`*.safelinks.protection.outlook.com/?url=…`)
  and Google's `google.com/url?q=…` are peeled off and decoded, nested ones included — otherwise
  a Zoom passcode arrives as `pwd%3D…` and the client asks for one the invite supplied.
- **HTML is flattened.** `&amp;` and friends are decoded and tag brackets opened up, keeping
  the `href` — invitations show "Join meeting" and hide the link in the attribute.
- **One rule decides between links.** A `----( Video Call )----` block in the notes is an
  explicit answer and wins, even for a service the catalogue does not know. After that, a direct
  call link beats the wrappers that forward to one (Gong, Chorus, Reclaim), and the well-known
  services beat the niche. An unrecognised link is never called a call.

`meetingURL` is unchanged in shape: the detected link, else the event's own URL field. For Zoom
`/j/` meetings, `videoCall.appURL` gives the `zoommtg://` form that skips the browser.

Three shapes are inferred from the service's host because no real join link could be found to
pin the path: Preply, Sessions and Relayed (whose site was a parked page when checked). The
catalogue marks them.

## Opening a date or event elsewhere

```swift
Agenda.openURL(in: .googleCalendar, at: day, view: .week)  // calendar.google.com/calendar/r/week/2026/10/4
Agenda.openURL(in: .fantastical, at: day)                   // x-fantastical://date/2026-10-04
Agenda.openURL(in: .busyCal, at: day)                       // busycalevent://date/2026-10-04
event.openURL(in: .appleCalendar)                           // ical://ekevent/<id>?method=show&options=more
event.openURL(in: .busyCal)                                 // busycalevent://find/<calendar>/<title>/<start>
Agenda.calendarScript(showing: day, view: .week)            // AppleScript for Calendar.app
```

The day is worked out in `Agenda.calendar`'s zone, on the Gregorian calendar whatever the
user's own. What each app can take, honestly:

- **Calendar.app has no link for a date.** It registers only `ical://`, and `calshow:` is
  iOS. A date needs the AppleScript, which builds the date from numbers (a date literal is
  parsed by locale) and waits a second after activating, because recent macOS restores
  Calendar's previous date just after it comes forward. The script compiles against
  Calendar's dictionary; it needs the Automation permission to run. An *event* does open by
  link — `ical://ekevent/`, undocumented by Apple but what MeetingBar and Calendr ship — which
  takes EventKit's calendar-item identifier, now carried as `calendarItemId`.
- **Google Calendar** takes day, week and month views. The `/r/<view>/y/m/d` form is
  undocumented but is what Chromium's own ChromeOS tray opens. Its event links need Google's
  event ID, which EventKit does not expose, so an event opens on its day.
- **Fantastical** and **BusyCal** use their makers' documented handlers. Neither takes a view,
  and Fantastical has no event link, so an event opens on its day; BusyCal finds one by
  calendar, title and start. Fantastical's current docs give `x-fantastical://`; older
  versions documented `x-fantastical3://show/calendar/…`. Neither app was installed to try.

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

174 tests, none of which need a calendar: date and duration parsing, recurrence rules, alarm
and location-alarm construction, time-zone handling, the search and edit filters, one
invitation-shaped fixture per video-call service plus the wrappers, HTML and precedence around
them, and every "open in" link as an exact string for a fixed instant in a pinned zone. The
store itself is not mocked — what is tested is everything that decides *what* to ask it.

## Licence

MIT.
