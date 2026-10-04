//
//  VideoCallTests.swift
//  AgendaKitTests
//
//  Created by David Sherlock on 2026.
//
//  Video-call detection on fixed text: one realistic link per service,
//  the redirect and HTML wrappers calendars put around them, which link
//  wins when there are several, and links that are not calls at all.
//

import XCTest
@testable import AgendaKit

final class VideoCallCatalogueTests: XCTestCase {

    /// One invitation-shaped fixture per service: the text as it would sit in an event,
    /// and the link that should come out of it.
    private let fixtures: [(service: VideoCallService, text: String, url: String)] = [
        (.zoom, "Join Zoom Meeting\nhttps://us02web.zoom.us/j/81234567890?pwd=aBcDeF123\n\nMeeting ID: 812 3456 7890",
         "https://us02web.zoom.us/j/81234567890?pwd=aBcDeF123"),
        (.microsoftTeams, "Microsoft Teams meeting\nJoin on your computer: https://teams.microsoft.com/l/meetup-join/19%3ameeting_NjA5ZTk%40thread.v2/0?context=%7b%22Tid%22%3a%22abc%22%7d\nMeeting ID: 123",
         "https://teams.microsoft.com/l/meetup-join/19%3ameeting_NjA5ZTk%40thread.v2/0?context=%7b%22Tid%22%3a%22abc%22%7d"),
        (.googleMeet, "Video call link: https://meet.google.com/abc-defg-hij\nOr dial: +44 20 3873 7654",
         "https://meet.google.com/abc-defg-hij"),
        (.webex, "Join meeting https://acme.webex.com/acme/j.php?MTID=m0123456789abcdef0123456789abcdef\nMeeting number: 2630 123 4567",
         "https://acme.webex.com/acme/j.php?MTID=m0123456789abcdef0123456789abcdef"),
        (.goToMeeting, "Please join my meeting from your computer, tablet or smartphone.\nhttps://meet.goto.com/123456789",
         "https://meet.goto.com/123456789"),
        (.goToWebinar, "Register here: https://attendee.gotowebinar.com/register/1234567890123456789",
         "https://attendee.gotowebinar.com/register/1234567890123456789"),
        (.ringCentral, "Join: https://v.ringcentral.com/join/123456789",
         "https://v.ringcentral.com/join/123456789"),
        (.faceTime, "FaceTime: https://facetime.apple.com/join#v=1&p=AbCdEf123&k=XyZ987",
         "https://facetime.apple.com/join#v=1&p=AbCdEf123&k=XyZ987"),
        (.slack, "Huddle in #design: https://app.slack.com/huddle/T01ABCDEF/C02GHIJKL",
         "https://app.slack.com/huddle/T01ABCDEF/C02GHIJKL"),
        (.skype, "Join Skype call: https://join.skype.com/AbCdEfGh1234",
         "https://join.skype.com/AbCdEfGh1234"),
        (.blueJeans, "To join: https://bluejeans.com/123456789/0123",
         "https://bluejeans.com/123456789/0123"),
        (.amazonChime, "Click to join: https://chime.aws/1234567890",
         "https://chime.aws/1234567890"),
        (.eightByEight, "Join: https://8x8.vc/acme/weekly-sync",
         "https://8x8.vc/acme/weekly-sync"),
        (.jitsiMeet, "Room: https://meet.jit.si/AcmeWeeklySync",
         "https://meet.jit.si/AcmeWeeklySync"),
        (.whereby, "https://whereby.com/acme-standup",
         "https://whereby.com/acme-standup"),
        (.signal, "Signal call: https://signal.link/call/#key=bcdf-ghkm-npqr-stxz-bcdf-ghkm-npqr-stxz",
         "https://signal.link/call/#key=bcdf-ghkm-npqr-stxz-bcdf-ghkm-npqr-stxz"),
        (.dialpad, "Dialpad Meetings: https://meetings.dialpad.com/weekly-project-review",
         "https://meetings.dialpad.com/weekly-project-review"),
        (.vonage, "https://meetings.vonage.com/123456789",
         "https://meetings.vonage.com/123456789"),
        (.vooV, "VooV Meeting: https://voovmeeting.com/dm/AbCdEfGh1",
         "https://voovmeeting.com/dm/AbCdEfGh1"),
        (.lark, "Join Lark video meeting: https://vc.larksuite.com/j/123456789",
         "https://vc.larksuite.com/j/123456789"),
        (.zhumu, "https://welink.zhumu.com/j/123456789?pwd=abc123",
         "https://welink.zhumu.com/j/123456789?pwd=abc123"),
        (.zohoCliq, "Join: https://cliq.zoho.eu/meetings/acme/1234567890",
         "https://cliq.zoho.eu/meetings/acme/1234567890"),
        (.workplaceChat, "Room: https://fb.workplace.com/groupcall/ROOM:1234567890123456/",
         "https://fb.workplace.com/groupcall/ROOM:1234567890123456/"),
        (.teamViewer, "TeamViewer meeting: https://go.teamviewer.com/m12345678",
         "https://go.teamviewer.com/m12345678"),
        (.calCom, "Where: https://app.cal.com/video/aBcDeFgH1234",
         "https://app.cal.com/video/aBcDeFgH1234"),
        (.pumble, "https://meet.pumble.com/abc-defg-hij",
         "https://meet.pumble.com/abc-defg-hij"),
        (.around, "https://meet.around.co/r/acme-standup",
         "https://meet.around.co/r/acme-standup"),
        (.jam, "Jam room: https://jam.systems/abcdefgh",
         "https://jam.systems/abcdefgh"),
        (.coScreen, "https://join.coscreen.co/AbCdEf/xyz123",
         "https://join.coscreen.co/AbCdEf/xyz123"),
        (.tuple, "Pair on this: https://tuple.app/c/abc123def",
         "https://tuple.app/c/abc123def"),
        (.pop, "Pop: https://pop.com/j/123-456-789",
         "https://pop.com/j/123-456-789"),
        (.gather, "Office: https://app.gather.town/app/AbCdEf123/acme-office",
         "https://app.gather.town/app/AbCdEf123/acme-office"),
        (.oVice, "https://acme.ovice.in/lobby",
         "https://acme.ovice.in/lobby"),
        (.teemyco, "https://app.teemyco.com/room/AbCdEf123",
         "https://app.teemyco.com/room/AbCdEf123"),
        (.huddle01, "Join on Huddle01: https://app.huddle01.com/abc-defg-hij",
         "https://app.huddle01.com/abc-defg-hij"),
        (.liveKitMeet, "https://meet.livekit.io/rooms/acme-sync",
         "https://meet.livekit.io/rooms/acme-sync"),
        (.meetecho, "Remote participation: https://meetings.conf.meetecho.com/ietf120/?session=32456",
         "https://meetings.conf.meetecho.com/ietf120/?session=32456"),
        (.vowel, "https://acme.vowel.com/#/g/abc123",
         "https://acme.vowel.com/#/g/abc123"),
        (.doxyMe, "Your telehealth visit: https://doxy.me/drsmith",
         "https://doxy.me/drsmith"),
        (.demodesk, "Demo: https://demodesk.com/ZLWEOIKS",
         "https://demodesk.com/ZLWEOIKS"),
        (.demio, "Your link: https://event.demio.com/ref/AbCdEf123",
         "https://event.demio.com/ref/AbCdEf123"),
        (.livestorm, "https://app.livestorm.co/p/12345678-1234-1234-1234-123456789012/live?s=abc",
         "https://app.livestorm.co/p/12345678-1234-1234-1234-123456789012/live?s=abc"),
        (.luma, "Join the event: https://lu.ma/join/g-AbCdEf123",
         "https://lu.ma/join/g-AbCdEf123"),
        (.streamYard, "Backstage: https://streamyard.com/ab12cd34ef",
         "https://streamyard.com/ab12cd34ef"),
        (.vimeo, "Watch live: https://vimeo.com/event/1234567",
         "https://vimeo.com/event/1234567"),
        (.venue, "https://app.venue.live/app/acme/event/123",
         "https://app.venue.live/app/acme/event/123"),
        (.userZoom, "Study: https://go.userzoom.com/participate/abc123-def456",
         "https://go.userzoom.com/participate/abc123-def456"),
        (.preply, "Lesson: https://preply.com/en/classroom/AbCdEf123",
         "https://preply.com/en/classroom/AbCdEf123"),
        (.sessions, "https://app.sessions.us/session/AbCdEf123",
         "https://app.sessions.us/session/AbCdEf123"),
        (.relayed, "https://relayed.ai/r/abc123",
         "https://relayed.ai/r/abc123"),
        (.reclaim, "Booked via Reclaim: https://reclaim.ai/z/AbCdEf/12345",
         "https://reclaim.ai/z/AbCdEf/12345"),
        (.gong, "Join via Gong: https://join.gong.io/acme/jane.doe?tkn=abc123",
         "https://join.gong.io/acme/jane.doe?tkn=abc123"),
        (.chorus, "https://go.chorus.ai/AbCdEf123",
         "https://go.chorus.ai/AbCdEf123")
    ]

