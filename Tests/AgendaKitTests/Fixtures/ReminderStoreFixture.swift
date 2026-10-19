//
//  ReminderStoreFixture.swift
//  AgendaKitTests
//
//  Created by David Sherlock on 2026.
//
//  A synthetic Reminders store with the live schema and made-up rows: two lists
//  (one with sections), a custom and a built-in smart list, tags, a subtask, a
//  reminder whose CloudKit id differs from its own, and deleted rows of every
//  kind that must not show. Nothing in it came from a real store but the shape.
//

import Foundation
import SQLite3
import XCTest

/// Identifiers the fixture uses, so tests can name them.
enum Fixture {
    static let groceries = "11111111-1111-1111-1111-111111111111"
    static let workFocus = "22222222-2222-2222-2222-222222222222"
    static let today = "33333333-3333-3333-3333-333333333333"
    static let produce = "44444444-4444-4444-4444-444444444444"
    static let dairy = "55555555-5555-5555-5555-555555555555"
    static let goneSection = "66666666-6666-6666-6666-666666666666"
    static let apples = "AAAAAAAA-0000-0000-0000-000000000001"     // tags work + home, in Produce
    static let seeds = "AAAAAAAA-0000-0000-0000-000000000002"      // subtask of apples, obsolete membership
    static let milk = "AAAAAAAA-0000-0000-0000-000000000003"       // in Dairy, written to the log only
    static let deleted = "AAAAAAAA-0000-0000-0000-000000000004"    // marked for deletion
    static let caldav = "AAAAAAAA-0000-0000-0000-000000000005"     // own id differs from its CK id
    static let caldavCK = "BBBBBBBB-0000-0000-0000-000000000005"
}

/// A store on disk, plus the writer that keeps its log un-checkpointed.
final class ReminderStoreFixture {

    let folder: URL
    let database: URL
    private var writer: OpaquePointer?

    /// - Parameters:
    ///   - version: The model version Z_METADATA records.
    ///   - dropping: `TABLE.COLUMN`s to leave out, to fake a changed schema.
    init(version: String = "v2026_A", dropping: Set<String> = []) throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("agenda-fixture-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        database = folder.appendingPathComponent("Data-FIXTURE.sqlite")
        XCTAssertEqual(sqlite3_open(database.path, &writer), SQLITE_OK)
        try exec("PRAGMA journal_mode = WAL")
        try exec("PRAGMA wal_autocheckpoint = 0")
        for sql in ReminderStoreSchema.tables { try exec(Self.dropColumns(sql, dropping)) }
        for (ent, name, sup) in ReminderStoreSchema.entities {
            try exec("insert into Z_PRIMARYKEY values (\(ent), '\(name)', \(sup), 0)")
        }
        let plist = try PropertyListSerialization.data(
            fromPropertyList: ["NSStoreModelVersionIdentifiers": [version], "NSStoreType": "SQLite"],
            format: .binary, options: 0)
        try exec("insert into Z_METADATA (Z_VERSION, Z_UUID, Z_PLIST) values (1, 'x', x'\(plist.hex)')")
        // A changed schema is refused before any row is read, so it needs none.
        if dropping.isEmpty { try populate() }
    }

    deinit {
        sqlite3_close(writer)
        try? FileManager.default.removeItem(at: folder)
    }

