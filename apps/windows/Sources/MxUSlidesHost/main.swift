import Foundation
import LocalAPI
import WindowsHost

// mxu-slides: the Windows host.
//
//   mxu-slides [--library <path>] [--web <path>] [--port 6981] [--api-port 6980]
//              [--no-api] [--no-browser] [--demo]

struct Options {
    var libraryRoot = HostPaths.defaultLibraryRoot()
    var webRoot: URL? = HostPaths.defaultWebRoot()
    var uiPort: UInt16 = 6981
    var apiPort: UInt16 = 6980
    var serveAPI = true
    var openBrowser = true
    var nativeWindow = true
    var installDemo = false
    var verbose = false

    init(arguments: [String]) throws {
        var iterator = arguments.dropFirst().makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--library":
                guard let value = iterator.next() else { throw UsageError("--library needs a path") }
                libraryRoot = URL(fileURLWithPath: value, isDirectory: true)
            case "--web":
                guard let value = iterator.next() else { throw UsageError("--web needs a path") }
                webRoot = URL(fileURLWithPath: value, isDirectory: true)
            case "--port":
                guard let value = iterator.next(), let port = UInt16(value) else { throw UsageError("--port needs a number") }
                uiPort = port
            case "--api-port":
                guard let value = iterator.next(), let port = UInt16(value) else { throw UsageError("--api-port needs a number") }
                apiPort = port
            case "--no-api": serveAPI = false
            case "--no-browser": openBrowser = false; nativeWindow = false
            case "--browser": nativeWindow = false
            case "--demo": installDemo = true
            case "--verbose": verbose = true
            case "--help", "-h":
                throw UsageError(nil)
            default:
                throw UsageError("unknown argument \(argument)")
            }
        }
    }
}

struct UsageError: Error {
    var message: String?
    init(_ message: String?) { self.message = message }
}

let usage = """
    mxu-slides [--library <path>] [--web <path>] [--port 6981] [--api-port 6980]
               [--no-api] [--browser] [--no-browser] [--demo] [--verbose]

      --library    the library folder (default: %LOCALAPPDATA%\\MxU Slides\\Library)
      --web        the folder with index.html (default: found next to the executable or the sources)
      --port       the port the app's own UI listens on, loopback only (default 6981)
      --api-port   the Local API port for remotes (default 6980)
      --no-api     do not start the Local API
      --browser    open the UI in Microsoft Edge (app mode) instead of the app's own window
      --no-browser do not open any window; just serve
      --demo       add four public-domain hymns and a sample service if missing
                   (the starter themes and the Getting Started service come on their own)
      --verbose    log every HTTP connection and request
    """

/// Where log lines go besides stdout: a file, because the packaged app has no
/// console (%LOCALAPPDATA%\MxU Slides\logs\mxu-slides.log).
nonisolated(unsafe) var logFile: FileHandle?

func openLogFile() {
    guard let local = ProcessInfo.processInfo.environment["LOCALAPPDATA"], !local.isEmpty else { return }
    let folder = URL(fileURLWithPath: local, isDirectory: true)
        .appendingPathComponent("MxU Slides", isDirectory: true)
        .appendingPathComponent("logs", isDirectory: true)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let file = folder.appendingPathComponent("mxu-slides.log")
    if !FileManager.default.fileExists(atPath: file.path) {
        FileManager.default.createFile(atPath: file.path, contents: nil)
    }
    logFile = try? FileHandle(forWritingTo: file)
    logFile?.seekToEndOfFile()
}

func log(_ message: String) {
    print(message)
    fflush(stdout)
    if let logFile {
        let stamp = ISO8601DateFormatter().string(from: Date())
        logFile.write(Data("\(stamp) \(message)\n".utf8))
    }
}

/// Set once the window closes, so the servers' stop errors are not reported as failures.
@MainActor
final class HostLifecycle {
    var isShuttingDown = false
}

