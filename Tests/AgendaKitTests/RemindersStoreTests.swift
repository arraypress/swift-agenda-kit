//
//  RemindersStoreTests.swift
//  AgendaKitTests
//
//  Created by David Sherlock on 2026.
//
//  The Reminders-store reader against a synthetic store with the live schema:
//  what it reads, what it skips, how it joins, and how it fails.
//

import CryptoKit
import Foundation
import XCTest
@testable import AgendaKit

final class RemindersStoreTests: XCTestCase {

    func testTagsSectionsAndParentsAreRead() throws {
        let fixture = try ReminderStoreFixture()
        let store = try RemindersStore.read(from: fixture.folder)

        let apples = try XCTUnwrap(store.details(for: Fixture.apples))
        XCTAssertEqual(apples.tags, ["work", "home"], "a nameless hashtag takes its label's name; '#work' is the same tag")
        XCTAssertEqual(apples.section, "Produce")
        XCTAssertEqual(apples.sectionID, Fixture.produce)
        XCTAssertNil(apples.parentID)
        XCTAssertEqual(apples.listID, Fixture.groceries)

        let seeds = try XCTUnwrap(store.details(for: Fixture.seeds))
        XCTAssertEqual(seeds.parentID, Fixture.apples)
        XCTAssertNil(seeds.section, "an obsolete membership is no membership")
        XCTAssertEqual(seeds.tags, [])
    }

    func testRowsOnlyInTheLogAreRead() throws {
        let fixture = try ReminderStoreFixture()
        let store = try RemindersStore.read(from: fixture.folder)
        XCTAssertEqual(store.details(for: Fixture.milk)?.section, "Dairy")
    }

    func testDeletedRowsDoNotShow() throws {
        let fixture = try ReminderStoreFixture()
        let store = try RemindersStore.read(from: fixture.folder)
        XCTAssertNil(store.details(for: Fixture.deleted))
        XCTAssertFalse(store.sections.contains { $0.name == "Gone" })
        XCTAssertFalse(store.smartLists.contains { $0.name == "Deleted smart" })
        XCTAssertFalse(store.details(for: Fixture.apples)?.tags.contains("gone") ?? true)
        XCTAssertFalse(store.details(for: Fixture.apples)?.tags.contains("an alarm, not a tag") ?? true)
    }

    func testEitherIdentifierFindsTheSameReminder() throws {
        let fixture = try ReminderStoreFixture()
        let store = try RemindersStore.read(from: fixture.folder)
        XCTAssertEqual(store.details(for: Fixture.caldav)?.id, Fixture.caldav)
        XCTAssertEqual(store.details(for: Fixture.caldavCK)?.id, Fixture.caldav)
        XCTAssertEqual(store.details(for: Fixture.apples.lowercased())?.id, Fixture.apples)
    }

    func testJoinCountsBothSides() throws {
        let fixture = try ReminderStoreFixture()
        let store = try RemindersStore.read(from: fixture.folder)
        let report = RemindersStore.join(eventKitIDs: [Fixture.apples, Fixture.caldavCK, "NOT-IN-THE-STORE"], with: store)
        XCTAssertEqual(report.matched, 2)
        XCTAssertEqual(report.eventKitOnly, 1)
        XCTAssertEqual(report.storeOnly, 2, "seeds and milk")
        XCTAssertEqual(report.rate, 2.0 / 3.0, accuracy: 1e-9)
        XCTAssertEqual(RemindersStore.join(eventKitIDs: [], with: store).rate, 1)
    }

    func testSmartListsCarryTheirRules() throws {
        let fixture = try ReminderStoreFixture()
        let store = try RemindersStore.read(from: fixture.folder)
        let custom = try XCTUnwrap(store.smartLists.first { $0.id == Fixture.workFocus })
        XCTAssertEqual(custom.name, "Work focus")
        XCTAssertEqual(custom.kind, "custom")
        XCTAssertEqual(custom.rules, ["flagged: true", "hashtags.hashtags: work, urgent", "hashtags.operation: or"])
        let today = try XCTUnwrap(store.smartLists.first { $0.id == Fixture.today })
        XCTAssertNil(today.name)
        XCTAssertEqual(today.kind, "today")
        XCTAssertNil(today.rules)
    }

