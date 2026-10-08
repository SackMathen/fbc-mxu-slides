import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

public enum AnimationImportSupport {

    public static func rigidifyMoves(_ objects: inout [SlideObject], canvas: CGSize) {
        struct Key: Hashable {
            var kind: AnimationKind
            var edge: AnimationEdge
            var durationMilli: Int
        }
        var clusters: [Key: [(object: Int, step: Int)]] = [:]
        for (o, object) in objects.enumerated() {
            for (s, step) in (object.animationSteps ?? []).enumerated()
            where step.animation == .move && (step.ranges?.isEmpty ?? true) {
                guard let edge = step.edge else { continue }
                let key = Key(kind: step.kind, edge: edge, durationMilli: Int((step.durationSeconds * 1000).rounded()))
                clusters[key, default: []].append((o, s))
            }
        }
        for (key, members) in clusters where members.count > 1 {
            var shiftX: CGFloat = 0
            var shiftY: CGFloat = 0
            for (o, _) in members {
                let frame = frame(of: objects[o], canvas: canvas)
                switch key.edge {
                case .left: shiftX = min(shiftX, -frame.maxX)
                case .right: shiftX = max(shiftX, canvas.width - frame.minX)
                case .top: shiftY = min(shiftY, -frame.maxY)
                case .bottom: shiftY = max(shiftY, canvas.height - frame.minY)
                }
            }

            let dx = (Double(shiftX) * 1000).rounded() / 1000
            let dy = (Double(shiftY) * 1000).rounded() / 1000
            for (o, s) in members {
                objects[o].animationSteps?[s].edge = nil
                objects[o].animationSteps?[s].offsetX = dx == 0 ? nil : dx
                objects[o].animationSteps?[s].offsetY = dy == 0 ? nil : dy
            }
        }
    }

    private static func frame(of object: SlideObject, canvas: CGSize) -> CGRect {
        CGRect(
            x: object.x ?? 0, y: object.y ?? 0,
            width: object.width ?? Double(canvas.width), height: object.height ?? Double(canvas.height)
        )
    }
}
