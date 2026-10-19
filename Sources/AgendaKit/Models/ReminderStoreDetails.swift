//
//  ReminderStoreDetails.swift
//  AgendaKit
//
//  Created by David Sherlock on 2026.
//
//  What the Reminders store knows about a reminder that EventKit does not.
//

import Foundation

/// Tags, section and parent of one reminder, read from the Reminders store.
///
/// EventKit has no API for any of the three. Joined to an ``AgendaReminder``
/// by ``id``, which is the same string as its EventKit identifier.
public struct ReminderStoreDetails: Codable, Sendable, Equatable {

    /// The reminder's identifier — EventKit's `calendarItemIdentifier`.
    public let id: String

    /// Its tags, without the `#`, in the order they were added.
    public let tags: [String]

    /// The section of its list it sits in, if any.
    public let section: String?

    /// That section's identifier.
    public let sectionID: String?

    /// The reminder this is a subtask of, by EventKit identifier.
    public let parentID: String?

    /// The list it belongs to, by EventKit calendar identifier.
    public let listID: String?

    public init(id: String, tags: [String] = [], section: String? = nil, sectionID: String? = nil,
                parentID: String? = nil, listID: String? = nil) {
        self.id = id
        self.tags = tags
        self.section = section
        self.sectionID = sectionID
        self.parentID = parentID
        self.listID = listID
    }
}
