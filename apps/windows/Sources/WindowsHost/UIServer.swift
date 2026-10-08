import FlyingFox
import FlyingSocks
import Foundation
import LocalAPI
import PresenterCore
import RenderEngine
import SlideScene
#if canImport(WinSDK)
import WinSDK
#elseif canImport(Glibc)
import Glibc
#endif

/// Serves the app's own user interface on the loopback interface: the static
/// page, a state document the page polls, scene JSON for thumbnails, the live
/// output and the output window, and the commands the page sends.
public final class UIServer: @unchecked Sendable {
    public let port: UInt16
    public let webRoot: URL
    private let model: HostModel
    private let localAPIPort: Int?
    private let server: HTTPServer

    /// `verbose` keeps the HTTP library's per-request log lines.
    public init(model: HostModel, webRoot: URL, port: UInt16, localAPIPort: Int?, verbose: Bool = false) throws {
        self.model = model
        self.webRoot = webRoot
        self.port = port
        self.localAPIPort = localAPIPort
        // IPv4 loopback only: the page, the output window and the launcher all use 127.0.0.1.
        self.server = HTTPServer(
            address: try sockaddr_in.inet(ip4: "127.0.0.1", port: port),
            logger: verbose ? HTTPServer.defaultLogger(category: "ui") : LocalAPIServer.SilentHTTPLogger()
        )
    }

    public var url: String { "http://127.0.0.1:\(port)/" }

    public func run() async throws {
        await registerRoutes()
        try await server.run()
    }

    public func waitUntilListening() async throws {
        try await server.waitUntilListening()
    }

    public func stop() async {
        await server.stop(timeout: 1)
    }

    private func registerRoutes() async {
        let webRoot = webRoot
        await server.appendRoute("GET /static/*", to: DirectoryHTTPHandler(root: webRoot, serverPath: "/static"))
        await server.appendRoute(HTTPRoute("GET /")) { _ in
            Self.page(webRoot.appendingPathComponent("index.html"))
        }
        await server.appendRoute(HTTPRoute("GET /output")) { _ in
            Self.page(webRoot.appendingPathComponent("output.html"))
        }
        await server.appendRoute(HTTPRoute("/ui/*")) { [weak self] request in
            guard let self else { return HTTPResponse(statusCode: .serviceUnavailable) }
            return await self.handle(request)
        }
    }

    private static func page(_ url: URL) -> HTTPResponse {
        guard let data = try? Data(contentsOf: url) else {
            return HTTPResponse(statusCode: .notFound, body: Data("Missing \(url.lastPathComponent)".utf8))
        }
        return HTTPResponse(
            statusCode: .ok,
            headers: [HTTPHeader("Content-Type"): "text/html; charset=utf-8", HTTPHeader("Cache-Control"): "no-store"],
            body: data
        )
    }

    // MARK: Routing

    private func handle(_ request: HTTPRequest) async -> HTTPResponse {
        let parts = request.path.split(separator: "/").map(String.init)
        guard parts.count >= 3, parts[0] == "ui", parts[1] == "v1" else {
            return Self.json(["error": "No such endpoint."], status: .notFound)
        }
        let route = Array(parts.dropFirst(2))
        let method = request.method.rawValue.uppercased()
        do {
            switch (method, route.first ?? "") {
            case ("GET", "state"):
                return Self.json(try await state())
            case ("GET", "presentations"):
                guard route.count >= 2 else { return Self.json(["error": "Missing id."], status: .badRequest) }
                return Self.json(try await presentation(id: route[1], arrangementId: request.query["arrangement"]))
            case ("GET", "scene"):
                return try await scene(route: route, request: request)
            case ("GET", "media"):
                guard route.count >= 2 else { return Self.json(["error": "Missing id."], status: .badRequest) }
                return try await mediaFile(id: route[1])
            case ("POST", "fire"):
                let command = try await decode(FireCommand.self, from: request)
                try await fire(command)
                return Self.ok()
            case ("POST", "advance"):
                let command = try await decode(AdvanceCommand.self, from: request)
                try await model.advance(steps: command.steps ?? 1, settled: command.settled ?? false)
                return Self.ok()
            case ("POST", "clear"):
                let command = try await decode(ClearCommand.self, from: request)
                try await clear(command)
                return Self.ok()
            case ("POST", "service"):
                let command = try await decode(SelectServiceCommand.self, from: request)
                await model.selectService(command.id)
                return Self.ok()
            case ("POST", "overlay"):
                let command = try await decode(OverlayCommand.self, from: request)
                try await overlay(command)
                return Self.ok()
            case ("POST", "alert"):
                let command = try await decode(AlertCommand.self, from: request)
                await alert(command)
                return Self.ok()
            default:
                return Self.json(["error": "No such endpoint."], status: .notFound)
            }
        } catch let error as HostModel.AdvanceError {
            let message = switch error {
            case .atEnd: "Already at the end."
            case .atStart: "Already at the start."
            case .nothingToAdvance: "Nothing is live and the current service has no slides."
            }
            return Self.json(["error": message], status: .conflict)
        } catch let error as RequestError {
            return Self.json(["error": error.message], status: error.status)
        } catch {
            return Self.json(["error": "\(error)"], status: .internalServerError)
        }
    }

