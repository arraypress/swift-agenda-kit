//
//  ReminderStoreError.swift
//  AgendaKit
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Why the Reminders store could not be read.
///
/// None of these is a reason for a reminders listing to fail: EventKit still
/// answers, and the caller says what it could not add. Each message names
/// the fix.
public enum ReminderStoreError: LocalizedError, Equatable, Sendable {

    /// No store where Reminders keeps one — Reminders never set up on this Mac.
    case missing(String)

    /// macOS refused the read: Full Disk Access is not granted to whatever
    /// runs this (for a command line, the terminal app).
    case notPermitted(String)

    /// The store's tables are not the shape this was written against — a
    /// newer macOS changed them. Lists what is missing, `TABLE.COLUMN`.
    case unknownSchema([String])

    /// SQLite or the copy failed.
    case readFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missing:
            return "No Reminders store on this Mac, so tags, sections and subtasks cannot be read."
        case .notPermitted:
            return """
                macOS refused to let agenda read the Reminders store, so tags, sections and subtasks \
                cannot be shown. Grant Full Disk Access to your terminal app under System Settings → \
                Privacy & Security → Full Disk Access.
                """
        case .unknownSchema(let missing):
            return "The Reminders store has changed shape (missing \(missing.prefix(4).joined(separator: ", "))), "
                 + "so tags, sections and subtasks cannot be read safely."
        case .readFailed(let reason):
            return "Could not read the Reminders store: \(reason)"
        }
    }
}
