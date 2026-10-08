// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PPTXImport",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "PPTXImport", targets: ["PPTXImport"]),
    ],
    dependencies: [
        .package(path: "../PresenterCore"),
        .package(path: "../PortableSupport"),
    ],
    targets: [
        .target(
            name: "PPTXImport",
            dependencies: [
                "PresenterCore",
                .product(name: "PortableCrypto", package: "PortableSupport", condition: .when(platforms: [.windows, .linux])),
            ]
        ),
        .testTarget(name: "PPTXImportTests", dependencies: ["PPTXImport"]),
    ]
)
