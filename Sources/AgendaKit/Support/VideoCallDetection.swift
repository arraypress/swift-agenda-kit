//
//  VideoCallDetection.swift
//  AgendaKit
//
//  Created by David Sherlock on 2026.
//
//  Finding the video call in an event's free text: undoing the HTML
//  and redirect wrappers mail and calendar servers put around links,
//  honouring an explicitly marked call, then walking the catalogue in
//  precedence order. Pure functions over strings, so every rule is
//  pinned by a fixture rather than by a calendar.
//

import Foundation

/// Video-call detection over an event's notes, location and URL field.
enum VideoCallDetection {

    // MARK: - Detection

    /// The video call an event points at, or `nil` when it has none.
    ///
    /// Precedence, highest first:
    /// 1. A link inside a `----( Video Call )----` block in the notes. That block is an
    ///    explicit statement of which link is the call — the convention Dato documents
    ///    for marking one by hand — so it beats any guess, and its link counts even on a
    ///    service the catalogue does not know (``VideoCallService/other``).
    /// 2. The first catalogue entry, in ``VideoCallCatalogue/entries`` order, that matches
    ///    anywhere in the three fields together.
    ///
    /// An unrecognised link is *not* a call: notes are full of agenda documents and
    /// booking pages, and calling one of those a meeting is worse than saying nothing.
    static func videoCall(notes: String?, location: String?, url: String?) -> VideoCall? {
        let fields = [notes, location, url].compactMap { $0 }.map(cleaned)
        let haystack = fields.joined(separator: "\n")
        guard haystack.contains("://") else { return nil }

        if let notes, let marked = explicitCallLink(in: cleaned(notes)) {
            return VideoCall(service: service(of: marked) ?? .other, url: marked)
        }
        return firstCatalogueMatch(in: haystack)
    }

    /// The legacy single-string answer: the detected call's link, else the event's own
    /// URL field, else `nil`.
    ///
    /// The URL-field fallback predates the catalogue and is kept because callers rely on
    /// it — an organiser who puts the call link in the URL field of a service nobody has
    /// heard of still gets a link back. It is returned as stored, not unwrapped.
    static func meetingURL(notes: String?, location: String?, url: String?) -> String? {
        videoCall(notes: notes, location: location, url: url)?.url ?? url?.nilIfBlank
    }

    /// The service a single URL belongs to, or `nil` when the catalogue does not know it.
    static func service(of url: String) -> VideoCallService? {
        firstCatalogueMatch(in: url)?.service
    }

    /// The first catalogue match in `text`, walking entries in precedence order.
    private static func firstCatalogueMatch(in text: String) -> VideoCall? {
        let range = NSRange(text.startIndex..., in: text)
        for (service, regex) in VideoCallCatalogue.compiled {
            guard let match = regex.firstMatch(in: text, options: [], range: range),
                  let found = Range(match.range, in: text) else { continue }
            return VideoCall(service: service, url: trimmingTrailingPunctuation(String(text[found])))
        }
        return nil
    }

    // MARK: - The explicit block

