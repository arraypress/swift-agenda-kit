//
//  ReminderStoreContents.swift
//  AgendaKit
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Everything read from the Reminders store in one pass.
///
/// Built by ``RemindersStore/read(from:)``.
public struct ReminderStoreContents: Sendable, Equatable {

    /// Per reminder, by EventKit identifier.
    public let reminders: [String: ReminderStoreDetails]

    /// Every list section.
    public let sections: [ReminderSection]

    /// Every smart list.
    public let smartLists: [SmartList]

    /// The store's Core Data model version, e.g. `v2026_A`.
    public let modelVersion: String?

    /// Whether that version is one this was checked against. An unknown one is
    /// still read when every column is present — but the caller should say so.
    public let isKnownVersion: Bool

    /// How many store files were read.
    public let storeCount: Int

    public init(reminders: [String: ReminderStoreDetails], sections: [ReminderSection],
                smartLists: [SmartList], modelVersion: String?, isKnownVersion: Bool, storeCount: Int) {
        self.reminders = reminders
        self.sections = sections
        self.smartLists = smartLists
        self.modelVersion = modelVersion
        self.isKnownVersion = isKnownVersion
        self.storeCount = storeCount
    }

    /// The details for one EventKit identifier.
    public func details(for id: String) -> ReminderStoreDetails? {
        reminders[id.uppercased()]
    }
}

/// How well EventKit's reminders and the store's rows line up.
public struct ReminderJoinReport: Codable, Sendable, Equatable {

    /// EventKit reminders found in the store.
    public let matched: Int

    /// EventKit reminders the store has no row for.
    public let eventKitOnly: Int

    /// Store rows EventKit did not return — deleted-but-not-purged, or in an
    /// account EventKit does not expose.
    public let storeOnly: Int

    public init(matched: Int, eventKitOnly: Int, storeOnly: Int) {
        self.matched = matched
        self.eventKitOnly = eventKitOnly
        self.storeOnly = storeOnly
    }

    /// matched / EventKit total, or 1 when EventKit has none.
    public var rate: Double {
        let total = matched + eventKitOnly
        return total == 0 ? 1 : Double(matched) / Double(total)
    }
}