    struct RequestError: Error {
        var status: HTTPStatusCode
        var message: String

        static func badRequest(_ message: String) -> RequestError { RequestError(status: .badRequest, message: message) }
        static func notFound(_ message: String) -> RequestError { RequestError(status: .notFound, message: message) }
    }

    struct FireCommand: Decodable {
        var presentationId: String
        var index: Int
        var contextId: String?
        var arrangementId: String?
    }

    struct AdvanceCommand: Decodable {
        var steps: Int?
        var settled: Bool?
    }

    struct ClearCommand: Decodable {
        var function: String?
        var layer: String?
        var all: Bool?
    }

    struct SelectServiceCommand: Decodable {
        var id: String
    }

    struct OverlayCommand: Decodable {
        var id: String
        var action: String
    }

    struct AlertCommand: Decodable {
        var message: String?
        var behavior: String?
        var target: String?
        var dismiss: Bool?
    }

    private func decode<T: Decodable>(_ type: T.Type, from request: HTTPRequest) async throws -> T {
        let data = try await request.bodyData
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw RequestError.badRequest("Bad request body: \(error)")
        }
    }

    // MARK: Handlers

    private func state() async throws -> UIState {
        await model.refreshThemesIfNeeded()
        let sections: [(key: String, kind: DocumentKind)] = [
            ("services", .service), ("presentations", .presentation), ("overlays", .overlay),
            ("media", .media), ("audio", .audio), ("themes", .theme), ("confidence", .confidenceLayout),
            ("playlists", .playlist),
        ]
        var listed: [String: [UIState.Entry]] = [:]
        for section in sections {
            listed[section.key] = await model.entries(of: section.kind)
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                .map { UIState.Entry(id: $0.id, name: $0.name, folder: $0.subkind.isEmpty ? nil : $0.subkind, date: nil) }
        }
        let serviceEntries = await model.entries(of: .service).map {
            UIState.Entry(id: $0.id, name: $0.name, folder: nil, date: $0.subkind.isEmpty ? nil : $0.subkind)
        }
        var current: UIState.Service?
        if let service = await model.currentService() {
            let items = await model.runOfShow(service)
            current = UIState.Service(
                id: service.id, name: service.name, date: service.serviceDate,
                items: items.map {
                    UIState.ServiceItem(
                        id: $0.id, kind: $0.itemKind.rawValue, name: $0.name, refId: $0.refId,
                        arrangementId: $0.arrangementId, colorHex: $0.colorHex, hidden: $0.isHidden
                    )
                }
            )
        }
        let live = await model.liveInfo().map {
            UIState.Live(
                presentationId: $0.presentationID, presentationName: $0.presentationName,
                slideId: $0.slideID, slideName: $0.slideName, contextId: $0.contextID,
                occurrence: $0.occurrence, slideCount: $0.slideCount,
                stepIndex: $0.stepIndex, stepCount: $0.stepCount, text: $0.text
            )
        }
        let showState = await model.state
        var mediaLayers: [String: String] = [:]
        for (layer, cue) in showState.liveMedia {
            mediaLayers[layer.rawValue] = await model.entry(cue.mediaId)?.name ?? cue.mediaId
        }
        return UIState(
            version: await model.version,
            platform: BuildIdentityPlatform.name,
            libraryPath: await model.rootURL.path,
            localAPIPort: localAPIPort,
            service: current,
            services: serviceEntries,
            live: live,
            nextText: await model.nextSlideText(),
            mediaLayers: mediaLayers,
            overlays: showState.liveOverlays.map { UIState.Overlay(id: $0.id, name: $0.name, layer: $0.layer) },
            alert: showState.liveAlert.map {
                UIState.Alert(id: $0.id, message: $0.message, behavior: $0.behavior.rawValue, target: $0.target.rawValue)
            },
            sections: listed
        )
    }

    private func presentation(id: String, arrangementId: String?) async throws -> UIPresentation {
        guard let presentation = try? await model.presentation(id) else {
            throw RequestError.notFound("No presentation '\(id)'.")
        }
        let arrangement = (arrangementId?.isEmpty ?? true) ? nil : arrangementId
        return await UIModels.presentation(presentation, arrangementId: arrangement)
    }

    private func scene(route: [String], request: HTTPRequest) async throws -> HTTPResponse {
        guard route.count >= 2 else { throw RequestError.badRequest("Which scene?") }
        switch route[1] {
        case "live":
            let scene = await model.liveScene()
            let now = await model.hostTime
            return HTTPResponse(
                statusCode: .ok,
                headers: [HTTPHeader("Content-Type"): "application/json", HTTPHeader("Cache-Control"): "no-store"],
                body: try SceneJSON.encode(scene, hostTime: now)
            )
        case "slide":
            guard route.count >= 4, let index = Int(route[3]) else {
                throw RequestError.badRequest("Use /ui/v1/scene/slide/{presentationId}/{index}.")
            }
            guard let presentation = try? await model.presentation(route[2]) else {
                throw RequestError.notFound("No presentation '\(route[2])'.")
            }
            let arrangement = request.query["arrangement"].flatMap { $0.isEmpty ? nil : $0 }
            let slides = SlideSceneBuilder.arrangedSlides(for: presentation, arrangementId: arrangement)
            guard slides.indices.contains(index) else {
                throw RequestError.notFound("Slide \(index) is out of range (\(slides.count) slides).")
            }
            let scene = await model.scene(for: slides[index], in: presentation, arrangementId: arrangement)
            return HTTPResponse(
                statusCode: .ok,
                headers: [HTTPHeader("Content-Type"): "application/json", HTTPHeader("Cache-Control"): "no-store"],
                body: try SceneJSON.encode(scene, hostTime: SceneJSON.settledHostTime)
            )
        default:
            throw RequestError.notFound("No such scene.")
        }
    }

    private func mediaFile(id: String) async throws -> HTTPResponse {
        let safeID = try? HostAPIBridge.validatedID(id)
        guard let safeID, let item = try? await model.client.loadValue(MediaItem.self, id: safeID) else {
            throw RequestError.notFound("No media item '\(id)'.")
        }
        let blobs = try BlobStore(libraryRoot: await model.rootURL)
        guard let url = blobs.url(forHash: item.fileHash), let data = try? Data(contentsOf: url) else {
            throw RequestError.notFound("The file for '\(item.name)' is not in this library.")
        }
        let type: String
        switch url.pathExtension.lowercased() {
        case "png": type = "image/png"
        case "jpg", "jpeg": type = "image/jpeg"
        case "gif": type = "image/gif"
        case "webp": type = "image/webp"
        case "bmp": type = "image/bmp"
        case "mp4", "m4v": type = "video/mp4"
        case "mov": type = "video/quicktime"
        case "webm": type = "video/webm"
        default: type = "application/octet-stream"
        }
        return HTTPResponse(
            statusCode: .ok,
            headers: [HTTPHeader("Content-Type"): type, HTTPHeader("Cache-Control"): "private, max-age=3600"],
            body: data
        )
    }

    private func fire(_ command: FireCommand) async throws {
        guard let presentation = try? await model.presentation(command.presentationId) else {
            throw RequestError.notFound("No presentation '\(command.presentationId)'.")
        }
        let arrangement = (command.arrangementId?.isEmpty ?? true) ? nil : command.arrangementId
        let slides = SlideSceneBuilder.arrangedSlides(for: presentation, arrangementId: arrangement)
        guard slides.indices.contains(command.index) else {
            throw RequestError.badRequest("Slide \(command.index) is out of range (\(slides.count) slides).")
        }
        await model.fire(
            slide: slides[command.index], in: presentation, arrangementId: arrangement,
            contextID: command.contextId ?? command.presentationId, occurrence: command.index
        )
    }

    private func clear(_ command: ClearCommand) async throws {
        if command.all == true {
            await model.clearAll()
        } else if let raw = command.function {
            guard let function = ShowFunction(rawValue: raw) else {
                throw RequestError.badRequest("Unknown function '\(raw)'.")
            }
            await model.clear(function: function)
        } else if let raw = command.layer {
            guard let layer = LayerKind(rawValue: raw) else {
                throw RequestError.badRequest("Unknown layer '\(raw)'.")
            }
            await model.clear(layer: layer)
        } else {
            throw RequestError.badRequest("Provide 'all', 'function' or 'layer'.")
        }
    }

    private func overlay(_ command: OverlayCommand) async throws {
        switch command.action {
        case "fire":
            guard let overlay = try? await model.client.loadValue(Overlay.self, id: command.id) else {
                throw RequestError.notFound("No overlay '\(command.id)'.")
            }
            await model.fire(overlay: overlay)
        case "dismiss":
            await model.dismissOverlay(id: command.id)
        default:
            throw RequestError.badRequest("Overlay action must be 'fire' or 'dismiss'.")
        }
    }

    private func alert(_ command: AlertCommand) async {
        if command.dismiss == true {
            await model.dismissAlert()
            return
        }
        let behavior = command.behavior.flatMap(AlertBehavior.init(rawValue:)) ?? .persist
        let target = command.target.flatMap(AlertTarget.init(rawValue:)) ?? .audience
        await model.fireAlert(message: command.message ?? "", behavior: behavior, target: target, themeId: nil)
    }

    // MARK: Responses

    private static func json(_ value: some Encodable, status: HTTPStatusCode = .ok) -> HTTPResponse {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let body = (try? encoder.encode(value)) ?? Data("{}".utf8)
        return HTTPResponse(
            statusCode: status,
            headers: [HTTPHeader("Content-Type"): "application/json", HTTPHeader("Cache-Control"): "no-store"],
            body: body
        )
    }

    private static func ok() -> HTTPResponse {
        json(["ok": true])
    }
}

enum BuildIdentityPlatform {
    static var name: String {
        #if os(Windows)
        "Windows"
        #elseif os(macOS)
        "macOS"
        #else
        "Linux"
        #endif
    }
}
