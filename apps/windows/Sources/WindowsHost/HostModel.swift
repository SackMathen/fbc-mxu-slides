import Foundation
import PresenterCore
import RenderEngine
import SlideScene

/// The Windows app's model: the library, the show state, and the pieces of
/// the Mac app's AppModel and ServiceControls that drive presenting. Anything
/// that needs the Mac's media, audio or output engines is left out for now.
@MainActor
public final class HostModel {
    public let client: LibraryClient

    public private(set) var state = ShowState()

    public private(set) var currentServiceID: String?

    public private(set) var liveContextID: String?
    public private(set) var liveOccurrence: Int?

    /// Bumps on every show or library change; the UI polls it.
    public private(set) var changeCount = 0

    private var themes: [String: Theme] = [:]
    private var themesSequence = -1

    private var presentationCache: [String: (value: Presentation, sequence: Int)] = [:]
    private var serviceCache: [String: (value: Service, sequence: Int)] = [:]

    public init(rootURL: URL) {
        client = LibraryClient(rootURL: rootURL)
    }

    public var rootURL: URL { client.rootURL }

    public func start() async throws {
        try await client.start().value
        await refreshThemesIfNeeded()
        if currentServiceID == nil {
            currentServiceID = defaultServiceID()
        }
        noteChange()
    }

    public var version: Int { changeCount &+ client.lastAppliedSequence &* 1_000 }

    private func noteChange() {
        changeCount += 1
    }

    static var hostTime: Double { ProcessInfo.processInfo.systemUptime }

    // MARK: Library

    public func entries(of kind: DocumentKind) -> [LibraryIndex.Entry] {
        client.snapshot.entries(of: kind)
    }

    public func entry(_ id: String) -> LibraryIndex.Entry? {
        client.snapshot.entry(id: id)
    }

    public func theme(_ id: String) -> Theme? {
        id.isEmpty ? nil : themes[id]
    }

    public func refreshThemesIfNeeded() async {
        let sequence = client.lastAppliedSequence
        guard sequence != themesSequence else { return }
        let ids = entries(of: .theme).map(\.id)
        let loaded = (try? await client.loadValues(Theme.self, ids: ids))?.values ?? [:]
        themes = loaded
        themesSequence = sequence
    }

    public func presentation(_ id: String) async throws -> Presentation {
        let sequence = client.lastAppliedSequence
        if let cached = presentationCache[id], cached.sequence == sequence {
            return cached.value
        }
        let value = try await client.loadValue(Presentation.self, id: id)
        presentationCache[id] = (value, sequence)
        return value
    }

    public func service(_ id: String) async throws -> Service {
        let sequence = client.lastAppliedSequence
        if let cached = serviceCache[id], cached.sequence == sequence {
            return cached.value
        }
        let value = try await client.loadValue(Service.self, id: id)
        serviceCache[id] = (value, sequence)
        return value
    }

    public func currentService() async -> Service? {
        guard let id = currentServiceID else { return nil }
        return try? await service(id)
    }

    public func runOfShow(_ service: Service) -> [ServiceItem] {
        ServiceRunOrder.visible(service.items, timeHexId: nil, order: nil)
    }

    public func fireableItems(_ service: Service) -> [ServiceItem] {
        ServiceRunOrder.fireable(service.items, timeHexId: nil, order: nil)
    }

