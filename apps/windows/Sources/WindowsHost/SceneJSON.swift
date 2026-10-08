import Foundation
import RenderEngine

/// A JSON picture of a `RenderScene` for the browser-side renderer: enough to
/// draw text, shapes, fills and media placeholders faithfully. Animation
/// steps, effects and masks beyond simple clipping are left for the native
/// Windows renderer.
public enum SceneJSON {

    public struct Color: Codable, Equatable, Sendable {
        public var r: Double, g: Double, b: Double, a: Double

        init(_ color: SceneColor) {
            r = color.red
            g = color.green
            b = color.blue
            a = color.alpha
        }
    }

    public struct Rect: Codable, Equatable, Sendable {
        public var x: Double, y: Double, width: Double, height: Double

        init(_ rect: CGRect) {
            x = Double(rect.origin.x)
            y = Double(rect.origin.y)
            width = Double(rect.size.width)
            height = Double(rect.size.height)
        }
    }

    public struct Shadow: Codable, Equatable, Sendable {
        public var color: Color
        public var blurRadius: Double
        public var offsetX: Double
        public var offsetY: Double

        init(_ shadow: TextShadow) {
            color = Color(shadow.color)
            blurRadius = shadow.blurRadius
            offsetX = shadow.offsetX
            offsetY = shadow.offsetY
        }
    }

    public struct GradientStop: Codable, Equatable, Sendable {
        public var color: Color
        public var position: Double
    }

    public struct Fill: Codable, Equatable, Sendable {
        public var type: String
        public var color: Color?
        public var angle: Double?
        public var stops: [GradientStop]?
        public var mediaId: String?
        public var scaleMode: String?

        init(_ fill: SceneFill) {
            switch fill {
            case .none:
                type = "none"
            case .solid(let color):
                type = "solid"
                self.color = Color(color)
            case .linearGradient(let angle, let stops):
                type = "linearGradient"
                self.angle = angle
                self.stops = stops.map { GradientStop(color: Color($0.color), position: $0.position) }
            case .media(let id, let scaleMode, _):
                type = "media"
                mediaId = id
                self.scaleMode = scaleMode.rawValue
            }
        }
    }

    public struct Stroke: Codable, Equatable, Sendable {
        public var color: Color
        public var width: Double
        public var dash: String

        init(_ stroke: SceneStroke) {
            color = Color(stroke.color)
            width = stroke.width
            dash = String(describing: stroke.dash)
        }
    }

    public struct Outline: Codable, Equatable, Sendable {
        public var color: Color
        public var width: Double
    }

    public struct LineOverride: Codable, Equatable, Sendable {
        public var lineIndex: Int
        public var fontName: String?
        public var fontSize: Double?
        public var color: Color?
    }

    public struct StyleRun: Codable, Equatable, Sendable {
        public var line: Int
        public var column: Int
        public var length: Int
        public var fontName: String?
        public var fontSize: Double?
        public var color: Color?
        public var highlightColor: Color?
        public var underline: Bool?
        public var strikethrough: Bool?
        public var hidden: Bool?
    }

    public struct LineFill: Codable, Equatable, Sendable {
        public var fill: Fill
        public var widthMode: String
        public var verticalPadding: Double
        public var horizontalPadding: Double
        public var verticalOffset: Double
        public var horizontalOffset: Double
        public var cornerRadius: Double
    }

    public struct Text: Codable, Equatable, Sendable {
        public var string: String
        public var fontName: String
        public var fontSize: Double
        public var color: Color
        public var alignment: String
        public var verticalAlignment: String
        public var transform: String
        public var tracking: Double
        public var lineHeightMultiple: Double
        public var wordSpacing: Double
        public var paragraphSpacing: Double
        public var autoShrink: Bool
        public var minFontSize: Double
        public var keepLinesWhole: Bool
        public var balancedWrap: Bool
        public var insetTop: Double
        public var insetLeft: Double
        public var insetBottom: Double
        public var insetRight: Double
        public var firstLineIndent: Double
        public var leftIndent: Double
        public var rightIndent: Double
        public var underline: Bool
        public var strikethrough: Bool
        public var shadow: Shadow?
        public var outline: Outline?
        public var fill: Fill?
        public var lineFill: LineFill?
        public var lineOverrides: [LineOverride]
        public var styleRuns: [StyleRun]
        public var tickerSpeed: Double
        public var pathData: String?

