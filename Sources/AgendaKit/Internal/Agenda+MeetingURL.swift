//
//  Agenda+MeetingURL.swift
//  SwiftAgenda
//
//  Digging the video-call link out of an event's free-text fields.
//  The catalogue and the rules live in Support/; this is the public door.
//
//  Created by David Sherlock on 7/19/26.
//

import Foundation

extension Agenda {

    /// The video call an event's text points at — which service, and the link.
    ///
    /// Searches notes, location, and the URL field together — organisers put the link
    /// in whichever one their client chose, and there is no reliable convention. Before
    /// matching, HTML is flattened (`&amp;` decoded, `href` targets kept) and Outlook Safe
    /// Links and Google redirect wrappers are peeled off, so what comes back is the
    /// service's own address.
    ///
    /// Specific services beat any fallback, and direct call links beat the wrapper links
    /// that forward to one (Gong, Chorus, Reclaim). A link inside a
    /// `----( Video Call )----` notes block beats everything, being an explicit statement
    /// rather than a guess.
    ///
    /// - Returns: The call, or `nil` when no recognised service's link appears. An
    ///   unrecognised link is not treated as a call.
    public static func videoCall(notes: String?, location: String?, url: String?) -> VideoCall? {
        VideoCallDetection.videoCall(notes: notes, location: location, url: url)
    }

    /// The first video-call link found across an event's text fields.
    ///
    /// The single-string form of ``videoCall(notes:location:url:)``, kept for callers that
    /// only want a link to open.
    ///
    /// - Returns: The matched URL, the raw `url` field when nothing matches but a URL
    ///   exists, or `nil` when the event has no link at all.
    public static func meetingURL(notes: String?, location: String?, url: String?) -> String? {
        VideoCallDetection.meetingURL(notes: notes, location: location, url: url)
    }

    /// The service a single link belongs to, or `nil` when it is not a recognised
    /// video-call link. The link is taken as given — wrappers are not unwrapped here.
    public static func videoCallService(of url: String) -> VideoCallService? {
        VideoCallDetection.service(of: url)
    }
}
