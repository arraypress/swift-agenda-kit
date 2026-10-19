//
//  SmartList.swift
//  AgendaKit
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A smart list from the Reminders store — read-only, and invisible to EventKit.
public struct SmartList: Codable, Sendable, Equatable {

    /// The smart list's identifier.
    public let id: String

    /// Its name. `nil` for a built-in one (Today, Flagged…), which Reminders names itself.
    public let name: String?

    /// `custom` for one a person made, otherwise the built-in kind — `today`, `flagged`.
    public let kind: String

    /// Its filter, one rule per line — `hashtags.hashtags: work, home` — when the
    /// stored filter could be read. `nil` when there is none or it is not JSON.
    public let rules: [String]?

    public init(id: String, name: String?, kind: String, rules: [String]?) {
        self.id = id
        self.name = name
        self.kind = kind
        self.rules = rules
    }
}