    /// The service the Mac app would open: the next one on or after today,
    /// else the most recent dated one, else any.
    func defaultServiceID() -> String? {
        let services = entries(of: .service)
        let today = HostPaths.todayISO()
        let dated = services.filter { !$0.subkind.isEmpty }
        if let upcoming = dated.filter({ $0.subkind >= today }).min(by: { $0.subkind < $1.subkind }) {
            return upcoming.id
        }
        if let latest = dated.max(by: { $0.subkind < $1.subkind }) {
            return latest.id
        }
        return services.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }.first?.id
    }

    public func selectService(_ id: String) {
        guard id != currentServiceID else { return }
        currentServiceID = id
        noteChange()
    }

    // MARK: Firing

    public func fire(
        slide: Slide, in presentation: Presentation, arrangementId: String? = nil,
        contextID: String? = nil, occurrence: Int? = nil, arrivesSettled: Bool = false
    ) {
        let theme = theme(presentation.themeId(for: slide))
        state.fire(
            slide: slide, presentation: presentation, theme: theme, arrangementId: arrangementId,
            atHostTime: Self.hostTime, arrivesSettled: arrivesSettled
        )
        liveContextID = contextID
        liveOccurrence = occurrence
        noteChange()
    }

    public func fire(mediaItem: MediaItem) {
        let layer = SlideSceneBuilder.layerKind(CueMedia.dropped(for: mediaItem).layer)
        state.fire(
            media: CueMedia(mediaId: mediaItem.id, classification: mediaItem.classification),
            on: layer
        )
        noteChange()
    }

    public func fire(overlay: Overlay) {
        state.fire(overlay: overlay, atHostTime: Self.hostTime)
        noteChange()
    }

    public func dismissOverlay(id: String) {
        state.dismissOverlay(id: id, atHostTime: nil)
        noteChange()
    }

    public func fireAlert(message: String, behavior: AlertBehavior, target: AlertTarget, themeId: String?) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let styling = target != .confidence ? themeId ?? "" : ""
        state.fire(
            alert: CueAlert(message: trimmed, behavior: behavior, target: target, theme: theme(styling)),
            atHostTime: Self.hostTime
        )
        noteChange()
    }

    public func dismissAlert() {
        clear(function: .alerts)
    }

    public struct Position: Sendable {
        public var itemID: String
        public var occurrence: Int
        public var slide: Slide
        public var presentation: Presentation
        public var arrangementId: String?
    }

    /// Every firable slide in the service, in run order.
    public func positions(in service: Service) async -> [Position] {
        var positions: [Position] = []
        for item in runOfShow(service) where item.itemKind == .presentation {
            guard let presentation = try? await presentation(item.refId) else { continue }
            let slides = SlideSceneBuilder.arrangedSlides(for: presentation, arrangementId: item.arrangementId)
            for (index, slide) in slides.enumerated() {
                positions.append(Position(
                    itemID: item.id, occurrence: index, slide: slide,
                    presentation: presentation, arrangementId: item.arrangementId
                ))
            }
        }
        return positions
    }

    public enum AdvanceError: Error, Equatable {
        case atEnd
        case atStart
        case nothingToAdvance
    }

    /// The grid's arrows: reveals a pending animation step first, otherwise
    /// moves to the neighbouring slide in the service (or the deck).
    public func advance(steps: Int, settled: Bool = false) async throws {
        guard steps != 0 else { return }
        if !settled {
            if steps > 0, state.advanceStep(atHostTime: Self.hostTime) {
                noteChange()
                return
            }
            if steps < 0, state.unadvanceStep() {
                noteChange()
                return
            }
        }
        var positions: [Position] = []
        if let service = await currentService() {
            positions = await self.positions(in: service)
        }
        try advanceSlide(steps: steps, positions: positions, settled: settled)
    }

    private func advanceSlide(steps: Int, positions: [Position], settled: Bool) throws {
        if let contextID = liveContextID, let occurrence = liveOccurrence,
           let current = positions.firstIndex(where: { $0.itemID == contextID && $0.occurrence == occurrence }) {
            let next = current + steps
            guard positions.indices.contains(next) else {
                throw steps > 0 ? AdvanceError.atEnd : AdvanceError.atStart
            }
            fire(position: positions[next], settled: settled)
            return
        }
        if let contextID = liveContextID, let occurrence = liveOccurrence,
           let live = state.liveSlide, let presentation = live.presentation {
            let slides = SlideSceneBuilder.arrangedSlides(for: presentation, arrangementId: live.arrangementId)
            let next = occurrence + steps
            guard slides.indices.contains(next) else {
                throw steps > 0 ? AdvanceError.atEnd : AdvanceError.atStart
            }
            fire(
                slide: slides[next], in: presentation, arrangementId: live.arrangementId,
                contextID: contextID, occurrence: next, arrivesSettled: settled
            )
            return
        }
        guard let position = steps > 0 ? positions.first : positions.last else {
            throw AdvanceError.nothingToAdvance
        }
        fire(position: position, settled: settled)
    }

    private func fire(position: Position, settled: Bool) {
        fire(
            slide: position.slide, in: position.presentation, arrangementId: position.arrangementId,
            contextID: position.itemID, occurrence: position.occurrence, arrivesSettled: settled
        )
    }

    // MARK: Clearing

    public func clear(function: ShowFunction) {
        state.clear(function: function, atHostTime: nil)
        if function == .slides, state.liveSlide == nil {
            liveContextID = nil
            liveOccurrence = nil
        }
        noteChange()
    }

    public func clear(layer: LayerKind) {
        state.clear(layer: layer, atHostTime: nil)
        if layer == .slide, state.liveSlide == nil {
            liveContextID = nil
            liveOccurrence = nil
        }
        noteChange()
    }

    public func clearAll() {
        state.clearAll()
        liveContextID = nil
        liveOccurrence = nil
        noteChange()
    }

    // MARK: Scenes

    public func liveScene() -> RenderScene {
        state.scene()
    }

    /// A slide as its thumbnail shows it: every build settled, exits and page
    /// turns stripped (the Mac's "peak look").
    public func scene(for slide: Slide, in presentation: Presentation, arrangementId: String?) -> RenderScene {
        SlideSceneBuilder.peakLook(SlideSceneBuilder.scene(
            for: slide, theme: theme(presentation.themeId(for: slide)),
            presentation: presentation, arrangementId: arrangementId,
            animationContext: .settled
        ))
    }

    public var hostTime: Double { Self.hostTime }

    // MARK: Status

    public struct LiveInfo: Sendable {
        public var presentationID: String
        public var presentationName: String?
        public var slideID: String
        public var slideName: String?
        public var contextID: String?
        public var occurrence: Int?
        public var slideCount: Int?
        public var stepIndex: Int?
        public var stepCount: Int?
        public var text: String
    }

    public func liveInfo() -> LiveInfo? {
        guard let live = state.liveSlide else { return nil }
        let text = ConfidenceSceneBuilder.slideText(for: live.slide, in: live.presentation).body
        var count: Int?
        if let presentation = live.presentation {
            count = SlideSceneBuilder.arrangedSlides(for: presentation, arrangementId: live.arrangementId).count
        }
        return LiveInfo(
            presentationID: live.presentation?.id ?? "",
            presentationName: live.presentation?.name,
            slideID: live.slide.id,
            slideName: live.slide.name.isEmpty ? nil : live.slide.name,
            contextID: liveContextID,
            occurrence: liveOccurrence,
            slideCount: count,
            stepIndex: state.slideAnimationStep?.consumed,
            stepCount: state.slideAnimationStep?.total,
            text: text
        )
    }

    /// The text of the slide that follows the live one, for the confidence
    /// readout. Walks the service when the live slide was fired from it.
    public func nextSlideText() async -> String? {
        guard let contextID = liveContextID, let occurrence = liveOccurrence else { return nil }
        var upcoming: [(slide: Slide, presentation: Presentation?)] = []
        if let service = await currentService(), service.items.contains(where: { $0.id == contextID }) {
            let positions = await positions(in: service)
            if let current = positions.firstIndex(where: { $0.itemID == contextID && $0.occurrence == occurrence }) {
                upcoming = positions[(current + 1)...].map { ($0.slide, $0.presentation) }
            }
        } else if let live = state.liveSlide, let presentation = live.presentation {
            let slides = SlideSceneBuilder.arrangedSlides(for: presentation, arrangementId: live.arrangementId)
            if slides.indices.contains(occurrence + 1) {
                upcoming = slides[(occurrence + 1)...].map { ($0, presentation) }
            }
        }
        guard let next = ConfidenceSceneBuilder.nextSlide(in: upcoming.map(\.slide), skippingBlanks: true) else {
            return nil
        }
        let presentation = upcoming.first { $0.slide.id == next.id }?.presentation
        let text = ConfidenceSceneBuilder.slideText(for: next, in: presentation).body
        return text.isEmpty ? nil : text
    }
}
