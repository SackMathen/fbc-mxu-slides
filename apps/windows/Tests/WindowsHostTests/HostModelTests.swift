import Foundation
import PresenterCore
import RenderEngine
import SlideScene
import Testing

@testable import WindowsHost

@MainActor
@Suite(.serialized) struct HostModelTests {
    private func makeRoot() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mxu-windows-host-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test func demoLibraryPresentsFromTheService() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = HostModel(rootURL: root)
        try await model.start()

        let created = try await DemoLibrary.install(into: model.client)
        #expect(created.contains(DemoLibrary.serviceID))
        #expect(try await DemoLibrary.install(into: model.client).isEmpty, "installing twice adds nothing")
        try await model.start()

        #expect(model.currentServiceID == DemoLibrary.serviceID)
        let service = try #require(await model.currentService())
        #expect(model.runOfShow(service).count == service.items.count)
        let positions = await model.positions(in: service)
        #expect(positions.count > 20, "the welcome deck and four hymns add up to a run of slides")

        try await model.advance(steps: 1)
        let first = try #require(model.liveInfo())
        #expect(first.presentationID == WelcomeDeck.presentationID)
        #expect(first.occurrence == 0)
        #expect(first.contextID == service.items[1].id)

        let scene = model.liveScene()
        let slideItems = scene.layers.first { $0.kind == .slide }?.items ?? []
        #expect(!slideItems.isEmpty, "the live scene carries the slide's objects")
        #expect(slideItems.contains { if case .text = $0.content { true } else { false } })

        let next = try #require(await model.nextSlideText())
        #expect(!next.isEmpty)

        try await model.advance(steps: 1)
        #expect(model.liveInfo()?.occurrence == 1)
        try await model.advance(steps: -1)
        #expect(model.liveInfo()?.occurrence == 0)
        await #expect(throws: HostModel.AdvanceError.atStart) { try await model.advance(steps: -1) }

        model.clear(function: .slides)
        #expect(model.liveInfo() == nil)
        #expect(model.liveContextID == nil)
    }

    @Test func songsRenderThroughTheStarterTheme() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = HostModel(rootURL: root)
        try await model.start()
        try await DemoLibrary.install(into: model.client)
        try await model.start()

        let song = try await model.presentation(DemoLibrary.songs[0].id)
        #expect(song.themeId == DemoLibrary.pack.themeID)
        #expect(model.theme(song.themeId) != nil)
        let slides = SlideSceneBuilder.arrangedSlides(for: song, arrangementId: nil)
        #expect(slides.count >= 8)

        // Lyric imports open on a blank slide, so the first verse is the second slide.
        let listing = UIModels.presentation(song, arrangementId: nil)
        #expect(listing.slides.count == slides.count)
        let firstVerse = try #require(listing.slides.first { $0.label.contains("Amazing grace") })
        #expect(firstVerse.index == 1)

        let scene = model.scene(for: slides[firstVerse.index], in: song, arrangementId: nil)
        let encoded = try SceneJSON.encode(scene, hostTime: SceneJSON.settledHostTime)
        let decoded = try JSONDecoder().decode(SceneJSON.Scene.self, from: encoded)
        #expect(decoded.width == 1920 && decoded.height == 1080)
        let texts = decoded.layers.flatMap(\.items).compactMap(\.content.text)
        #expect(texts.contains { $0.string.contains("Amazing grace") })
    }

    @Test func sceneJSONDescribesShapesAndFills() throws {
        var scene = RenderScene(canvasSize: CGSize(width: 1920, height: 1080))
        scene.addItem(
            RenderItem(
                id: "plate", frame: CGRect(x: 10, y: 20, width: 300, height: 100),
                content: .shape(ShapeStyle(
                    kind: .roundedRectangle(cornerRadius: 12),
                    fill: .linearGradient(angleDegrees: 90, stops: [
                        SceneGradientStop(color: SceneColor(red: 1, green: 0, blue: 0, alpha: 1), position: 0),
                        SceneGradientStop(color: SceneColor(red: 0, green: 0, blue: 1, alpha: 1), position: 1),
                    ]),
                    stroke: SceneStroke(color: .black, width: 2)
                )),
                opacity: 0.5
            ),
            to: .slide
        )
        let decoded = try JSONDecoder().decode(SceneJSON.Scene.self, from: SceneJSON.encode(scene, hostTime: 10))
        let item = try #require(decoded.layers.first { $0.kind == "slide" }?.items.first)
        #expect(item.motion == nil, "a static item carries no motion")
        #expect(!decoded.timeVarying)
        #expect(item.content.type == "shape")
        #expect(item.content.shape?.kind == "roundedRectangle")
        #expect(item.content.shape?.cornerRadius == 12)
        #expect(item.content.shape?.fill.type == "linearGradient")
        #expect(item.content.shape?.fill.stops?.count == 2)
        #expect(item.content.shape?.stroke?.width == 2)
        #expect(item.opacity == 0.5)
        #expect(item.frame.x == 10 && item.frame.height == 100)
    }
}