    /// The header Dato documents for marking an event's call by hand.
    private static let blockHeader = try? NSRegularExpression(
        pattern: #"-{2,}\(\s*Video Call\s*\)-{2,}"#, options: .caseInsensitive)

    /// The line that closes the block.
    private static let blockFooter = "---===---"

    /// Any link, for reading the explicit block — which may name a service the catalogue
    /// does not know.
    private static let anyLink = try? NSRegularExpression(pattern: #"https?://[^\s<>"']+"#, options: .caseInsensitive)

    /// The first link between a `----( Video Call )----` header and its `---===---`
    /// footer (or the end of the text, when the footer was lost to an editor).
    static func explicitCallLink(in notes: String) -> String? {
        guard let blockHeader, let anyLink,
              let header = blockHeader.firstMatch(in: notes, range: NSRange(notes.startIndex..., in: notes)),
              let headerRange = Range(header.range, in: notes) else { return nil }

        let afterHeader = notes[headerRange.upperBound...]
        let body = afterHeader.range(of: blockFooter).map { afterHeader[..<$0.lowerBound] } ?? afterHeader
        let text = String(body)
        guard let link = anyLink.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let linkRange = Range(link.range, in: text) else { return nil }
        return trimmingTrailingPunctuation(String(text[linkRange]))
    }

    // MARK: - Cleaning

    /// One field made searchable: HTML flattened, then redirect wrappers peeled off.
    ///
    /// HTML goes first because a wrapper inside an `href` carries `&amp;` between its
    /// parameters, and the unwrapping has to see a real `&` to know where the target ends.
    static func cleaned(_ text: String) -> String {
        unwrappingRedirects(in: flatteningHTML(text))
    }

    /// Notes with their markup made harmless: tag brackets become spaces and character
    /// entities are decoded.
    ///
    /// Tags are *opened up* rather than removed, deliberately. Calendar invitations put the
    /// real link in `href` and show "Join meeting" as the text, so deleting tags wholesale
    /// would delete the very URL being looked for. Turning `<` and `>` into spaces leaves
    /// `href="https://…"` behind, and the link patterns already stop at a quote.
    static func flatteningHTML(_ text: String) -> String {
        guard text.contains("<") || text.contains("&") else { return text }
        let opened = text.replacingOccurrences(of: "<", with: " ").replacingOccurrences(of: ">", with: " ")
        return decodingEntities(opened)
    }

    /// The named entities that turn up in calendar HTML, and what they stand for.
    /// `&nbsp;` becomes an ordinary space so it separates words like one.
    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " "
    ]

    private static let entityPattern = try? NSRegularExpression(
        pattern: #"&(#[0-9]+|#[xX][0-9a-fA-F]+|[a-zA-Z]+);"#)

    /// `text` with named and numeric character entities decoded in a single pass — so
    /// `&amp;lt;` becomes the literal `&lt;`, not `<`.
    ///
    /// An entity this does not know is left as written rather than guessed at.
    static func decodingEntities(_ text: String) -> String {
        guard text.contains("&"), let entityPattern else { return text }
        var result = ""
        var copied = text.startIndex
        for match in entityPattern.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let whole = Range(match.range, in: text),
                  let name = Range(match.range(at: 1), in: text),
                  let decoded = decodedEntity(String(text[name])) else { continue }
            result += text[copied..<whole.lowerBound]
            result += decoded
            copied = whole.upperBound
        }
        result += text[copied...]
        return result
    }

    /// The character an entity body (`amp`, `#38`, `#x26`) stands for.
    private static func decodedEntity(_ body: String) -> String? {
        if body.hasPrefix("#") {
            let digits = body.dropFirst()
            let value = digits.first.map({ $0 == "x" || $0 == "X" }) == true
                ? UInt32(digits.dropFirst(), radix: 16)
                : UInt32(digits, radix: 10)
            return value.flatMap(Unicode.Scalar.init).map { String(Character($0)) }
        }
        return namedEntities[body.lowercased()]
    }

    /// Outlook's Safe Links wrapper: `https://<region>.safelinks.protection.outlook.com/?url=<encoded>&data=…`.
    /// Capture 1 is the encoded target; the rest of the wrapper's parameters are consumed
    /// so they do not end up glued to the unwrapped link.
    private static let outlookSafeLink = try? NSRegularExpression(
        pattern: #"https?://[\w.-]+\.safelinks\.protection\.outlook\.com/?\?(?:[^\s<>"']*?&)?url=([^&\s<>"']+)[^\s<>"']*"#,
        options: .caseInsensitive)

    /// Google's click-tracking redirect, `https://www.google.com/url?q=<encoded>&sa=D&…`,
    /// on any country domain. Google percent-encodes the whole target, so every `&` after
    /// `q=` is Google's own and the target ends at the first one.
    private static let googleRedirect = try? NSRegularExpression(
        pattern: #"https?://(?:www\.)?google\.[a-z]{2,3}(?:\.[a-z]{2})?/url\?(?:[^\s<>"']*?&)?q=([^&\s<>"']+)[^\s<>"']*"#,
        options: .caseInsensitive)

    /// `text` with every Outlook Safe Link and Google redirect replaced by the link it
    /// wraps, percent-decoded.
    ///
    /// Repeats while it makes progress, because forwarded mail wraps a wrapper — Outlook
    /// around Google around Zoom is a real invitation — and stops after a few rounds
    /// whatever happens. A target that will not decode is left wrapped rather than
    /// guessed at; it then simply fails to match a service.
    static func unwrappingRedirects(in text: String) -> String {
        guard text.contains("safelinks.protection.outlook.com") || text.contains("/url?") else { return text }
        var current = text
        for _ in 0..<4 {
            var changed = false
            for wrapper in [outlookSafeLink, googleRedirect].compactMap({ $0 }) {
                if let rewritten = replacingWrappers(in: current, using: wrapper) {
                    current = rewritten
                    changed = true
                }
            }
            if !changed { break }
        }
        return current
    }

    /// One pass of one wrapper pattern: each match spliced out for its decoded target.
    /// `nil` when nothing changed, which is what ends the loop above.
    private static func replacingWrappers(in text: String, using regex: NSRegularExpression) -> String? {
        var result = ""
        var copied = text.startIndex
        var changed = false
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let whole = Range(match.range, in: text),
                  let target = Range(match.range(at: 1), in: text),
                  let decoded = String(text[target]).removingPercentEncoding,
                  decoded != String(text[whole]) else { continue }
            result += text[copied..<whole.lowerBound]
            result += decoded
            copied = whole.upperBound
            changed = true
        }
        guard changed else { return nil }
        result += text[copied...]
        return result
    }

