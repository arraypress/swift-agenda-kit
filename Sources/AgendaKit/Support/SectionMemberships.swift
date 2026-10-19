//
//  SectionMemberships.swift
//  AgendaKit
//
//  Created by David Sherlock on 2026.
//
//  Which reminder sits in which section — stored on the LIST, not the reminder.
//
//  A list keeps `membershipsOfRemindersInSectionsAsData`: JSON naming each
//  member (a reminder) and its group (a section). The key names are
//  ReminderKit's own (`memberships`, `memberID`, `groupID`, `isObsolete`,
//  `modifiedOn` — all present as strings in the framework, and `REMMembership`
//  carries exactly those fields). No live store on the Mac this was written
//  on had a section, so the decoding is lenient: the identifier-named
//  spellings are accepted too, and anything else is no membership rather than
//  a failure.
//

import Foundation

enum SectionMemberships {

    /// Section identifier by member (reminder) identifier, both upper-cased.
    /// Obsolete memberships — a reminder moved out of a section — are dropped.
    static func decode(_ data: Data?) -> [String: String] {
        guard let data, !data.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: data) else { return [:] }
        let entries: [Any]
        if let dictionary = object as? [String: Any] {
            entries = (dictionary["memberships"] as? [Any]) ?? []
        } else {
            entries = (object as? [Any]) ?? []
        }
        var result: [String: String] = [:]
        for case let entry as [String: Any] in entries {
            if (entry["isObsolete"] as? Bool) == true { continue }
            guard let member = (entry["memberID"] ?? entry["memberIdentifier"]) as? String,
                  let group = (entry["groupID"] ?? entry["groupIdentifier"]) as? String else { continue }
            result[member.uppercased()] = group.uppercased()
        }
        return result
    }
}