    func testVersionIsReported() throws {
        let current = try ReminderStoreFixture()
        let known = try RemindersStore.read(from: current.folder)
        XCTAssertEqual(known.modelVersion, "v2026_A")
        XCTAssertTrue(known.isKnownVersion)

        let later = try ReminderStoreFixture(version: "v2027_A")
        let newer = try RemindersStore.read(from: later.folder)
        XCTAssertEqual(newer.modelVersion, "v2027_A")
        XCTAssertFalse(newer.isKnownVersion)
        XCTAssertEqual(newer.details(for: Fixture.apples)?.tags, ["work", "home"], "still read when every column is there")
    }

    func testTheLiveFilesAreNeverWritten() throws {
        let fixture = try ReminderStoreFixture()
        let paths = ["", "-wal", "-shm"].map { fixture.database.path + $0 }
        func digests() -> [String] {
            paths.map { path in
                (FileManager.default.contents(atPath: path).map { SHA256.hash(data: $0).description }) ?? "absent"
            }
        }
        let before = digests()
        _ = try RemindersStore.read(from: fixture.folder)
        XCTAssertEqual(digests(), before)
    }

    func testAChangedSchemaIsRefusedByName() throws {
        let fixture = try ReminderStoreFixture(dropping: ["ZREMCDOBJECT.ZNAME1"])
        XCTAssertThrowsError(try RemindersStore.read(from: fixture.folder)) { error in
            XCTAssertEqual(error as? ReminderStoreError, .unknownSchema(["ZREMCDOBJECT.ZNAME1"]))
        }
    }

    func testAMissingStoreSaysSo() throws {
        let nowhere = FileManager.default.temporaryDirectory.appendingPathComponent("agenda-nowhere-\(UUID().uuidString)")
        XCTAssertThrowsError(try RemindersStore.read(from: nowhere)) { error in
            XCTAssertEqual(error as? ReminderStoreError, .missing(nowhere.path))
        }
        let empty = FileManager.default.temporaryDirectory.appendingPathComponent("agenda-empty-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: empty) }
        XCTAssertThrowsError(try RemindersStore.read(from: empty)) { error in
            XCTAssertEqual(error as? ReminderStoreError, .missing(empty.path))
        }
    }

    func testARefusedFolderIsNotCalledMissing() throws {
        let fixture = try ReminderStoreFixture()
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: fixture.folder.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fixture.folder.path) }
        XCTAssertThrowsError(try RemindersStore.read(from: fixture.folder)) { error in
            XCTAssertEqual(error as? ReminderStoreError, .notPermitted(fixture.folder.path))
        }
    }

    func testMembershipDecodingIsLenient() {
        XCTAssertEqual(SectionMemberships.decode(Data(#"[{"memberIdentifier":"a","groupIdentifier":"b"}]"#.utf8)), ["A": "B"])
        XCTAssertEqual(SectionMemberships.decode(Data("not json".utf8)), [:])
        XCTAssertEqual(SectionMemberships.decode(nil), [:])
        XCTAssertEqual(SectionMemberships.decode(Data(#"{"memberships":[{"memberID":"a"}]}"#.utf8)), [:])
    }

    func testRulesThatAreNotAnObjectAreNotRules() {
        XCTAssertNil(SmartListRules.decode(Data("[1,2]".utf8)))
        XCTAssertNil(SmartListRules.decode(Data()))
        XCTAssertEqual(SmartListRules.decode(Data(#"{"a":[{"b":1}],"c":null}"#.utf8)), ["a[0].b: 1", "c: null"])
        XCTAssertEqual(SmartListRules.kind(nil), "custom")
    }
}
