//
//  RemindersStore.swift
//  AgendaKit
//
//  Created by David Sherlock on 2026.
//
//  Tags, sections, subtasks and smart lists — read from Reminders' own store,
//  because EventKit has no API for any of them.
//
//  READ-ONLY, AND NEVER IN PLACE. Each store file is cloned with its log into a
//  private folder and read there (see StoreSnapshot); Reminders' files are only
//  ever read as bytes. Nothing here writes, and there is no write path to add.
//
//  JOINED BY IDENTIFIER. A store row's 16-byte ZIDENTIFIER is the reminder's
//  EventKit `calendarItemIdentifier` (ZCKIDENTIFIER and
//  ZDACALENDARITEMUNIQUEIDENTIFIER carry the same string on iCloud; both are
//  accepted as aliases for accounts where they differ).
//

import Foundation

/// Reading the Reminders store.
///
/// ```swift
/// let store = try RemindersStore.read()
/// store.details(for: reminder.id)?.tags   // ["errands"]
/// ```
public enum RemindersStore {

    /// Where Reminders keeps its stores on macOS.
    public static var defaultFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers/group.com.apple.reminders/Container_v1/Stores")
    }

    /// Reads every `Data-*.sqlite` store in `folder`.
    ///
    /// - Throws: ``ReminderStoreError`` — `.missing`, `.notPermitted` (Full Disk
    ///   Access), `.unknownSchema` or `.readFailed`. A caller listing reminders
    ///   should show EventKit's answer anyway and say which.
    public static func read(from folder: URL = defaultFolder) throws -> ReminderStoreContents {
        let (access, names) = StoreAccess.listing(folder.path)
        switch access {
        case .readable: break
        case .missing: throw ReminderStoreError.missing(folder.path)
        case .refused: throw ReminderStoreError.notPermitted(folder.path)
        }
        let files = names.filter { $0.hasPrefix("Data-") && $0.hasSuffix(".sqlite") }.sorted()
        guard !files.isEmpty else { throw ReminderStoreError.missing(folder.path) }

        var parts: [StorePart] = []
        for file in files {
            let snapshot = try StoreSnapshot(of: folder.appendingPathComponent(file))
            parts.append(try read(snapshot.database))
        }
        return merge(parts)
    }

    /// How EventKit's reminders line up with the store's rows.
    ///
    /// - Parameter eventKitIDs: Every reminder EventKit returned, completed ones
    ///   included, or the store-only count means nothing.
    public static func join(eventKitIDs: [String], with contents: ReminderStoreContents) -> ReminderJoinReport {
        var matchedRows = Set<String>()
        var matched = 0
        for id in eventKitIDs {
            if let details = contents.details(for: id) {
                matched += 1
                matchedRows.insert(details.id)
            }
        }
        let rows = Set(contents.reminders.values.map(\.id))
        return ReminderJoinReport(matched: matched, eventKitOnly: eventKitIDs.count - matched,
                                  storeOnly: rows.subtracting(matchedRows).count)
    }

    // MARK: - One store

    /// What one store file holds.
    struct StorePart {
        var reminders: [ReminderStoreDetails] = []
        var aliases: [String: String] = [:]      // any identifier → canonical
        var sections: [ReminderSection] = []
        var smartLists: [SmartList] = []
        var modelVersion: String?
        var listCount = 0

        /// Whether this store holds anything — an account's leftover empty store
        /// (this Mac had a `Data-local` at an older model, with no rows) is not
        /// a reason to doubt the others.
        var holdsData: Bool { listCount > 0 || !reminders.isEmpty }
    }

    static func read(_ database: StoreSQLite) throws -> StorePart {
        let missing = StoreSchema.missing(try database.columns(of: Array(StoreSchema.required.keys)))
        guard missing.isEmpty else { throw ReminderStoreError.unknownSchema(missing) }

        var part = StorePart()
        try database.query("select Z_PLIST from Z_METADATA limit 1") { row in
            part.modelVersion = StoreSchema.modelVersion(row.data(0))
        }

        var entities: [String: Int64] = [:]
        try database.query("select Z_NAME, Z_ENT from Z_PRIMARYKEY") { row in
            if let name = row.text(0), let ent = row.integer(1) { entities[name] = ent }
        }
        let needed = [StoreSchema.Entity.list, StoreSchema.Entity.smartList,
                      StoreSchema.Entity.listSection, StoreSchema.Entity.hashtag]
        let absent = needed.filter { entities[$0] == nil }
        guard absent.isEmpty else { throw ReminderStoreError.unknownSchema(absent.map { "Z_PRIMARYKEY.\($0)" }) }

        // Lists: their EventKit identifier, section memberships and — for smart
        // lists — the filter.
        var listIDs: [Int64: String] = [:]
        var memberships: [String: String] = [:]
        try database.query("""
            select Z_PK, Z_ENT, ZIDENTIFIER, ZCKIDENTIFIER, ZNAME,
                   ZMEMBERSHIPSOFREMINDERSINSECTIONSASDATA, ZFILTERDATA, ZSMARTLISTTYPE
            from ZREMCDBASELIST where coalesce(ZMARKEDFORDELETION, 0) = 0
            """) { row in
            guard let pk = row.integer(0) else { return }
            let id = StoreSchema.uuid(row.data(2)) ?? row.text(3)?.uppercased() ?? "list-\(pk)"
            listIDs[pk] = id
            part.listCount += 1
            memberships.merge(SectionMemberships.decode(row.data(5))) { _, new in new }
            if row.integer(1) == entities[StoreSchema.Entity.smartList] {
                part.smartLists.append(SmartList(id: id, name: row.text(4)?.nilIfBlank,
                                                 kind: SmartListRules.kind(row.text(7)),
                                                 rules: SmartListRules.decode(row.data(6))))
            }
        }

        // Sections, by every identifier a membership might use.
        var sectionsByAlias: [String: ReminderSection] = [:]
        try database.query("""
            select Z_PK, ZIDENTIFIER, ZCKIDENTIFIER, ZDISPLAYNAME, ZLIST from ZREMCDBASESECTION
            where Z_ENT = ? and coalesce(ZMARKEDFORDELETION, 0) = 0
            """, [.integer(entities[StoreSchema.Entity.listSection]!)]) { row in
            guard let pk = row.integer(0) else { return }
            let uuid = StoreSchema.uuid(row.data(1))
            let ck = row.text(2)?.uppercased()
            let section = ReminderSection(id: uuid ?? ck ?? "section-\(pk)",
                                          name: row.text(3) ?? "Untitled",
                                          listID: row.integer(4).flatMap { listIDs[$0] })
            part.sections.append(section)
            for alias in [uuid, ck].compactMap({ $0 }) { sectionsByAlias[alias] = section }
        }

        // Tags, by the reminder's row.
        var tags: [Int64: [String]] = [:]
        try database.query("""
            select o.ZREMINDER3, o.ZNAME1, l.ZNAME from ZREMCDOBJECT o
            left join ZREMCDHASHTAGLABEL l on l.Z_PK = o.ZHASHTAGLABEL
            where o.Z_ENT = ? and o.ZREMINDER3 is not null and coalesce(o.ZMARKEDFORDELETION, 0) = 0
            order by o.Z_PK
            """, [.integer(entities[StoreSchema.Entity.hashtag]!)]) { row in
            guard let reminder = row.integer(0),
                  let name = (row.text(1)?.nilIfBlank ?? row.text(2)?.nilIfBlank) else { return }
            let clean = name.hasPrefix("#") ? String(name.dropFirst()) : name
            if !(tags[reminder]?.contains(clean) ?? false) { tags[reminder, default: []].append(clean) }
        }

        // Reminders.
        struct Raw { let pk: Int64; let aliases: [String]; let parent: Int64?; let list: Int64? }
        var raws: [Raw] = []
        try database.query("""
            select Z_PK, ZIDENTIFIER, ZCKIDENTIFIER, ZDACALENDARITEMUNIQUEIDENTIFIER, ZPARENTREMINDER, ZLIST
            from ZREMCDREMINDER where coalesce(ZMARKEDFORDELETION, 0) = 0
            """) { row in
            guard let pk = row.integer(0) else { return }
            var aliases: [String] = []
            for alias in [StoreSchema.uuid(row.data(1)), row.text(2)?.uppercased(), row.text(3)?.uppercased()] {
                if let alias, !aliases.contains(alias) { aliases.append(alias) }
            }
            guard !aliases.isEmpty else { return }
            raws.append(Raw(pk: pk, aliases: aliases, parent: row.integer(4), list: row.integer(5)))
        }
        let canonical = Dictionary(raws.map { ($0.pk, $0.aliases[0]) }, uniquingKeysWith: { first, _ in first })
        for raw in raws {
            let section = raw.aliases.lazy.compactMap { memberships[$0] }.first.flatMap { sectionsByAlias[$0] }
            part.reminders.append(ReminderStoreDetails(
                id: raw.aliases[0], tags: tags[raw.pk] ?? [], section: section?.name, sectionID: section?.id,
                parentID: raw.parent.flatMap { canonical[$0] }, listID: raw.list.flatMap { listIDs[$0] }
            ))
            for alias in raw.aliases { part.aliases[alias] = raw.aliases[0] }
        }
        return part
    }

    static func merge(_ parts: [StorePart]) -> ReminderStoreContents {
        var byCanonical: [String: ReminderStoreDetails] = [:]
        for part in parts { for details in part.reminders { byCanonical[details.id] = details } }
        var reminders: [String: ReminderStoreDetails] = [:]
        for part in parts {
            for (alias, canonical) in part.aliases { reminders[alias] = byCanonical[canonical] }
        }
        let versions = parts.filter(\.holdsData).compactMap(\.modelVersion)
        return ReminderStoreContents(
            reminders: reminders,
            sections: parts.flatMap(\.sections),
            smartLists: parts.flatMap(\.smartLists),
            modelVersion: versions.first ?? parts.compactMap(\.modelVersion).first,
            isKnownVersion: versions.allSatisfy(StoreSchema.knownVersions.contains),
            storeCount: parts.count
        )
    }
}
