//
//  VideoCall+AppURL.swift
//  AgendaKit
//
//  Created by David Sherlock on 2026.
//
//  The native-app form of a call link, where one exists. Delegates to
//  `VideoCallDetection`.
//

import Foundation

extension VideoCall {

    /// The link rewritten to open the service's desktop app directly, or `nil` when there
    /// is no dependable app form.
    ///
    /// Only Zoom's `/j/<number>` meetings convert today
    /// (`https://acme.zoom.us/j/123?pwd=abc` → `zoommtg://acme.zoom.us/join?action=join&confno=123&pwd=abc`),
    /// which skips the browser's "Open zoom.us?" step. Everything else — including Zoom
    /// personal rooms and webinars — returns `nil`; open ``url`` instead.
    public var appURL: String? {
        guard service == .zoom else { return nil }
        return VideoCallDetection.zoomAppURL(for: url)
    }
}
