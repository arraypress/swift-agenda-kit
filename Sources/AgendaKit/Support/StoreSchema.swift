//
//  StoreSchema.swift
//  AgendaKit
//
//  Created by David Sherlock on 2026.
//
//  The shape of the Reminders store this reads, and the checks that it still
//  has it.
//
//  WHERE THE COLUMN NAMES CAME FROM. Not a write-up: ReminderKit's own Core
//  Data model (ReminderData.momd, current version v2026_A) was loaded and a
//  scratch store built from it, which came out column-for-column identical
//  to the live one. A hashtag object written into that scratch store landed
//  in ZREMCDOBJECT with its reminder in ZREMINDER3 and its name in ZNAME1 —
//  Core Data numbers columns that several sub-entities share, so those two
//  numbers are the fragile part, and the reason for the version check.
//

import Foundation

enum StoreSchema {

    /// Model versions whose column layout was checked against a real store.
    static let knownVersions: Set<String> = ["v2026_A"]

    /// The Core Data entities read, by name. Their numbers are looked up in
    /// `Z_PRIMARYKEY`, never assumed.
    enum Entity {
        static let list = "REMCDList"
        static let smartList = "REMCDSmartList"
        static let listSection = "REMCDListSection"
        static let hashtag = "REMCDHashtag"
    }

    /// Every column the queries read, by table.
    static let required: [String: Set<String>] = [
        "Z_PRIMARYKEY": ["Z_ENT", "Z_NAME"],
        "ZREMCDREMINDER": ["Z_PK", "ZIDENTIFIER", "ZCKIDENTIFIER", "ZDACALENDARITEMUNIQUEIDENTIFIER",
                           "ZPARENTREMINDER", "ZLIST", "ZMARKEDFORDELETION"],
        "ZREMCDOBJECT": ["Z_PK", "Z_ENT", "ZREMINDER3", "ZNAME1", "ZHASHTAGLABEL", "ZMARKEDFORDELETION"],
        "ZREMCDHASHTAGLABEL": ["Z_PK", "ZNAME"],
        "ZREMCDBASELIST": ["Z_PK", "Z_ENT", "ZIDENTIFIER", "ZCKIDENTIFIER", "ZNAME", "ZMARKEDFORDELETION",
                           "ZMEMBERSHIPSOFREMINDERSINSECTIONSASDATA", "ZFILTERDATA", "ZSMARTLISTTYPE"],
        "ZREMCDBASESECTION": ["Z_PK", "Z_ENT", "ZIDENTIFIER", "ZCKIDENTIFIER", "ZDISPLAYNAME", "ZLIST",
                              "ZMARKEDFORDELETION"],
    ]

    /// `TABLE.COLUMN` for each one missing, given each table's columns.
    static func missing(_ present: [String: Set<String>]) -> [String] {
        required.keys.sorted().flatMap { table in
            required[table, default: []].subtracting(present[table, default: []]).sorted().map { "\(table).\($0)" }
        }
    }

    /// The model version in a `Z_METADATA.Z_PLIST`.
    static func modelVersion(_ plist: Data?) -> String? {
        guard let plist,
              let dictionary = try? PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: Any],
              let identifiers = dictionary["NSStoreModelVersionIdentifiers"] as? [Any] else { return nil }
        return identifiers.compactMap { $0 as? String }.first
    }

    /// A 16-byte `ZIDENTIFIER` as the UUID string EventKit uses, upper-cased.
    ///
    /// Measured on a live iCloud reminder: EventKit's `calendarItemIdentifier`,
    /// `ZCKIDENTIFIER`, `ZDACALENDARITEMUNIQUEIDENTIFIER` and this were the
    /// same UUID; for a list, `calendarIdentifier` matched the same way.
    static func uuid(_ blob: Data?) -> String? {
        guard let blob, blob.count == 16 else { return nil }
        let bytes = [UInt8](blob)
        let uuid = UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                               bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
        return uuid.uuidString
    }
}