    func testEveryServiceHasAFixture() {
        let covered = Set(fixtures.map(\.service))
        let missing = VideoCallService.allCases.filter { $0 != .other && !covered.contains($0) }
        XCTAssertEqual(missing, [], "services without a fixture")
    }

    func testEveryServiceIsInTheCatalogueOnce() {
        let services = VideoCallCatalogue.entries.map(\.service)
        XCTAssertEqual(services.count, Set(services).count)
        XCTAssertEqual(Set(services), Set(VideoCallService.allCases.filter { $0 != .other }))
        XCTAssertEqual(VideoCallCatalogue.compiled.count, VideoCallCatalogue.entries.count, "a pattern failed to compile")
    }

    func testEachFixtureInNotes() {
        for fixture in fixtures {
            let call = Agenda.videoCall(notes: fixture.text, location: nil, url: nil)
            XCTAssertEqual(call?.service, fixture.service, "service for \(fixture.url)")
            XCTAssertEqual(call?.url, fixture.url, "url for \(fixture.service)")
        }
    }

    func testEachFixtureInLocation() {
        for fixture in fixtures {
            let call = Agenda.videoCall(notes: nil, location: fixture.text, url: nil)
            XCTAssertEqual(call, VideoCall(service: fixture.service, url: fixture.url), "\(fixture.service)")
        }
    }

