//
//  VideoCall.swift
//  AgendaKit
//
//  Created by David Sherlock on 2026.
//
//  A video-call link and the service it belongs to. Finding one is
//  `Support/VideoCallDetection.swift`; this is only the result.
//

import Foundation

/// The video call an event points at: which service, and the link to join it.
///
/// Built by ``Agenda/videoCall(notes:location:url:)`` and carried on
/// ``AgendaEvent/videoCall``. The URL is kept as the string found — after any Outlook or
/// Google redirect wrapper has been peeled off and HTML entities decoded — so it is the
/// address the service itself issued, not a tracking hop in front of it.
public struct VideoCall: Codable, Sendable, Equatable, Hashable {

    /// The service the link belongs to.
    public let service: VideoCallService

    /// The join link, unwrapped.
    public let url: String

    /// Creates a video-call record. Detection builds these; the memberwise form exists for
    /// tests and for callers assembling results by hand.
    public init(service: VideoCallService, url: String) {
        self.service = service
        self.url = url
    }
}
