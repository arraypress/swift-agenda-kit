//
//  SmartListRules.swift
//  AgendaKit
//
//  Created by David Sherlock on 2026.
//
//  A smart list's filter as lines a person can read.
//
//  The filter is `REMCustomSmartListFilterDescriptor`, stored as JSON in
//  `ZFILTERDATA`. Its keys are not documented and none was available to
//  measure, so it is NOT interpreted: every leaf is printed under its key
//  path — `hashtags.hashtags: work, home` — which is faithful whatever the
//  keys turn out to be.
//

import Foundation

enum SmartListRules {

    /// One line per leaf, sorted by key path; `nil` when there is no filter or
    /// it is not a JSON object.
    static func decode(_ data: Data?) -> [String]? {
        guard let data, !data.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        var lines: [String] = []
        flatten(object, path: "", into: &lines)
        return lines
    }

    private static func flatten(_ value: Any, path: String, into lines: inout [String]) {
        if let dictionary = value as? [String: Any] {
            for key in dictionary.keys.sorted() {
                flatten(dictionary[key]!, path: path.isEmpty ? key : "\(path).\(key)", into: &lines)
            }
        } else if let array = value as? [Any] {
            if array.allSatisfy({ !($0 is [String: Any]) && !($0 is [Any]) }) {
                lines.append("\(path): \(array.map(scalar).joined(separator: ", "))")
            } else {
                for (index, element) in array.enumerated() { flatten(element, path: "\(path)[\(index)]", into: &lines) }
            }
        } else {
            lines.append("\(path): \(scalar(value))")
        }
    }

    private static func scalar(_ value: Any) -> String {
        if value is NSNull { return "null" }
        if let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() {
            return number.boolValue ? "true" : "false"
        }
        return "\(value)"
    }

    /// `com.apple.reminders.smartlist.today` → `today`; none → `custom`.
    static func kind(_ type: String?) -> String {
        guard let type, !type.isEmpty else { return "custom" }
        return type.split(separator: ".").last.map(String.init) ?? type
    }
}