    func testEachFixtureIsRecognisedOnItsOwn() {
        for fixture in fixtures {
            XCTAssertEqual(Agenda.videoCallService(of: fixture.url), fixture.service, fixture.url)
        }
    }

    func testDisplayNames() {
        XCTAssertEqual(VideoCallService.googleMeet.displayName, "Google Meet")
        XCTAssertEqual(VideoCallService.oVice.displayName, "oVice")
        XCTAssertEqual(VideoCallService.eightByEight.rawValue, "8x8")
        for service in VideoCallService.allCases {
            XCTAssertFalse(service.displayName.isEmpty)
        }
    }
}

final class VideoCallShapeTests: XCTestCase {

    private func service(_ text: String) -> VideoCallService? {
        Agenda.videoCall(notes: text, location: nil, url: nil)?.service
    }

    func testTeamsShortAndConsumerForms() {
        XCTAssertEqual(service("https://teams.microsoft.com/meet/2345678901234?p=AbCdEfGh"), .microsoftTeams)
        XCTAssertEqual(service("https://teams.live.com/meet/9876543210987?p=XyZ"), .microsoftTeams)
        XCTAssertEqual(service("https://gov.teams.microsoft.us/l/meetup-join/19%3ameeting_x"), .microsoftTeams)
    }

    func testZoomVariants() {
        XCTAssertEqual(service("https://zoom.us/j/123456789"), .zoom)
        XCTAssertEqual(service("https://acme.zoom.us/my/jane.doe"), .zoom)
        XCTAssertEqual(service("https://acme.zoom.us/w/123456789?tk=abc"), .zoom)
        XCTAssertEqual(service("https://acme.zoomgov.com/j/1612345678"), .zoom)
        XCTAssertEqual(service("https://us06web.zoom.us/meeting/register/tZAbCdEf123"), .zoom)
    }