    func exec(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(writer, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? "?"
            sqlite3_free(error)
            throw NSError(domain: "fixture", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(message) — \(sql.prefix(80))"])
        }
    }

    private func populate() throws {
        let memberships = #"""
        {"minimumSupportedVersion":20230430,"memberships":[
         {"memberID":"\#(Fixture.apples)","groupID":"\#(Fixture.produce)","modifiedOn":700000000},
         {"memberID":"\#(Fixture.seeds)","groupID":"\#(Fixture.produce)","isObsolete":true,"modifiedOn":700000001},
         {"memberID":"\#(Fixture.milk)","groupID":"\#(Fixture.dairy)","modifiedOn":700000002}]}
        """#
        let filter = #"{"hashtags":{"hashtags":["work","urgent"],"operation":"or"},"flagged":true}"#
        try exec("begin")
        // Lists: 3 REMCDList, 4 REMCDSmartList.
        try exec("""
            insert into ZREMCDBASELIST (Z_PK, Z_ENT, ZIDENTIFIER, ZCKIDENTIFIER, ZNAME, ZMARKEDFORDELETION,
              ZMEMBERSHIPSOFREMINDERSINSECTIONSASDATA) values
              (1, 3, x'\(Fixture.groceries.uuidHex)', '\(Fixture.groceries)', 'Groceries', 0, x'\(Data(memberships.utf8).hex)')
            """)
        try exec("""
            insert into ZREMCDBASELIST (Z_PK, Z_ENT, ZIDENTIFIER, ZNAME, ZMARKEDFORDELETION, ZFILTERDATA, ZSMARTLISTTYPE) values
              (2, 4, x'\(Fixture.workFocus.uuidHex)', 'Work focus', 0, x'\(Data(filter.utf8).hex)', 'com.apple.reminders.smartlist.custom'),
              (3, 4, x'\(Fixture.today.uuidHex)', null, 0, null, 'com.apple.reminders.smartlist.today'),
              (4, 4, x'\("77777777-7777-7777-7777-777777777777".uuidHex)', 'Deleted smart', 1, null, null)
            """)
        // Sections: 6 REMCDListSection.
        try exec("""
            insert into ZREMCDBASESECTION (Z_PK, Z_ENT, ZIDENTIFIER, ZCKIDENTIFIER, ZDISPLAYNAME, ZLIST, ZMARKEDFORDELETION) values
              (1, 6, x'\(Fixture.produce.uuidHex)', '\(Fixture.produce)', 'Produce', 1, 0),
              (2, 6, x'\(Fixture.dairy.uuidHex)', '\(Fixture.dairy)', 'Dairy', 1, 0),
              (3, 6, x'\(Fixture.goneSection.uuidHex)', null, 'Gone', 1, 1)
            """)
        // Reminders.
        try exec("""
            insert into ZREMCDREMINDER (Z_PK, Z_ENT, ZIDENTIFIER, ZCKIDENTIFIER, ZDACALENDARITEMUNIQUEIDENTIFIER,
              ZPARENTREMINDER, ZLIST, ZMARKEDFORDELETION, ZTITLE) values
              (1, 39, x'\(Fixture.apples.uuidHex)', '\(Fixture.apples)', '\(Fixture.apples)', null, 1, 0, 'Apples'),
              (2, 39, x'\(Fixture.seeds.uuidHex)', '\(Fixture.seeds)', null, 1, 1, 0, 'Seeds'),
              (4, 39, x'\(Fixture.deleted.uuidHex)', '\(Fixture.deleted)', null, null, 1, 1, 'Deleted'),
              (5, 39, x'\(Fixture.caldav.uuidHex)', '\(Fixture.caldavCK)', null, null, 1, 0, 'CalDAV')
            """)
        // Tags: 32 REMCDHashtag in ZREMCDOBJECT. "home" has no name of its own, only its label's.
        try exec("""
            insert into ZREMCDHASHTAGLABEL (Z_PK, Z_ENT, ZNAME, ZCANONICALNAME) values
              (1, 11, 'work', 'work'), (2, 11, 'home', 'home'), (3, 11, 'gone', 'gone')
            """)
        try exec("""
            insert into ZREMCDOBJECT (Z_PK, Z_ENT, ZREMINDER3, ZNAME1, ZHASHTAGLABEL, ZMARKEDFORDELETION) values
              (1, 32, 1, 'work', 1, 0),
              (2, 32, 1, null, 2, 0),
              (3, 32, 1, 'gone', 3, 1),
              (4, 32, 1, '#work', 1, 0),
              (5, 15, 1, 'an alarm, not a tag', null, 0)
            """)
        try exec("commit")
        // Written last, and never checkpointed: only the log holds it.
        try exec("""
            insert into ZREMCDREMINDER (Z_PK, Z_ENT, ZIDENTIFIER, ZCKIDENTIFIER, ZPARENTREMINDER, ZLIST, ZMARKEDFORDELETION, ZTITLE)
            values (3, 39, x'\(Fixture.milk.uuidHex)', '\(Fixture.milk)', null, 1, 0, 'Milk')
            """)
    }

    /// A CREATE TABLE with some columns left out.
    static func dropColumns(_ sql: String, _ dropping: Set<String>) -> String {
        guard let open = sql.firstIndex(of: "("), let close = sql.lastIndex(of: ")") else { return sql }
        let table = sql[sql.startIndex..<open].split(separator: " ").last.map(String.init) ?? ""
        let columns = sql[sql.index(after: open)..<close].split(separator: ",").filter { column in
            let name = column.trimmingCharacters(in: .whitespaces).split(separator: " ").first.map(String.init) ?? ""
            return !dropping.contains("\(table).\(name)")
        }
        return String(sql[...open]) + columns.joined(separator: ",") + ")"
    }
}

extension Data {
    var hex: String { map { String(format: "%02x", $0) }.joined() }
}

extension String {
    /// A UUID string as the 16 bytes Core Data stores, in hex.
    var uuidHex: String { replacingOccurrences(of: "-", with: "") }
}
