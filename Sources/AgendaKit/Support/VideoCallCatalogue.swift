//
//  VideoCallCatalogue.swift
//  AgendaKit
//
//  Created by David Sherlock on 2026.
//
//  The URL shape of every recognised video-call service, as data, in
//  the order detection tries them. Each pattern is written against the
//  link a service actually issues — a join path, not just a host — so
//  a link to a vendor's pricing page is not mistaken for a meeting.
//

import Foundation

/// The video-call link shapes, in precedence order.
enum VideoCallCatalogue {

    /// One service and the pattern its join links match.
    struct Entry {
        let service: VideoCallService
        let pattern: String
    }

    /// The rest of a URL once its recognising prefix has matched: anything up to
    /// whitespace, a quote, or an angle bracket — the characters that end a link in
    /// plain text, in an HTML attribute, or between `<` `>` in a mail body.
    private static let rest = #"[^\s<>"']*"#

    /// As ``rest``, but at least one character, for shapes whose prefix alone is
    /// only a service's home page.
    private static let restOne = #"[^\s<>"']+"#

    /// Every recognised service, most trusted first.
    ///
    /// Order only matters when one event carries links to two different services, and
    /// the rule it encodes is: a direct meeting link beats a link that *leads to* one.
    /// Gong, Chorus and Reclaim issue wrapper links that record consent or track a
    /// booking and then forward to the real call, and invitations carrying them usually
    /// carry the Zoom or Meet link too — so those three sit last, and the call itself
    /// wins. Among direct services the widely used ones come first, which is the better
    /// guess when an organiser has pasted two (an old link left in a recurring invite is
    /// more often the niche one).
    ///
    /// The generic fallback — the event's own URL field when nothing here matches — is
    /// not an entry; it belongs to ``Agenda/meetingURL(notes:location:url:)`` and sits
    /// below all of these.
    ///
    /// Shapes not confirmed against a live link are marked; they match on the host the
    /// service is documented to use, with a path required so a bare home page is not a
    /// call.
    static let entries: [Entry] = [
        // Zoom and ZoomGov: join (`/j/`), personal rooms (`/my/`), webinars (`/w/`), the
        // web client (`/wc/`), and registration pages, which is all some invitations carry.
        // Vanity subdomains like `acme.zoom.us` and data-centre ones like
        // `us02web.zoom.us` are both common.
        Entry(service: .zoom,
              pattern: #"https?://(?:[\w-]+\.)*zoom(?:gov)?\.(?:us|com|com\.cn|de)/(?:j|my|w|s|wc|webinar|meeting/register)/"# + restOne),
        // Teams: classic meetup-join links and the newer short `/meet/<id>?p=` form, on
        // the work, government and consumer (`teams.live.com`) hosts.
        Entry(service: .microsoftTeams,
              pattern: #"https?://(?:[\w-]+\.)?teams\.(?:microsoft\.(?:com|us)|live\.com)/(?:l/meetup-join|meet)/"# + restOne),
        Entry(service: .googleMeet,
              pattern: #"https?://meet\.google\.com/(?:_meet/|lookup/)?[a-z0-9-]+"# + rest),
        // Webex: `j.php?MTID=` scheduled meetings, `/meet/` and `/join/` personal rooms,
        // optionally under a site path (`acme.webex.com/acme/j.php`).
        Entry(service: .webex,
              pattern: #"https?://(?:[\w-]+\.)*webex\.com/(?:[\w.-]+/)?(?:j\.php\?|meet/|join/|wbxmjs/)"# + restOne),
        // GoTo rebranded; invitations carry the old and new hosts side by side.
        Entry(service: .goToMeeting,
              pattern: #"https?://(?:(?:[\w-]+\.)?gotomeeting\.com|meet\.goto\.com|gotomeet\.me)/"# + restOne),
        Entry(service: .goToWebinar,
              pattern: #"https?://(?:[\w-]+\.)?gotowebinar\.com/"# + restOne),
        Entry(service: .ringCentral,
              pattern: #"https?://(?:v|meetings|video)\.ringcentral\.com/"# + restOne),
        Entry(service: .faceTime,
              pattern: #"https?://facetime\.apple\.com/join"# + rest),
        Entry(service: .slack,
              pattern: #"https?://(?:[\w-]+\.)*slack\.com/huddle/"# + restOne),
        Entry(service: .skype,
              pattern: #"https?://join\.skype\.com/[\w-]+"#),
        Entry(service: .blueJeans,
              pattern: #"https?://(?:[\w-]+\.)?bluejeans\.com/"# + restOne),
        Entry(service: .amazonChime,
              pattern: #"https?://(?:app\.)?chime\.aws/"# + restOne),
        Entry(service: .eightByEight,
              pattern: #"https?://(?:[\w-]+\.)?8x8\.vc/"# + restOne),
        Entry(service: .jitsiMeet,
              pattern: #"https?://meet\.jit\.si/"# + restOne),
        Entry(service: .whereby,
              pattern: #"https?://(?:[\w-]+\.)?whereby\.com/[\w-]+"# + rest),
        // Signal call links keep their key in the fragment: `signal.link/call/#key=…`.
        Entry(service: .signal,
              pattern: #"https?://signal\.link/call/"# + restOne),
        Entry(service: .dialpad,
              pattern: #"https?://meetings\.dialpad\.com/"# + restOne),
        Entry(service: .vonage,
              pattern: #"https?://meetings\.vonage\.com/"# + restOne),
        // VooV is Tencent Meeting outside China; the domestic host shares link shapes.
        Entry(service: .vooV,
              pattern: #"https?://(?:(?:www\.)?voovmeeting\.com|meeting\.tencent\.com)/"# + restOne),
        // Lark is Feishu outside China; same product, two hosts.
        Entry(service: .lark,
              pattern: #"https?://(?:[\w-]+\.)?vc\.(?:larksuite\.com|feishu\.cn)/j/\d+"#),
        Entry(service: .zhumu,
              pattern: #"https?://welink\.zhumu\.com/(?:j|wc/join)/"# + restOne),
        Entry(service: .zohoCliq,
              pattern: #"https?://cliq\.zoho\.(?:com|eu|in|com\.au|jp|ca)/meetings/"# + restOne),
        Entry(service: .workplaceChat,
              pattern: #"https?://(?:[\w-]+\.)*workplace\.com/(?:groupcall|meet)/"# + restOne),
        Entry(service: .teamViewer,
              pattern: #"https?://go\.teamviewer\.com/"# + restOne),
        Entry(service: .calCom,
              pattern: #"https?://(?:app\.)?cal\.com/video/"# + restOne),
        Entry(service: .pumble,
              pattern: #"https?://meet\.pumble\.com/[\w-]+"#),
        Entry(service: .around,
              pattern: #"https?://(?:meet\.)?around\.co/"# + restOne),
        Entry(service: .jam,
              pattern: #"https?://jam\.systems/"# + restOne),
        Entry(service: .coScreen,
              pattern: #"https?://join\.coscreen\.co/"# + restOne),
        Entry(service: .tuple,
              pattern: #"https?://tuple\.app/c/"# + restOne),
        Entry(service: .pop,
              pattern: #"https?://pop\.com/j/[\d-]+"#),
        Entry(service: .gather,
              pattern: #"https?://app\.(?:v2\.)?gather\.town/(?:app|invite|events)\b"# + restOne),
        // oVice spaces live on their own subdomain; the marketing site is `www.`.
        Entry(service: .oVice,
              pattern: #"https?://(?!www\.)(?:[\w-]+\.)+ovice\.(?:in|com)\b"# + rest),
        Entry(service: .teemyco,
              pattern: #"https?://app\.teemyco\.com/room/"# + restOne),
        // `app.huddle01.com/<room>` now redirects to `huddle01.app/room/<room>`
        // (checked 2026-10); both appear in calendars.
        Entry(service: .huddle01,
              pattern: #"https?://(?:app\.huddle01\.com/[\w-]+|huddle01\.app/room/[\w-]+)"#),
        Entry(service: .liveKitMeet,
              pattern: #"https?://(?:[\w-]+\.)*livekit\.io/rooms/"# + restOne),
        Entry(service: .meetecho,
              pattern: #"https?://meetings\.conf\.meetecho\.com/"# + restOne),
        // Vowel keeps the room in the fragment: `vowel.com/#/g/<room>`.
        Entry(service: .vowel,
              pattern: #"https?://(?:[\w-]+\.)?vowel\.com/#/g/"# + restOne),
        Entry(service: .doxyMe,
              pattern: #"https?://(?:[\w-]+\.)?doxy\.me/[\w.-]+"#),
        // Demodesk issues one-off codes (`demodesk.com/ZLWEOIKS`) and lobby links
        // (`demodesk.com/meet/<name>`); the code is upper case, which is what keeps
        // `demodesk.com/pricing` out. The company now also answers on `demodesk.ai`.
        Entry(service: .demodesk,
              pattern: #"https?://(?:www\.)?demodesk\.(?:com|ai)/(?:meet/[\w.-]+|(?-i:[A-Z0-9]{6,12})\b)"#),
        Entry(service: .demio,
              pattern: #"https?://(?:event|my)\.demio\.com/"# + restOne),
        Entry(service: .livestorm,
              pattern: #"https?://app\.livestorm\.com?/"# + restOne),
        Entry(service: .luma,
              pattern: #"https?://(?:lu\.ma|luma\.com)/join/"# + restOne),
        // StreamYard guest codes are 8–13 characters with at least one digit, which is
        // what separates them from `streamyard.com/resources`.
        Entry(service: .streamYard,
              pattern: #"https?://(?:www\.)?streamyard\.com/(?:watch/[\w-]+|(?:guest/)?(?=[a-z]*\d)[a-z0-9]{8,13}\b)"# + rest),
        Entry(service: .vimeo,
              pattern: #"https?://(?:vimeo\.com/event/\d+|venues\.vimeo\.com/[\w-]+)"# + rest),
        Entry(service: .venue,
              pattern: #"https?://app\.venue\.live/"# + restOne),
        Entry(service: .userZoom,
              pattern: #"https?://go\.userzoom\.com/participate/"# + restOne),
        // Unconfirmed: the lesson room's path. Preply's help centre describes the
        // classroom but never prints its address, so this keys on the word.
        Entry(service: .preply,
              pattern: #"https?://(?:www\.)?preply\.com/[^\s<>"']*(?:classroom|space)"# + rest),
        // Unconfirmed: Sessions (sessions.us) runs on `app.sessions.us`, but no public
        // join link was found to pin the path.
        Entry(service: .sessions,
              pattern: #"https?://app\.sessions\.us/"# + restOne),
        // Unconfirmed: Relayed's site (`relayed.ai`) was a parked page when checked in
        // 2026-10; this keeps recognising old invitations on that host.
        Entry(service: .relayed,
              pattern: #"https?://(?:[\w-]+\.)?relayed\.ai/"# + restOne),
        // Wrappers last — see the precedence note above.
        Entry(service: .reclaim,
              pattern: #"https?://(?:app\.)?reclaim\.ai/z/"# + restOne),
        Entry(service: .gong,
              pattern: #"https?://(?:[\w-]+\.)*join\.gong\.io/"# + restOne),
        Entry(service: .chorus,
              pattern: #"https?://go\.chorus\.ai/"# + restOne)
    ]

    /// ``entries`` compiled once, case-insensitively — hosts arrive in any case, and
    /// a pattern that must not fold opts out inline with `(?-i:…)`.
    ///
    /// A pattern that fails to compile is a bug in this file, so it traps in debug and
    /// drops out in release rather than taking every other service with it.
    static let compiled: [(service: VideoCallService, regex: NSRegularExpression)] =
        entries.compactMap { entry in
            do {
                return (entry.service, try NSRegularExpression(pattern: entry.pattern, options: .caseInsensitive))
            } catch {
                assertionFailure("invalid pattern for \(entry.service): \(entry.pattern)")
                return nil
            }
        }
}
