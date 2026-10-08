// swift-tools-version: 6.0
import PackageDescription

// On Apple platforms PresenterCore uses the system `os`, `CryptoKit` and
// `SQLite3` modules. Elsewhere (Windows, Linux) the PortableSupport package
// supplies source-compatible stand-ins; the sources switch with `#if canImport`.
let portablePlatforms: [Platform] = [.windows, .linux]

let package = Package(
    name: "PresenterCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "PresenterCore", targets: ["PresenterCore"]),
        .executable(name: "library-bench", targets: ["library-bench"]),
    ],
    dependencies: [

        .package(path: "../automerge-swift"),
        .package(path: "../PortableSupport"),
    ],
    targets: [
        .target(
            name: "PresenterCore",
            dependencies: [
                .product(name: "Automerge", package: "automerge-swift"),
                .product(name: "PortableOS", package: "PortableSupport", condition: .when(platforms: portablePlatforms)),
                .product(name: "PortableCrypto", package: "PortableSupport", condition: .when(platforms: portablePlatforms)),
                .product(name: "CSQLite", package: "PortableSupport", condition: .when(platforms: portablePlatforms)),
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3", .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS]))
            ]
        ),
        .executableTarget(
            name: "library-bench",
            dependencies: ["PresenterCore"]
        ),
        .testTarget(
            name: "PresenterCoreTests",
            dependencies: [
                "PresenterCore",
                .product(name: "PortableOS", package: "PortableSupport", condition: .when(platforms: portablePlatforms)),
                .product(name: "CSQLite", package: "PortableSupport", condition: .when(platforms: portablePlatforms)),
            ]
        ),
    ]
)