    func testWebexPersonalRoom() {
        XCTAssertEqual(service("https://acme.my.webex.com/meet/jane.doe"), .webex)
    }

    func testGoToLegacyHost() {
        XCTAssertEqual(service("https://global.gotomeeting.com/join/123456789"), .goToMeeting)
    }

    func testHuddle01NewHost() {
        XCTAssertEqual(service("https://huddle01.app/room/abc-defg-hij"), .huddle01)
    }

    func testLarkChinaHost() {
        XCTAssertEqual(service("https://vc.feishu.cn/j/123456789"), .lark)
    }

    func testDemodeskLobby() {
        XCTAssertEqual(service("https://demodesk.com/meet/jane-doe"), .demodesk)
    }

    func testTrailingPunctuationIsNotPartOfTheLink() {
        let call = Agenda.videoCall(notes: "(join at https://meet.google.com/abc-defg-hij).", location: nil, url: nil)
        XCTAssertEqual(call?.url, "https://meet.google.com/abc-defg-hij")

        let sentence = Agenda.videoCall(notes: "Join here: https://acme.zoom.us/j/123456789, thanks!", location: nil, url: nil)
        XCTAssertEqual(sentence?.url, "https://acme.zoom.us/j/123456789")
    }

    func testMailStyleAngleBrackets() {
        let call = Agenda.videoCall(notes: "Link <https://meet.google.com/abc-defg-hij>", location: nil, url: nil)
        XCTAssertEqual(call?.url, "https://meet.google.com/abc-defg-hij")
    }
}

final class VideoCallWrapperTests: XCTestCase {

    func testOutlookSafeLinkIsUnwrapped() {
        let notes = "Join: https://nam12.safelinks.protection.outlook.com/?url=https%3A%2F%2Facme.zoom.us%2Fj%2F81234567890%3Fpwd%3DaBcDeF&data=05%7C02%7Cjane%40acme.com%7C&sdata=AbC%3D&reserved=0 today"
        let call = Agenda.videoCall(notes: notes, location: nil, url: nil)
        XCTAssertEqual(call, VideoCall(service: .zoom, url: "https://acme.zoom.us/j/81234567890?pwd=aBcDeF"))
    }

    func testGoogleRedirectIsUnwrapped() {
        let notes = "https://www.google.com/url?q=https://meet.google.com/abc-defg-hij&sa=D&source=calendar&ust=1700000000000000&usg=AOvVaw0abc"
        let call = Agenda.videoCall(notes: notes, location: nil, url: nil)
        XCTAssertEqual(call, VideoCall(service: .googleMeet, url: "https://meet.google.com/abc-defg-hij"))
    }

    func testEncodedGoogleRedirectOnACountryDomainKeepsThePasscode() {
        let notes = "https://www.google.co.uk/url?q=https%3A%2F%2Facme.zoom.us%2Fj%2F123%3Fpwd%3DSecret&sa=D&ust=1"
        XCTAssertEqual(Agenda.videoCall(notes: notes, location: nil, url: nil)?.url,
                       "https://acme.zoom.us/j/123?pwd=Secret")
    }

    func testNestedWrappersUnwrapAllTheWay() {
        // Outlook around Google around Teams — a forwarded Google invitation.
        let google = "https://www.google.com/url?q=https%3A%2F%2Fteams.microsoft.com%2Fmeet%2F123%3Fp%3DAbC&sa=D"
        let outlook = "https://eur02.safelinks.protection.outlook.com/?url="
            + google.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
            + "&data=05%7C02&reserved=0"
        XCTAssertEqual(Agenda.videoCall(notes: outlook, location: nil, url: nil),
                       VideoCall(service: .microsoftTeams, url: "https://teams.microsoft.com/meet/123?p=AbC"))
    }

    func testUndecodableWrapperIsLeftAlone() {
        let text = "https://www.google.com/url?q=https%3A%2F%2Fmeet.google.com%2F%ZZ&sa=D"
        XCTAssertEqual(VideoCallDetection.unwrappingRedirects(in: text), text)
    }

