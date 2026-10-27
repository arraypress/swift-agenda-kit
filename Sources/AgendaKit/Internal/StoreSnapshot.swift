//
//  StoreSnapshot.swift
//  AgendaKit
//
//  Created by David Sherlock on 2026.
//
//  WHY A COPY, AND NOT A READ-ONLY OPEN. A reader opened with `mode=ro` on a
//  WAL database that another process has open still writes its read marks
//  into the `-shm` file (measured for swift-whatsapp-messages, the same
//  shape). So a "read-only" open of the Reminders store is a write into
//  Reminders' container. Instead the database and its log are copied into a
//  private folder by swift-sqlite-reader's `.snapshot` and read there, and
//  the copy is deleted when the reader goes. Reminders' own files are only
//  ever read as bytes.
//
//  Two things are this library's own: a store that changes while it is
//  copied is copied again, and the copy is locked with `PRAGMA query_only`,
//  so a statement that writes is refused by SQLite itself.
//

import Foundation
import SQLiteReader

/// Private copies of a store and its log.
enum StoreSnapshot {

    /// How many times to copy a store that keeps changing under the copy.
    static let attempts = 4

    /// A reader over a private copy of the store at `source`, taken while the
    /// store held still.
    static func open(_ source: URL) throws -> SQLiteReader {
        for _ in 0..<attempts {
            let before = signature(source)
            let reader: SQLiteReader
            do {
                reader = try SQLiteReader(path: source, opening: .snapshot, busyTimeout: 2)
            } catch {
                throw ReminderStoreError(error)
            }
            guard signature(source) == before else {
                Thread.sleep(forTimeInterval: 0.05)
                continue
            }
            do {
                _ = try reader.rows("PRAGMA query_only = 1")
            } catch {
                throw ReminderStoreError(error)
            }
            return reader
        }
        throw ReminderStoreError.readFailed("the store kept changing while it was copied")
    }

    /// Size and modification time of the database and its log.
    static func signature(_ source: URL) -> [Double] {
        ["", "-wal"].flatMap { suffix -> [Double] in
            var info = stat()
            guard stat(source.path + suffix, &info) == 0 else { return [-1, -1] }
            return [Double(info.st_size),
                    Double(info.st_mtimespec.tv_sec) + Double(info.st_mtimespec.tv_nsec) / 1e9]
        }
    }
}

/// Listing the stores' folder, telling "macOS said no" from "it is not there".
///
/// Privacy protection refuses with EPERM, plain permissions with EACCES — and
/// Foundation reports a refusal on a PARENT folder as "file not found", so the
/// check asks the kernel directly (the rule is swift-sqlite-reader's `FileChecks`).
enum StoreAccess {

    /// What listing a folder finds.
    static func listing(_ path: String) -> (FileAccess, [String]) {
        guard let directory = opendir(path) else {
            return (FileChecks.isRefusal(errno: errno) ? .refused : .missing, [])
        }
        defer { closedir(directory) }
        var names: [String] = []
        while let entry = readdir(directory) {
            let name = withUnsafePointer(to: entry.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
            }
            names.append(name)
        }
        return (.readable, names)
    }
}
