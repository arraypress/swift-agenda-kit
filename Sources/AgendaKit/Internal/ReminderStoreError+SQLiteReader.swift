//
//  ReminderStoreError+SQLiteReader.swift
//  AgendaKit
//
//  Created by David Sherlock on 2026.
//
//  The Reminders store is read through swift-sqlite-reader; its errors are
//  reported as this library's own, so callers and messages stay the same.
//

import Foundation
import SQLiteReader

extension ReminderStoreError {

    /// This library's error for a reader's.
    init(_ error: SQLiteReaderError) {
        switch error {
        case .notFound(let path): self = .missing(path)
        case .permissionDenied(let path): self = .notPermitted(path)
        case .unreadable(_, let reason): self = .readFailed(reason)
        }
    }
}
