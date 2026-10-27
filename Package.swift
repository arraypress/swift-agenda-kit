// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-agenda-kit",
    // macOS 15 is the floor so the full-access EventKit surface is available
    // unconditionally — no `if #available` fences around the modern APIs.
    platforms: [
        .macOS("15.0")
    ],
    products: [
        .library(name: "AgendaKit", targets: ["AgendaKit"]),
    ],
    dependencies: [
        // Reading the Reminders store from a private copy.
        .package(url: "https://github.com/arraypress/swift-sqlite-reader.git", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "AgendaKit",
            dependencies: [.product(name: "SQLiteReader", package: "swift-sqlite-reader")],
            // SWIFT 5 LANGUAGE MODE, deliberately. `EKEventStore` is not `Sendable` and is
            // legitimately one shared object for the process — EventKit is built that way and
            // this library is single-threaded by design. Swift 6 mode makes that an error
            // rather than a question, and answering it properly means an actor around the
            // store and an async boundary on every call, which is a rewrite rather than a
            // setting. Callers above this can and do use Swift 6.
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "AgendaKitTests",
            dependencies: ["AgendaKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
