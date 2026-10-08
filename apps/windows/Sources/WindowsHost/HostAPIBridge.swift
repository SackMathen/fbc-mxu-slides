import Foundation
import LocalAPI
import PresenterCore
import RenderEngine
import SlideScene

/// Serves the Local API (the same REST/WebSocket contract the Mac app offers)
/// from the Windows host. Library, documents, services and the slide show
/// work; audio, timers, media transport, outputs, MIDI and the scheduler
/// report that they are not available on Windows yet.
@MainActor
public final class HostAPIBridge: LocalAPIBridge {
    private let model: HostModel

    public init(model: HostModel) {
        self.model = model
    }

    nonisolated private static let idCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_."
    )

    nonisolated static func validatedID(_ id: String) throws -> String {
        guard !id.isEmpty, id.count <= 128,
              id.unicodeScalars.allSatisfy(Self.idCharacters.contains),
              !id.contains("..")
        else {
            throw APIError.badRequest("Invalid document id.")
        }
        return id
    }

    nonisolated static func documentKind(_ kind: APIDocumentKind) -> DocumentKind {
        switch kind {
        case .presentations: .presentation
        case .services: .service
        case .themes: .theme
        case .media: .media
        case .audio: .audio
        case .playlists: .playlist
        case .overlays: .overlay
        case .alertPresets: .alertPreset
        case .outputPresets: .outputPreset
        case .streamPresets: .streamRecordPreset
        case .actionCombos: .actionCombo
        case .scheduleTriggers: .scheduleTrigger
        case .confidenceLayouts: .confidenceLayout
        }
    }

    nonisolated static func unavailable(_ feature: String) -> APIError {
        APIError(status: 501, code: "not_available", message: "\(feature) is not available on Windows yet.")
    }

    // MARK: Library

    public func librarySummary() throws -> APILibrarySummary {
        var counts: [String: Int] = [:]
        for kind in APIDocumentKind.allCases {
            counts[kind.rawValue] = model.entries(of: Self.documentKind(kind)).count
        }
        return APILibrarySummary(counts: counts)
    }

    public func libraryEntries(kind: APIDocumentKind) throws -> [APILibraryEntry] {
        model.entries(of: Self.documentKind(kind)).map { entry in
            APILibraryEntry(
                id: entry.id, name: entry.name, kind: kind.rawValue,
                folder: entry.subkind.isEmpty ? nil : entry.subkind,
                updatedAt: entry.updatedAt
            )
        }
    }

    public func documentJSON(kind: APIDocumentKind, id: String) async throws -> Data {
        switch Self.documentKind(kind) {
        case .presentation: try await encode(Presentation.self, id: id)
        case .service: try await encode(Service.self, id: id)
        case .theme: try await encode(Theme.self, id: id)
        case .media: try await encode(MediaItem.self, id: id)
        case .audio: try await encode(AudioItem.self, id: id)
        case .playlist: try await encode(Playlist.self, id: id)
        case .overlay: try await encode(Overlay.self, id: id)
        case .outputPreset: try await encode(OutputPreset.self, id: id)
        case .alertPreset: try await encode(AlertPreset.self, id: id)
        case .streamRecordPreset: try await encode(StreamRecordPreset.self, id: id)
        case .actionCombo: try await encode(ActionCombo.self, id: id)
        case .scheduleTrigger: try await encode(ScheduleTrigger.self, id: id)
        case .confidenceLayout: try await encode(ConfidenceLayout.self, id: id)
        default: throw APIError.notFound("Unknown document kind.")
        }
    }

    private func encode<E: DocumentEntity>(_ type: E.Type, id: String) async throws -> Data {
        let safeID = try Self.validatedID(id)
        await model.client.settled()
        guard let value = try? await model.client.loadValue(type, id: safeID) else {
            throw APIError.notFound("No document with id '\(id)'.")
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    // MARK: Show

    public func showStatus() -> APIShowStatus {
        let state = model.state
        let service = model.currentServiceID.flatMap { model.entry($0) }
        var liveSlide: APIShowStatus.LiveSlide?
        if let info = model.liveInfo() {
            liveSlide = APIShowStatus.LiveSlide(
                presentationId: info.presentationID,
                presentationName: info.presentationName,
                slideId: info.slideID,
                slideIndex: info.occurrence,
                slideName: info.slideName,
                serviceItemId: info.contextID,
                occurrence: info.occurrence,
                stepIndex: info.stepIndex,
                stepCount: info.stepCount,
                text: info.text.isEmpty ? nil : info.text,
                slideCount: info.slideCount
            )
        }
        var mediaLayers: [String: APIShowStatus.LayerContent] = [:]
        for (layer, cue) in state.liveMedia {
            mediaLayers[layer.rawValue] = APIShowStatus.LayerContent(
                mediaId: cue.mediaId, mediaName: model.entry(cue.mediaId)?.name, loops: cue.loops
            )
        }
        return APIShowStatus(
            liveSlide: liveSlide,
            nextSlideText: nil,
            mediaLayers: mediaLayers,
            overlays: state.liveOverlays.map { APIShowStatus.Overlay(id: $0.id, name: $0.name, layer: $0.layer) },
            alert: state.liveAlert.map {
                APIShowStatus.Alert(
                    id: $0.id, message: $0.message, behavior: $0.behavior.rawValue,
                    target: $0.target.rawValue, layer: $0.layer?.rawValue
                )
            },
            currentServiceId: model.currentServiceID,
            service: service.map { APIShowStatus.ServiceRef(id: $0.id, name: $0.name) },
            nextSlide: nil,
            position: nil
        )
    }

    public func timers() -> [APITimerStatus] { [] }

    public func audioStatus() -> APIAudioStatus { APIAudioStatus(buses: []) }

    public func transportRows() -> [APITransportRow] { [] }

    public func outputsStatus() -> APIOutputsStatus { APIOutputsStatus(screens: [], presets: []) }

    public func schedulerStatus() -> APISchedulerStatus {
        APISchedulerStatus(enabled: false, nextFire: nil, triggers: [])
    }

    public func fireSlide(_ command: APIFireSlideCommand) async throws {
        if let serviceItemId = command.serviceItemId {
            guard let service = await service(containingItem: serviceItemId) else {
                throw APIError.notFound("No service contains an item '\(serviceItemId)'.")
            }
            let positions = await model.positions(in: service).filter { $0.itemID == serviceItemId }
            guard !positions.isEmpty else {
                throw APIError.notFound("Service item '\(serviceItemId)' has no firable slides.")
            }
            let index = command.occurrence ?? command.slideIndex ?? 0
            guard positions.indices.contains(index) else {
                throw APIError.badRequest("Occurrence \(index) is out of range (item has \(positions.count) positions).")
            }
            let position = positions[index]
            model.fire(
                slide: position.slide, in: position.presentation, arrangementId: position.arrangementId,
                contextID: position.itemID, occurrence: position.occurrence
            )
            return
        }
        guard let presentationId = command.presentationId,
              let presentation = try? await model.presentation(try Self.validatedID(presentationId))
        else {
            throw APIError.notFound("Provide serviceItemId, or a presentationId that exists.")
        }
        let slides = SlideSceneBuilder.arrangedSlides(for: presentation, arrangementId: command.arrangementId)
        let index: Int
        if let slideId = command.slideId {
            guard let found = slides.firstIndex(where: { $0.id == slideId }) else {
                throw APIError.notFound("No slide '\(slideId)' in that presentation's arranged order.")
            }
            index = found
        } else {
            index = command.slideIndex ?? 0
        }
        guard slides.indices.contains(index) else {
            throw APIError.badRequest("Slide index \(index) is out of range (\(slides.count) slides).")
        }
        model.fire(
            slide: slides[index], in: presentation, arrangementId: command.arrangementId,
            contextID: presentationId, occurrence: index
        )
    }

    private func service(containingItem itemID: String) async -> Service? {
        if let service = await model.currentService(), service.items.contains(where: { $0.id == itemID }) {
            return service
        }
        for entry in model.entries(of: .service) {
            if let service = try? await model.service(entry.id), service.items.contains(where: { $0.id == itemID }) {
                return service
            }
        }
        return nil
    }

    public func advance(steps: Int, settled: Bool) async throws {
        do {
            try await model.advance(steps: steps, settled: settled)
        } catch HostModel.AdvanceError.atEnd {
            throw APIError.badRequest("Already at the end.")
        } catch HostModel.AdvanceError.atStart {
            throw APIError.badRequest("Already at the start.")
        } catch HostModel.AdvanceError.nothingToAdvance {
            throw APIError.badRequest("Nothing is live and the current service has no slides.")
        }
    }

    public func clear(_ command: APIClearCommand) throws {
        if let raw = command.function {
            guard let function = ShowFunction(rawValue: raw) else {
                throw APIError.badRequest(
                    "Unknown function '\(raw)'. Functions: \(ShowFunction.allCases.map(\.rawValue).joined(separator: ", "))."
                )
            }
            model.clear(function: function)
        } else if let raw = command.layer {
            guard let layer = LayerKind(rawValue: raw) else {
                throw APIError.badRequest(
                    "Unknown layer '\(raw)'. Layers: \(LayerKind.allCases.map(\.rawValue).joined(separator: ", "))."
                )
            }
            model.clear(layer: layer)
        } else {
            throw APIError.badRequest("Provide either 'function' or 'layer'.")
        }
    }

    public func clearAll() {
        model.clearAll()
    }

    public func fireMedia(id: String) throws {
        throw Self.unavailable("Media playback")
    }

    public func fireOverlay(id: String) throws {
        throw Self.unavailable("Firing overlays over the Local API")
    }

    public func fireActionCombo(id: String) throws {
        throw Self.unavailable("Action combos")
    }

    public func dismissOverlay(id: String) throws {
        model.dismissOverlay(id: id)
    }

    public func fireAlert(_ command: APIFireAlertCommand) throws {
        guard let message = command.message, !message.isEmpty else {
            throw APIError.badRequest("Provide 'message' (alert presets are not available on Windows yet).")
        }
        let behavior = command.behavior.flatMap(AlertBehavior.init(rawValue:)) ?? .persist
        let target = command.target.flatMap(AlertTarget.init(rawValue:)) ?? .confidence
        model.fireAlert(message: message, behavior: behavior, target: target, themeId: command.themeId)
    }

    public func dismissAlert() {
        model.dismissAlert()
    }

    public func timerAction(id: String, action: APITimerAction) throws {
        throw Self.unavailable("Timers")
    }

    public func fireAudioPlaylist(id: String, startAtEntryId: String?) throws {
        throw Self.unavailable("Audio playback")
    }

    public func fireAudioItem(id: String) throws {
        throw Self.unavailable("Audio playback")
    }

    public func stopAudio(_ command: APIAudioStopCommand) throws {}

    public func audioTransport(_ command: APIAudioTransportCommand) throws {
        throw Self.unavailable("Audio transport")
    }

    public func mediaTransport(id: String, command: APIMediaTransportCommand) throws {
        throw Self.unavailable("Video transport")
    }

    public func activateOutputPreset(id: String?) throws {
        throw Self.unavailable("Output presets")
    }

    public func selectService(id: String) throws {
        guard model.entry(id)?.kind == .service else {
            throw APIError.notFound("No service '\(id)'.")
        }
        model.selectService(id)
    }

    public func setSchedulerEnabled(_ enabled: Bool) {}

    public func setScheduleTriggerEnabled(id: String, enabled: Bool) throws {
        throw Self.unavailable("The scheduler")
    }

    public func fireScheduleTrigger(id: String) throws {
        throw Self.unavailable("The scheduler")
    }

    public func midiDevices() -> [APIMIDIDeviceStatus] { [] }

    public func setMIDIDeviceEnabled(id: String, enabled: Bool) throws {
        throw Self.unavailable("MIDI")
    }

    public func videoInputs() -> [APIVideoInputStatus] { [] }

    public func audioInputs() -> [APIAudioInputStatus] { [] }

    public func audioMixes() -> [APIAudioMixStatus] { [] }

    public func setMixerInput(id: String, command: APIMixerInputCommand) throws {
        throw Self.unavailable("The audio mixer")
    }

    // MARK: Documents

    public func createDocument(kind: APIDocumentKind, body: Data) async throws -> String {
        switch Self.documentKind(kind) {
        case .presentation: try await create(Presentation.self, body: body)
        case .service: try await create(Service.self, body: body)
        case .theme: try await create(Theme.self, body: body)
        case .media: try await create(MediaItem.self, body: body)
        case .audio: try await create(AudioItem.self, body: body)
        case .playlist: try await create(Playlist.self, body: body)
        case .overlay: try await create(Overlay.self, body: body)
        case .outputPreset: try await create(OutputPreset.self, body: body)
        case .alertPreset: try await create(AlertPreset.self, body: body)
        case .streamRecordPreset: try await create(StreamRecordPreset.self, body: body)
        case .actionCombo: try await create(ActionCombo.self, body: body)
        case .scheduleTrigger: try await create(ScheduleTrigger.self, body: body)
        case .confidenceLayout: try await create(ConfidenceLayout.self, body: body)
        default: throw APIError.notFound("Unknown document kind.")
        }
    }

    public func updateDocument(kind: APIDocumentKind, id: String, body: Data) async throws {
        switch Self.documentKind(kind) {
        case .presentation: try await update(Presentation.self, id: id, body: body)
        case .service: try await update(Service.self, id: id, body: body)
        case .theme: try await update(Theme.self, id: id, body: body)
        case .media: try await update(MediaItem.self, id: id, body: body)
        case .audio: try await update(AudioItem.self, id: id, body: body)
        case .playlist: try await update(Playlist.self, id: id, body: body)
        case .overlay: try await update(Overlay.self, id: id, body: body)
        case .outputPreset: try await update(OutputPreset.self, id: id, body: body)
        case .alertPreset: try await update(AlertPreset.self, id: id, body: body)
        case .streamRecordPreset: try await update(StreamRecordPreset.self, id: id, body: body)
        case .actionCombo: try await update(ActionCombo.self, id: id, body: body)
        case .scheduleTrigger: try await update(ScheduleTrigger.self, id: id, body: body)
        case .confidenceLayout: try await update(ConfidenceLayout.self, id: id, body: body)
        default: throw APIError.notFound("Unknown document kind.")
        }
    }

    public func deleteDocument(kind: APIDocumentKind, id: String) async throws {
        let id = try Self.validatedID(id)
        do {
            _ = try await model.client.delete(kind: Self.documentKind(kind), id: id).value
        } catch {
            throw APIError.notFound("No document with id '\(id)'.")
        }
    }

    public func addServiceItem(serviceId: String, refId: String, index: Int?) throws {
        guard model.entry(serviceId)?.kind == .service else {
            throw APIError.notFound("No service '\(serviceId)'.")
        }
        guard let entry = model.entry(refId) else {
            throw APIError.notFound("No library item '\(refId)'.")
        }
        let kind: ServiceItemKind
        switch entry.kind {
        case .presentation: kind = .presentation
        case .media: kind = .media
        case .audio: kind = .audio
        case .playlist: kind = .playlist
        default: throw APIError.badRequest("Only presentations, media, audio and playlists go in a service.")
        }
        let item = ServiceItem(id: UUID().uuidString, itemKind: kind, name: entry.name, refId: refId)
        _ = model.client.modify(Service.self, id: serviceId) { service in
            if let index, service.items.indices.contains(index) {
                service.items.insert(item, at: max(0, index))
            } else {
                service.items.append(item)
            }
        }
    }

    @discardableResult
    private func create<E: DocumentEntity>(_ type: E.Type, body: Data) async throws -> String {
        guard var object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] else {
            throw APIError.badRequest("Body must be a JSON object (the document).")
        }
        if let suppliedID = object["id"] as? String, !suppliedID.isEmpty {
            object["id"] = try Self.validatedID(suppliedID)
        } else {
            object["id"] = UUID().uuidString
        }
        let entity: E
        do {
            let normalized = try JSONSerialization.data(withJSONObject: object)
            entity = try JSONDecoder().decode(E.self, from: normalized)
        } catch {
            throw APIError.badRequest("Not a valid \(String(describing: type)): \(error)")
        }
        do {
            _ = try await model.client.create(entity).value
        } catch {
            throw APIError(status: 409, code: "conflict", message: "\(error)")
        }
        return entity.id
    }

    private func update<E: DocumentEntity>(_ type: E.Type, id: String, body: Data) async throws {
        let id = try Self.validatedID(id)
        await model.client.settled()
        guard (try? await model.client.exists(kind: E.documentKind, id: id)) == true else {
            throw APIError.notFound("No document with id '\(id)'.")
        }
        let entity: E
        do {
            entity = try JSONDecoder().decode(E.self, from: body)
        } catch {
            throw APIError.badRequest("Not a valid \(String(describing: type)): \(error)")
        }
        guard entity.id == id else {
            throw APIError.badRequest("Body id '\(entity.id)' does not match the path id '\(id)'.")
        }
        do {
            let value = entity
            _ = try await model.client.modify(type, id: id) { $0 = value }.value
        } catch {
            throw APIError(status: 500, code: "write_failed", message: "\(error)")
        }
    }
}
