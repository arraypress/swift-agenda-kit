//
//  ReminderSection.swift
//  AgendaKit
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A section of a reminder list, from the Reminders store.
public struct ReminderSection: Codable, Sendable, Equatable {

    /// The section's identifier.
    public let id: String

    /// Its name, as the list shows it.
    public let name: String

    /// The list it belongs to, by EventKit calendar identifier.
    public let listID: String?

    public init(id: String, name: String, listID: String?) {
        self.id = id
        self.name = name
        self.listID = listID
    }
}
