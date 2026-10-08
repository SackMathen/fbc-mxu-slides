import Foundation
import PresenterCore
import SlideScene

/// What the user interface polls and renders. Kept deliberately flat: the
/// page is a view over this, the way the Mac views are over AppModel.
public struct UIState: Codable, Sendable {
    public struct Entry: Codable, Sendable {
        public var id: String
        public var name: String
        public var folder: String?
        public var date: String?
    }

    public struct ServiceItem: Codable, Sendable {
        public var id: String
        public var kind: String
        public var name: String
        public var refId: String
        public var arrangementId: String?
        public var colorHex: String?
        public var hidden: Bool
    }

    public struct Service: Codable, Sendable {
        public var id: String
        public var name: String
        public var date: String
        public var items: [ServiceItem]
    }

    public struct Live: Codable, Sendable {
        public var presentationId: String
        public var presentationName: String?
        public var slideId: String
        public var slideName: String?
        public var contextId: String?
        public var occurrence: Int?
        public var slideCount: Int?
        public var stepIndex: Int?
        public var stepCount: Int?
        public var text: String
    }

    public struct Overlay: Codable, Sendable {
        public var id: String
        public var name: String
        public var layer: String?
    }

    public struct Alert: Codable, Sendable {
        public var id: String
        public var message: String
        public var behavior: String
        public var target: String
    }

    public var version: Int
    public var platform: String
    public var libraryPath: String
    public var localAPIPort: Int?
    /// The default key remotes use; the page is loopback-only, so it may show it.
    public var localAPIKey: String?
    public var service: Service?
    public var services: [Entry]
    public var live: Live?
    public var nextText: String?
    public var mediaLayers: [String: String]
    public var overlays: [Overlay]
    public var alert: Alert?
    public var sections: [String: [Entry]]
    /// True when the app runs in its own window, so output windows can open on displays.
    public var nativeWindow: Bool
    public var displays: [NativeWindow.Display]
    public var outputs: [NativeWindow.Output]
}

public struct UIPresentation: Codable, Sendable {
    public struct Slide: Codable, Sendable {
        public var id: String
        public var index: Int
        public var name: String
        /// The grid caption after the number: the slide's own name, or empty.
        public var label: String
        /// The first non-empty line of lyric text, for tooltips and search.
        public var text: String
        public var sectionId: String?
        public var sectionName: String?
        public var sectionColorHex: String?
        public var hasBackgroundMedia: Bool
    }

    public struct Section: Codable, Sendable {
        public var id: String
        public var name: String
        public var colorHex: String?
    }

    public struct Arrangement: Codable, Sendable {
        public var id: String
        public var name: String
    }

    public var id: String
    public var name: String
    public var kind: String
    public var themeId: String
    public var canvasWidth: Double
    public var canvasHeight: Double
    public var arrangementId: String?
    public var musicKey: String?
    public var slides: [Slide]
    public var sections: [Section]
    public var arrangements: [Arrangement]
}

public enum UIModels {

    public static func presentation(_ presentation: Presentation, arrangementId: String?) -> UIPresentation {
        let canvas = SlideSceneBuilder.canvasSize(for: presentation)
        let slides = SlideSceneBuilder.arrangedSlides(for: presentation, arrangementId: arrangementId)
        let sections = Dictionary((presentation.sections ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return UIPresentation(
            id: presentation.id,
            name: presentation.name,
            kind: presentation.presentationKind.rawValue,
            themeId: presentation.themeId,
            canvasWidth: Double(canvas.width),
            canvasHeight: Double(canvas.height),
            arrangementId: arrangementId,
            musicKey: presentation.displayKey ?? presentation.musicKey,
            slides: slides.enumerated().map { index, slide in
                let section = slide.sectionId.flatMap { sections[$0] }
                // The grid caption, as on the Mac (PresentGridView.labelName): the
                // slide's name when it has one of its own, otherwise just the number.
                let label: String
                switch SlidePreview.rowText(for: slide, backgroundMediaName: nil) {
                case .name: label = slide.name
                case .preview, .number: label = ""
                }
                return UIPresentation.Slide(
                    id: slide.id, index: index, name: slide.name, label: label,
                    text: SlidePreview.line(for: slide),
                    sectionId: slide.sectionId, sectionName: section?.name, sectionColorHex: section?.colorHex,
                    hasBackgroundMedia: !(slide.background?.mediaId ?? "").isEmpty
                )
            },
            sections: (presentation.sections ?? []).map { UIPresentation.Section(id: $0.id, name: $0.name, colorHex: $0.colorHex) },
            arrangements: (presentation.arrangements ?? []).map { UIPresentation.Arrangement(id: $0.id, name: $0.name) }
        )
    }
}