    func testPlainTextPassesThroughUntouched() {
        let text = "Lunch & learn at https://example.com/?a=1&b=2"
        XCTAssertEqual(VideoCallDetection.cleaned(text), text)
    }
}

final class VideoCallHTMLTests: XCTestCase {

    func testLinkInHrefIsFoundAndAmpersandsDecoded() {
        let notes = #"<p>Join: <a href="https://acme.zoom.us/j/123456789?pwd=abc&amp;uname=Jane">Click here to join</a></p>"#
        let call = Agenda.videoCall(notes: notes, location: nil, url: nil)
        XCTAssertEqual(call, VideoCall(service: .zoom, url: "https://acme.zoom.us/j/123456789?pwd=abc&uname=Jane"))
    }

    func testSafeLinkInsideHTML() {
        let notes = #"<div><a href="https://nam12.safelinks.protection.outlook.com/?url=https%3A%2F%2Fmeet.google.com%2Fabc-defg-hij&amp;data=05%7C02&amp;reserved=0">Join</a><br>Dial-in: +1 555 0100</div>"#
        XCTAssertEqual(Agenda.videoCall(notes: notes, location: nil, url: nil)?.url,
                       "https://meet.google.com/abc-defg-hij")
    }

    func testBreakTagsDoNotGlueOntoTheLink() {
        let notes = "Meeting link:<br>https://meet.google.com/abc-defg-hij<br/>Passcode: none"
        XCTAssertEqual(Agenda.videoCall(notes: notes, location: nil, url: nil)?.url,
                       "https://meet.google.com/abc-defg-hij")
    }

    func testEntityDecoding() {
        XCTAssertEqual(VideoCallDetection.decodingEntities("a &amp; b &lt;c&gt; &quot;d&quot; &#39;e&#39;"),
                       "a & b <c> \"d\" 'e'")
        XCTAssertEqual(VideoCallDetection.decodingEntities("&#38;&#x26;&nbsp;"), "&& ")
        XCTAssertEqual(VideoCallDetection.decodingEntities("&amp;lt;"), "&lt;", "decoded once, not twice")
        XCTAssertEqual(VideoCallDetection.decodingEntities("&unknown; stays"), "&unknown; stays")
    }
}

final class VideoCallPrecedenceTests: XCTestCase {

    func testDirectCallBeatsAWrapperThatForwardsToIt() {
        let notes = """
        This call is recorded by Gong: https://join.gong.io/acme/jane.doe?tkn=abc
        Zoom: https://acme.zoom.us/j/123456789
        """
        XCTAssertEqual(Agenda.videoCall(notes: notes, location: nil, url: nil)?.service, .zoom)
    }

    func testCatalogueOrderDecidesBetweenTwoServices() {
        let call = Agenda.videoCall(notes: "Old link: https://meet.jit.si/OldRoom",
                                    location: "https://meet.google.com/abc-defg-hij", url: nil)
        XCTAssertEqual(call?.service, .googleMeet)
    }

    func testRecognisedServiceBeatsTheURLField() {
        let call = Agenda.videoCall(notes: "Join https://acme.zoom.us/j/999",
                                    location: nil, url: "https://example.com/agenda")
        XCTAssertEqual(call?.url, "https://acme.zoom.us/j/999")
    }

    func testExplicitBlockBeatsTheCatalogue() {
        let notes = """
        Backup: https://meet.google.com/abc-defg-hij
        ----( Video Call )----
        https://acme.zoom.us/j/555
        ---===---
        """
        XCTAssertEqual(Agenda.videoCall(notes: notes, location: nil, url: nil),
                       VideoCall(service: .zoom, url: "https://acme.zoom.us/j/555"))
    }

    func testExplicitBlockAcceptsAnUnknownService() {
        let notes = "----( Video Call )----\nhttps://video.example.org/room/42\n---===---"
        XCTAssertEqual(Agenda.videoCall(notes: notes, location: nil, url: nil),
                       VideoCall(service: .other, url: "https://video.example.org/room/42"))
    }