    /// `url` without the sentence punctuation that prose leaves stuck to the end of a
    /// link: `Join at https://zoom.us/j/1.` means `…/j/1`.
    ///
    /// A closing bracket is kept when the link opened one itself, since a few services do
    /// put brackets in paths; it is dropped when it closes the sentence's own parenthesis.
    static func trimmingTrailingPunctuation(_ url: String) -> String {
        var trimmed = Substring(url)
        while let last = trimmed.last {
            switch last {
            case ".", ",", ";", ":", "!", "?", "*":
                trimmed = trimmed.dropLast()
            case ")" where trimmed.filter({ $0 == ")" }).count > trimmed.filter({ $0 == "(" }).count,
                 "]" where trimmed.filter({ $0 == "]" }).count > trimmed.filter({ $0 == "[" }).count:
                trimmed = trimmed.dropLast()
            default:
                return String(trimmed)
            }
        }
        return String(trimmed)
    }

    // MARK: - Native app links

    private static let zoomJoinPath = try? NSRegularExpression(pattern: #"^/j/(\d+)/?$"#)

    /// A Zoom web join link rewritten for the Zoom app:
    /// `https://acme.zoom.us/j/123?pwd=abc` → `zoommtg://acme.zoom.us/join?action=join&confno=123&pwd=abc`.
    ///
    /// Opening the `zoommtg:` form goes straight into the desktop client instead of
    /// through the browser's "Open zoom.us?" interstitial. Only plain `/j/<number>`
    /// meetings convert; personal-room (`/my/`) and webinar links have no app form that
    /// is reliable from outside, so they return `nil` and the web link stays the answer.
    static func zoomAppURL(for url: String) -> String? {
        guard let components = URLComponents(string: url),
              let host = components.host?.lowercased(),
              host == "zoom.us" || host.hasSuffix(".zoom.us") || host == "zoomgov.com" || host.hasSuffix(".zoomgov.com"),
              let zoomJoinPath,
              let match = zoomJoinPath.firstMatch(in: components.path, range: NSRange(components.path.startIndex..., in: components.path)),
              let idRange = Range(match.range(at: 1), in: components.path) else { return nil }

        var app = URLComponents()
        app.scheme = "zoommtg"
        app.host = host
        app.path = "/join"
        var items = [URLQueryItem(name: "action", value: "join"),
                     URLQueryItem(name: "confno", value: String(components.path[idRange]))]
        if let pwd = components.queryItems?.first(where: { $0.name == "pwd" })?.value {
            items.append(URLQueryItem(name: "pwd", value: pwd))
        }
        app.queryItems = items
        return app.string
    }
}
