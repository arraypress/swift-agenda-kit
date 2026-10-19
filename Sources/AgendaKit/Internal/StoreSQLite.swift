//
//  StoreSQLite.swift
//  AgendaKit
//
//  Created by David Sherlock on 2026.
//
//  The smallest SQLite wrapper that runs the Reminders-store queries — opened
//  only ever on a private COPY of the store (see StoreSnapshot).
//

import Foundation
import SQLite3

/// A connection to a snapshot that runs SELECTs and nothing else.
///
/// Opened read-write on purpose — the copy carries the store's write-ahead
/// log, and folding a log into a read needs an index built beside it — then
/// locked with `PRAGMA query_only`, so a statement that writes is refused by
/// SQLite itself. Values are bound, never pasted into SQL.
final class StoreSQLite {

    private let handle: OpaquePointer

    init(path: String) throws {
        var pointer: OpaquePointer?
        let result = sqlite3_open_v2(path, &pointer, SQLITE_OPEN_READWRITE, nil)
        guard result == SQLITE_OK, let pointer else {
            let message = pointer.map { String(cString: sqlite3_errmsg($0)) } ?? "code \(result)"
            if let pointer { sqlite3_close_v2(pointer) }
            throw ReminderStoreError.readFailed(message)
        }
        handle = pointer
        sqlite3_busy_timeout(handle, 2000)
        guard sqlite3_exec(handle, "PRAGMA query_only = 1", nil, nil, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(handle))
            sqlite3_close_v2(handle)
            throw ReminderStoreError.readFailed(message)
        }
    }

    deinit { sqlite3_close_v2(handle) }

    /// Runs a query, handing each row to `row`.
    func query(_ sql: String, _ parameters: [Value] = [], row: (Row) throws -> Void) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw ReminderStoreError.readFailed(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(statement) }
        for (offset, parameter) in parameters.enumerated() {
            let index = Int32(offset + 1)
            switch parameter {
            case .integer(let value): sqlite3_bind_int64(statement, index, value)
            case .text(let value):
                // SQLITE_TRANSIENT: SQLite copies the bytes.
                sqlite3_bind_text(statement, index, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
        }
        while true {
            let step = sqlite3_step(statement)
            if step == SQLITE_ROW { try row(Row(statement: statement)); continue }
            if step == SQLITE_DONE { return }
            throw ReminderStoreError.readFailed(String(cString: sqlite3_errmsg(handle)))
        }
    }

    /// Each table's columns, upper-cased; a table that is absent is absent.
    func columns(of tables: [String]) throws -> [String: Set<String>] {
        var result: [String: Set<String>] = [:]
        for table in tables {
            var names: Set<String> = []
            try query("select name from pragma_table_info(?)", [.text(table)]) { row in
                if let name = row.text(0) { names.insert(name.uppercased()) }
            }
            if !names.isEmpty { result[table] = names }
        }
        return result
    }

    /// A value bound into a query.
    enum Value {
        case integer(Int64)
        case text(String)
    }

    /// One row of a result.
    struct Row {
        let statement: OpaquePointer

        func isNull(_ index: Int32) -> Bool { sqlite3_column_type(statement, index) == SQLITE_NULL }

        func integer(_ index: Int32) -> Int64? { isNull(index) ? nil : sqlite3_column_int64(statement, index) }

        func text(_ index: Int32) -> String? {
            guard let bytes = sqlite3_column_text(statement, index) else { return nil }
            return String(cString: bytes)
        }

        func data(_ index: Int32) -> Data? {
            guard let bytes = sqlite3_column_blob(statement, index) else { return nil }
            return Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, index)))
        }
    }
}
