// swift-tools-version: 6.0
import PackageDescription

// The Windows app. It reuses the platform-neutral packages under apps/mac/Packages
// (library, documents, show state, scene builder, Local API) and adds a host
// that serves the user interface and the output renderer.
let package = Package(
    name: "MxUSlidesWindows",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "mxu-slides", targets: ["MxUSlidesHost"]),
        .library(name: "WindowsHost", targets: ["WindowsHost"]),
    ],
    dependencies: [
        .package(path: "../mac/Packages/PresenterCore"),
        .package(path: "../mac/Packages/RenderEngine"),
        .package(path: "../mac/Packages/SlideScene"),
        .package(path: "../mac/Packages/LocalAPI"),
        .package(url: "https://github.com/swhitty/FlyingFox.git", from: "0.27.0"),
    ],
    targets: [
        .target(
            name: "WindowsHost",
            dependencies: [
                .product(name: "PresenterCore", package: "PresenterCore"),
                .product(name: "RenderEngine", package: "RenderEngine"),
                .product(name: "SlideScene", package: "SlideScene"),
                .product(name: "LocalAPI", package: "LocalAPI"),
                .product(name: "FlyingFox", package: "FlyingFox"),
                .product(name: "FlyingSocks", package: "FlyingFox"),
            ],
            linkerSettings: [
                .linkedLibrary("crypt32", .when(platforms: [.windows]))
            ]
        ),
        .executableTarget(
            name: "MxUSlidesHost",
            dependencies: ["WindowsHost"]
        ),
        .testTarget(
            name: "WindowsHostTests",
            dependencies: ["WindowsHost"]
        ),
    ]
)