        init(_ text: StyledText) {
            string = text.string
            fontName = text.fontName
            fontSize = text.fontSize
            color = Color(text.color)
            alignment = text.alignment.rawValue
            verticalAlignment = text.verticalAlignment.rawValue
            transform = text.transform.rawValue
            tracking = text.tracking
            lineHeightMultiple = text.lineHeightMultiple
            wordSpacing = text.wordSpacing
            paragraphSpacing = text.paragraphSpacing
            autoShrink = text.autoShrink
            minFontSize = text.minFontSize
            keepLinesWhole = text.keepLinesWhole
            balancedWrap = text.balancedWrap
            insetTop = text.insetTop
            insetLeft = text.insetLeft
            insetBottom = text.insetBottom
            insetRight = text.insetRight
            firstLineIndent = text.firstLineIndent
            leftIndent = text.leftIndent
            rightIndent = text.rightIndent
            underline = text.underline
            strikethrough = text.strikethrough
            shadow = text.shadow.map(Shadow.init)
            outline = text.outline.map { Outline(color: Color($0.color), width: $0.width) }
            fill = text.fill.map(Fill.init)
            lineFill = text.lineFill.map { style in
                LineFill(
                    fill: Fill(style.fill), widthMode: String(describing: style.widthMode),
                    verticalPadding: style.verticalPadding, horizontalPadding: style.horizontalPadding,
                    verticalOffset: style.verticalOffset, horizontalOffset: style.horizontalOffset,
                    cornerRadius: style.cornerRadius
                )
            }
            lineOverrides = text.lineOverrides.map {
                LineOverride(lineIndex: $0.lineIndex, fontName: $0.fontName, fontSize: $0.fontSize, color: $0.color.map(Color.init))
            }
            styleRuns = text.styleRuns.map {
                StyleRun(
                    line: $0.line, column: $0.column, length: $0.length,
                    fontName: $0.fontName, fontSize: $0.fontSize,
                    color: $0.color.map(Color.init), highlightColor: $0.highlightColor.map(Color.init),
                    underline: $0.underline, strikethrough: $0.strikethrough, hidden: $0.hidden
                )
            }
            tickerSpeed = text.tickerSpeed
            pathData = text.pathData
        }
    }

    public struct Shape: Codable, Equatable, Sendable {
        public var kind: String
        public var cornerRadius: Double?
        public var path: String?
        public var fill: Fill
        public var fillOpacity: Double
        public var stroke: Stroke?
        public var shadow: Shadow?

        init(_ style: ShapeStyle) {
            switch style.kind {
            case .rectangle:
                kind = "rectangle"
            case .roundedRectangle(let radius):
                kind = "roundedRectangle"
                cornerRadius = radius
            case .ellipse:
                kind = "ellipse"
            case .path(let data):
                kind = "path"
                path = data
            }
            fill = Fill(style.fill)
            fillOpacity = style.fillOpacity
            stroke = style.stroke.map(Stroke.init)
            shadow = style.shadow.map(Shadow.init)
        }
    }

    public struct Content: Codable, Equatable, Sendable {
        public var type: String
        public var color: Color?
        public var text: Text?
        public var shape: Shape?
        public var mediaId: String?
        public var scaleMode: String?

        init(_ content: ItemContent) {
            switch content {
            case .solid(let color):
                type = "solid"
                self.color = Color(color)
            case .text(let text):
                type = "text"
                self.text = Text(text)
            case .shape(let style):
                type = "shape"
                shape = Shape(style)
            case .media(let id, let scaleMode, _):
                type = "media"
                mediaId = id
                self.scaleMode = scaleMode.rawValue
            }
        }
    }

    /// Where an animation has moved an item at the moment the scene was
    /// resolved: the compositor's AnimationMotion, minus the 3D terms the
    /// canvas renderer does not do yet.
    public struct Motion: Codable, Equatable, Sendable {
        public struct Wipe: Codable, Equatable, Sendable {
            public var edge: String
            public var progress: Double
            public var feather: Double
        }

