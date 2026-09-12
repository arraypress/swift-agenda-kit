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
    targets: [
        .target(
            name: "AgendaKit",
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
