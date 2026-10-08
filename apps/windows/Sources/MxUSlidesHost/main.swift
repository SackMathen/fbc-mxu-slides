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
    var installDemo = false

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
            case "--no-browser": openBrowser = false
            case "--demo": installDemo = true
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
    mxu-slides [--library <path>] [--web <path>] [--port 6981] [--api-port 6980] [--no-api] [--no-browser] [--demo]

      --library    the library folder (default: %LOCALAPPDATA%\\MxU Slides\\Library)
      --web        the folder with index.html (default: found next to the executable or the sources)
      --port       the port the app's own UI listens on, loopback only (default 6981)
      --api-port   the Local API port for remotes (default 6980)
      --no-api     do not start the Local API
      --no-browser do not open the UI window
      --demo       add a starter theme, four hymns and a service if the library is empty
    """

func log(_ message: String) {
    print(message)
    fflush(stdout)
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

    let model = HostModel(rootURL: options.libraryRoot)
    try await model.start()
    if options.installDemo {
        let created = try await DemoLibrary.install(into: model.client)
        if !created.isEmpty {
            log("  demo     added \(created.count) documents")
            try await model.start()
        }
    }

    var apiServer: LocalAPIServer?
    if options.serveAPI {
        let tokens = APITokenStore(fileURL: options.libraryRoot.appendingPathComponent("local-api-tokens.json"))
        let secret = tokens.ensureDefaultKey()
        let info = APIServerInfo(
            name: ProcessInfo.processInfo.hostName,
            product: "MxU Slides",
            apiVersion: OpenAPIDocument.apiVersion,
            schemaVersion: OpenAPIDocument.documentSchemaVersion()
        )
        let bridge = HostAPIBridge(model: model)
        let server = LocalAPIServer(
            configuration: .init(port: options.apiPort, serviceName: info.name, advertise: true, info: info),
            routes: APIRouteTable.build(bridge: bridge),
            tokens: tokens
        )
        apiServer = server
        Task {
            do {
                try await server.run()
            } catch {
                log("  local api failed: \(error)")
            }
        }
        log("  api      http://localhost:\(options.apiPort)/docs")
        if let secret {
            log("  api key  \(secret)  (the default key; Settings on the Mac shows the same one)")
        }
    }

    let ui = try UIServer(model: model, webRoot: webRoot, port: options.uiPort, localAPIPort: options.serveAPI ? Int(options.apiPort) : nil)
    let uiTask = Task {
        try await ui.run()
    }
    try await ui.waitUntilListening()
    log("  ui       \(ui.url)")
    if options.openBrowser {
        if BrowserLauncher.open(url: ui.url) {
            log("  window   opened in Microsoft Edge (app mode)")
        } else {
            log("  window   could not open a browser; open \(ui.url) yourself")
        }
    }
    log("Press Ctrl+C to quit.")
    try await uiTask.value
    await apiServer?.stop()
}

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
