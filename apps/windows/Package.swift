// swift-tools-version: 6.0
import Foundation
import PackageDescription

// The Windows app. It reuses the platform-neutral packages under apps/mac/Packages
// (library, documents, show state, scene builder, Local API) and adds a host
// that serves the user interface and the output renderer.
//
// CWebView2Host is the native window (Win32 + WebView2). It compiles against
// the WebView2 SDK in Vendor/WebView2, fetched by scripts/windows/fetch-webview2.ps1.
let webView2SDK = Context.packageDirectory + "/Vendor/WebView2"

// The icon and version block, compiled by scripts/windows/build-resources.ps1.
// Linked when present so a bare `swift build` still works without rc.exe.
let resourceFile = Context.packageDirectory + "/Resources/build/app.res"
let resourceFlags: [LinkerSetting] = FileManager.default.fileExists(atPath: resourceFile)
    ? [.unsafeFlags(["-Xlinker", resourceFile], .when(platforms: [.windows]))]
    : []

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
            name: "CWebView2Host",
            cxxSettings: [
                .headerSearchPath("../../Vendor/WebView2/include"),
                .define("UNICODE"),
                .define("_UNICODE"),
            ],
            linkerSettings: [
                .unsafeFlags(["-L", webView2SDK + "/x64"], .when(platforms: [.windows])),
                .linkedLibrary("WebView2LoaderStatic", .when(platforms: [.windows])),
                .linkedLibrary("user32", .when(platforms: [.windows])),
                .linkedLibrary("gdi32", .when(platforms: [.windows])),
                .linkedLibrary("ole32", .when(platforms: [.windows])),
                .linkedLibrary("oleaut32", .when(platforms: [.windows])),
                .linkedLibrary("advapi32", .when(platforms: [.windows])),
                .linkedLibrary("shell32", .when(platforms: [.windows])),
                .linkedLibrary("shlwapi", .when(platforms: [.windows])),
                .linkedLibrary("version", .when(platforms: [.windows])),
                .linkedLibrary("dwmapi", .when(platforms: [.windows])),
            ]
        ),
        .target(
            name: "WindowsHost",
            dependencies: [
                .product(name: "PresenterCore", package: "PresenterCore"),
                .product(name: "RenderEngine", package: "RenderEngine"),
                .product(name: "SlideScene", package: "SlideScene"),
                .product(name: "LocalAPI", package: "LocalAPI"),
                .product(name: "FlyingFox", package: "FlyingFox"),
                .product(name: "FlyingSocks", package: "FlyingFox"),
                .target(name: "CWebView2Host", condition: .when(platforms: [.windows])),
            ],
            linkerSettings: [
                .linkedLibrary("crypt32", .when(platforms: [.windows]))
            ]
        ),
        .executableTarget(
            name: "MxUSlidesHost",
            dependencies: ["WindowsHost"],
            linkerSettings: resourceFlags + [
                // A release build is a windowed app (no console); main stays the entry point.
                .unsafeFlags(
                    ["-Xlinker", "/SUBSYSTEM:WINDOWS", "-Xlinker", "/ENTRY:mainCRTStartup"],
                    .when(platforms: [.windows], configuration: .release)
                ),
            ]
        ),
        .testTarget(
            name: "WindowsHostTests",
            dependencies: ["WindowsHost"]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