        public struct Clip: Codable, Equatable, Sendable {
            public var minU: Double, maxU: Double, minV: Double, maxV: Double
        }

        public var dx: Double
        public var dy: Double
        public var scale: Double
        public var scaleY: Double?
        public var tilt: Double
        public var swing: Double
        public var skewX: Double
        public var skewY: Double
        public var wipe: Wipe?
        public var clip: Clip?

        init(_ motion: AnimationMotion) {
            dx = Double(motion.translate.dx)
            dy = Double(motion.translate.dy)
            scale = motion.scale
            scaleY = motion.scaleY
            tilt = motion.tilt
            swing = motion.swing
            skewX = motion.skewX
            skewY = motion.skewY
            wipe = motion.wipe.map { Wipe(edge: String(describing: $0.edge), progress: $0.progress, feather: $0.feather) }
            clip = motion.clip.map { Clip(minU: $0.minU, maxU: $0.maxU, minV: $0.minV, maxV: $0.maxV) }
        }
    }

    public struct Item: Codable, Equatable, Sendable {
        public var id: String
        public var frame: Rect
        public var content: Content
        public var rotationDegrees: Double
        public var opacity: Double
        public var blendMode: String
        public var flipHorizontal: Bool
        public var flipVertical: Bool
        public var maskedBy: String?
        public var maskOut: Bool
        public var isMatte: Bool
        public var hasAnimation: Bool
        public var motion: Motion?

        init(_ item: RenderItem, motion: AnimationMotion?) {
            id = item.id
            frame = Rect(item.frame)
            content = Content(item.content)
            rotationDegrees = item.rotationDegrees
            opacity = item.opacity
            blendMode = item.blendMode.rawValue
            flipHorizontal = item.flipHorizontal
            flipVertical = item.flipVertical
            maskedBy = item.maskedBy
            maskOut = item.maskOut
            isMatte = item.matteGroup != nil
            hasAnimation = !item.animationSteps.isEmpty
            self.motion = motion.map(Motion.init)
        }
    }

    public struct Layer: Codable, Equatable, Sendable {
        public var id: String
        public var kind: String
        public var name: String
        public var hidden: Bool
        public var items: [Item]

        init(_ layer: RenderLayer, motions: [String: AnimationMotion]) {
            id = layer.id
            kind = layer.kind.rawValue
            name = layer.name
            hidden = layer.isHidden
            items = layer.items.map { Item($0, motion: motions[$0.id]) }
        }
    }

    public struct Scene: Codable, Equatable, Sendable {
        public var width: Double
        public var height: Double
        public var background: Color
        public var layers: [Layer]

        /// True while something in the scene still moves (an animation in
        /// flight, a ticker, a scroll, media): the page keeps re-fetching.
        public var timeVarying: Bool

        /// The host clock the scene was resolved at, in seconds.
        public var hostTime: Double

        /// Builds the picture of `scene` at `hostTime`: every item's animation
        /// steps are evaluated the way the compositor evaluates them, so a slide
        /// mid-build looks the same here as on the Mac.
        public init(_ scene: RenderScene, hostTime: Double) {
            let resolved = AnimationEvaluator.resolve(scene, hostTime: hostTime)
            width = Double(scene.canvasSize.width)
            height = Double(scene.canvasSize.height)
            background = Color(scene.background)
            layers = resolved.scene.layers.map { Layer($0, motions: resolved.motions) }
            // Moving if a quarter second from now the picture differs: a build
            // or exit in flight, a ticker, a scroll. Settled builds and clicks
            // still to come do not count; the page re-fetches on those anyway.
            if scene.isTimeVarying {
                let soon = AnimationEvaluator.resolve(scene, hostTime: hostTime + 0.25)
                timeVarying = soon != resolved
            } else {
                timeVarying = false
            }
            self.hostTime = hostTime
        }
    }

    /// A scene at rest: every build finished, exits not started. What
    /// thumbnails show.
    public static let settledHostTime = 1e9

    public static func encode(_ scene: RenderScene, hostTime: Double) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(Scene(scene, hostTime: hostTime))
    }
}