    func testMeetingURLKeepsItsURLFieldFallback() {
        XCTAssertEqual(Agenda.meetingURL(notes: "no link", location: nil, url: "https://example.com/x"),
                       "https://example.com/x")
        XCTAssertNil(Agenda.videoCall(notes: "no link", location: nil, url: "https://example.com/x"))
    }
}

final class VideoCallNonMatchTests: XCTestCase {

    func testOrdinaryLinksAreNotCalls() {
        let notes = [
            "Agenda: https://docs.google.com/document/d/1AbC/edit",
            "Pricing at https://zoom.us/pricing",
            "https://www.webex.com/pricing/index.html",
            "https://teams.microsoft.com/",
            "https://meet.google.com/",
            "https://demodesk.com/pricing",
            "https://streamyard.com/resources",
            "https://www.ovice.com/",
            "https://www.gotomeeting.com/",
            "https://slack.com/intl/en-gb/",
            "https://www.google.com/search?q=zoom",
            "Download Zoom: https://zoom.us/download"
        ]
        for text in notes {
            XCTAssertNil(Agenda.videoCall(notes: text, location: nil, url: nil), text)
        }
    }

    func testNoTextAtAll() {
        XCTAssertNil(Agenda.videoCall(notes: nil, location: nil, url: nil))
        XCTAssertNil(Agenda.videoCall(notes: "Room 4", location: "Level 2", url: nil))
    }

    func testLookalikeHostsDoNotMatch() {
        XCTAssertNil(Agenda.videoCallService(of: "https://notzoom.us/j/123"))
        // Reads like Meet up to `.com`; the host is somebody else's.
        XCTAssertNil(Agenda.videoCallService(of: "https://meet.google.com.evil.example/abc"))
    }
}

final class VideoCallAppURLTests: XCTestCase {

    func testZoomJoinLinkConverts() {
        let call = VideoCall(service: .zoom, url: "https://acme.zoom.us/j/81234567890?pwd=aBcDeF")
        XCTAssertEqual(call.appURL, "zoommtg://acme.zoom.us/join?action=join&confno=81234567890&pwd=aBcDeF")
    }

    func testZoomWithoutPasscode() {
        XCTAssertEqual(VideoCall(service: .zoom, url: "https://zoom.us/j/123456789").appURL,
                       "zoommtg://zoom.us/join?action=join&confno=123456789")
    }

    func testOnlyPlainZoomMeetingsConvert() {
        XCTAssertNil(VideoCall(service: .zoom, url: "https://acme.zoom.us/my/jane").appURL)
        XCTAssertNil(VideoCall(service: .googleMeet, url: "https://meet.google.com/abc-defg-hij").appURL)
    }
}

final class AgendaEventVideoCallTests: XCTestCase {

    func testDecodesJSONWrittenBeforeTheNewFields() throws {
        let json = #"""
        {"id":"1","title":"T","calendar":"C","startsAt":0,"endsAt":3600,"isAllDay":false,
         "alarms":[],"isDetached":false,"availability":"busy","status":"none","attendees":[],
         "meetingURL":"https://acme.zoom.us/j/1"}
        """#
        let event = try JSONDecoder().decode(AgendaEvent.self, from: Data(json.utf8))
        XCTAssertEqual(event.meetingURL, "https://acme.zoom.us/j/1")
        XCTAssertNil(event.videoCall)
        XCTAssertNil(event.calendarItemId)
    }

    func testRoundTripsTheVideoCall() throws {
        let event = AgendaEvent(id: "1", title: "T", calendar: "C",
                                startsAt: Date(timeIntervalSinceReferenceDate: 0),
                                endsAt: Date(timeIntervalSinceReferenceDate: 3_600), isAllDay: false,
                                videoCall: VideoCall(service: .googleMeet, url: "https://meet.google.com/abc-defg-hij"))
        let decoded = try JSONDecoder().decode(AgendaEvent.self, from: JSONEncoder().encode(event))
        XCTAssertEqual(decoded.videoCall?.service, .googleMeet)
        XCTAssertEqual(decoded, event)
    }
}