@MainActor
func runHost(_ options: Options) async throws {
    try FileManager.default.createDirectory(at: options.libraryRoot, withIntermediateDirectories: true)
    guard let webRoot = options.webRoot else {
        throw UsageError("the web folder (index.html) was not found; pass --web <path>")
    }

    log("MxU Slides for Windows")
    log("  library  \(options.libraryRoot.path)")
    log("  web      \(webRoot.path)")
    let lifecycle = HostLifecycle()

    let model = HostModel(rootURL: options.libraryRoot)
    try await model.start()
    // As on the Mac: starter themes and overlays, and the Getting Started service on the first run.
    var seeded = try await StarterContent.install(into: model.client, rootURL: options.libraryRoot)
    if options.installDemo {
        seeded += try await DemoLibrary.install(into: model.client)
    }
    if !seeded.isEmpty {
        log("  library  added \(seeded.count) starter documents")
        try await model.start()
    }

    var apiServer: LocalAPIServer?
    var apiKey: String?
    if options.serveAPI {
        let tokens = APITokenStore(
            fileURL: options.libraryRoot.appendingPathComponent("local-api-tokens.json"),
            vault: WindowsKeyVault.vault(fileURL: options.libraryRoot.appendingPathComponent("local-api-default-key.bin"))
        )
        let secret = tokens.ensureDefaultKey(evenIfPopulated: tokens.defaultKeySecret == nil)
        apiKey = secret ?? tokens.defaultKeySecret
        let info = APIServerInfo(
            name: ProcessInfo.processInfo.hostName,
            product: "MxU Slides",
            apiVersion: OpenAPIDocument.apiVersion,
            schemaVersion: OpenAPIDocument.documentSchemaVersion()
        )
        let bridge = HostAPIBridge(model: model)
        let server = LocalAPIServer(
            configuration: .init(port: options.apiPort, serviceName: info.name, advertise: true, info: info, quietLogging: !options.verbose),
            routes: APIRouteTable.build(bridge: bridge),
            tokens: tokens
        )
        apiServer = server
        Task {
            do {
                try await server.run()
            } catch {
                if !lifecycle.isShuttingDown {
                    log("  local api failed: \(error)")
                }
            }
        }
        log("  api      http://localhost:\(options.apiPort)/docs")
        if let secret {
            log("  api key  \(secret)  (the default key for remotes; sealed with DPAPI in the library folder)")
        }
    }

    let ui = try UIServer(
        model: model, webRoot: webRoot, port: options.uiPort,
        localAPIPort: options.serveAPI ? Int(options.apiPort) : nil,
        localAPIKey: apiKey,
        verbose: options.verbose
    )
    let uiTask = Task {
        try await ui.run()
    }
    try await ui.waitUntilListening()
    log("  ui       \(ui.url)")

    var windowTask: Task<NativeWindow.Outcome, Never>?
    if options.nativeWindow, NativeWindow.isAvailable {
        let userData = options.libraryRoot.deletingLastPathComponent().appendingPathComponent("WebView2", isDirectory: true)
        let url = ui.url
        windowTask = Task {
            await NativeWindow.run(url: url, title: "MxU Slides", userDataFolder: userData)
        }
        log("  window   MxU Slides (WebView2)")
    } else if options.openBrowser {
        if options.nativeWindow {
            log("  window   the WebView2 runtime is not installed; falling back to Microsoft Edge")
        }
        if BrowserLauncher.open(url: ui.url) {
            log("  window   opened in Microsoft Edge (app mode)")
        } else {
            log("  window   could not open a browser; open \(ui.url) yourself")
        }
    }
    log("Press Ctrl+C to quit.")

    if let windowTask {
        let outcome = await windowTask.value
        switch outcome {
        case .closed:
            log("Window closed.")
        case .runtimeMissing, .browserFailed, .windowFailed, .unavailable:
            log("  window   could not open the app window (\(outcome)); the UI is still at \(ui.url)")
            if options.openBrowser { _ = BrowserLauncher.open(url: ui.url) }
            try await uiTask.value
        }
        lifecycle.isShuttingDown = true
        await ui.stop()
        await apiServer?.stop()
        uiTask.cancel()
        _ = try? await uiTask.value
    } else {
        try await uiTask.value
        await apiServer?.stop()
    }
}

openLogFile()
do {
    let options = try Options(arguments: CommandLine.arguments)
    try await runHost(options)
} catch let error as UsageError {
    if let message = error.message {
        log("mxu-slides: \(message)")
    }
    log(usage)
    exit(error.message == nil ? 0 : 2)
} catch {
    log("mxu-slides: \(error)")
    exit(1)
}
