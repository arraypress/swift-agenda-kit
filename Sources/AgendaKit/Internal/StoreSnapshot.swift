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
//  Reminders' container. Instead the database and its log are cloned into a
//  private folder — APFS clones, no data copied, milliseconds — and read
//  there. Reminders' own files are only ever read as bytes.
//
//  The `-shm` file is NOT copied: it is an index of the live process's
//  readers, and SQLite rebuilds it from the log when the copy is opened.
//

import Foundation

/// A private copy of one store and its log, deleted when done.
final class StoreSnapshot {

    let database: StoreSQLite
    private let folder: URL

    /// How many times to copy a store that keeps changing under the copy.
    static let attempts = 4

    init(of source: URL) throws {
        switch StoreAccess.access(source.path) {
        case .readable: break
        case .missing: throw ReminderStoreError.missing(source.path)
        case .refused: throw ReminderStoreError.notPermitted(source.path)
        }

        let fileManager = FileManager.default
        folder = fileManager.temporaryDirectory
            .appendingPathComponent("agenda-reminders-\(UUID().uuidString)", isDirectory: true)
        let target = folder.appendingPathComponent(source.lastPathComponent)
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true,
                                            attributes: [.posixPermissions: 0o700])
            var steady = false
            for _ in 0..<Self.attempts {
                let before = Self.signature(source)
                for suffix in ["", "-wal"] {
                    let from = URL(fileURLWithPath: source.path + suffix)
                    let to = URL(fileURLWithPath: target.path + suffix)
                    try? fileManager.removeItem(at: to)
                    guard suffix.isEmpty || fileManager.fileExists(atPath: from.path) else { continue }
                    // copyItem clones on APFS.
                    try fileManager.copyItem(at: from, to: to)
                }
                if Self.signature(source) == before { steady = true; break }
                Thread.sleep(forTimeInterval: 0.05)
            }
            guard steady else { throw ReminderStoreError.readFailed("the store kept changing while it was copied") }
        } catch let error as ReminderStoreError {
            try? fileManager.removeItem(at: folder)
            throw error
        } catch {
            try? fileManager.removeItem(at: folder)
            if StoreAccess.isRefusal(error) { throw ReminderStoreError.notPermitted(source.path) }
            throw ReminderStoreError.readFailed(error.localizedDescription)
        }

        do {
            database = try StoreSQLite(path: target.path)
        } catch {
            try? fileManager.removeItem(at: folder)
            throw error
        }
    }

    deinit { try? FileManager.default.removeItem(at: folder) }

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

/// Telling "macOS said no" from "it is not there".
///
/// Privacy protection refuses with EPERM, plain permissions with EACCES — and
/// Foundation reports a refusal on a PARENT folder as "file not found", so the
/// check asks the kernel directly.
enum StoreAccess {

    enum Access: Equatable { case readable, missing, refused }

    static func access(_ path: String) -> Access {
        let descriptor = open(path, O_RDONLY)
        if descriptor >= 0 {
            close(descriptor)
            return .readable
        }
        return isRefusal(errno: errno) ? .refused : .missing
    }

    /// What listing a folder finds.
    static func listing(_ path: String) -> (Access, [String]) {
        guard let directory = opendir(path) else {
            return (isRefusal(errno: errno) ? .refused : .missing, [])
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

    static func isRefusal(_ error: any Error) -> Bool {
        let error = error as NSError
        if error.domain == NSCocoaErrorDomain, error.code == NSFileReadNoPermissionError { return true }
        if error.domain == NSPOSIXErrorDomain, error.code == Int(EPERM) || error.code == Int(EACCES) { return true }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError { return isRefusal(underlying) }
        return false
    }

    static func isRefusal(errno code: Int32) -> Bool { code == EPERM || code == EACCES }
}
