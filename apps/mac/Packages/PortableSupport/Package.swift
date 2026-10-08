// swift-tools-version: 6.0
import PackageDescription

// PortableSupport fills in the handful of Apple system modules that the
// platform-neutral packages (PresenterCore, SlideScene, LocalAPI, the
// importers) lean on, so they can build on Windows and Linux:
//
// - PortableOS      stands in for `os` (Logger, OSSignposter, OSAllocatedUnfairLock)
// - PortableCrypto  stands in for the SHA256 part of `CryptoKit`
// - CSQLite         stands in for the SDK's `SQLite3` module (vendored amalgamation)
//
// Consumers depend on these only under `.when(platforms: [.windows, .linux])`
// and switch imports with `#if canImport(os)` etc., so the macOS build is
// unchanged.
let package = Package(
    name: "PortableSupport",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "PortableOS", targets: ["PortableOS"]),
        .library(name: "PortableCrypto", targets: ["PortableCrypto"]),
        .library(name: "CSQLite", targets: ["CSQLite"]),
    ],
    targets: [
        .target(name: "PortableOS"),
        .target(name: "PortableCrypto"),
        .target(
            name: "CSQLite",
            cSettings: [
                // The library index uses FTS5 virtual tables; Apple's system
                // SQLite ships with FTS5 enabled, so match it here.
                .define("SQLITE_ENABLE_FTS5"),
                .define("SQLITE_THREADSAFE", to: "1"),
                .define("SQLITE_ENABLE_COLUMN_METADATA"),
                .define("SQLITE_OMIT_DEPRECATED"),
                .define("SQLITE_OMIT_LOAD_EXTENSION"),
                .unsafeFlags(["-w"]),
            ]
        ),
        .testTarget(name: "PortableOSTests", dependencies: ["PortableOS"]),
        .testTarget(name: "PortableCryptoTests", dependencies: ["PortableCrypto"]),
        .testTarget(name: "CSQLiteTests", dependencies: ["CSQLite"]),
    ]
)
