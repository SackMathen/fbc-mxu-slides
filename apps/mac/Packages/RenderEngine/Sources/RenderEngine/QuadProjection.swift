import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Projects an item's rectangle through its tilt, swing, keystone and skew
/// into the four screen-space corners the compositor draws. Pure geometry,
/// shared by the Metal compositor and the editor's handle layout.
public enum QuadProjection {

    static func tiltFocalDistance(targetSize: CGSize) -> CGFloat {
        max(targetSize.width, targetSize.height) * 1.5
    }

    /// Top-left, top-right, bottom-left, bottom-right.
    public static func buildQuadCorners(
        contentRect: CGRect, motion: AnimationMotion, sceneScale: CGFloat, targetSize: CGSize
    ) -> [CGPoint] {
        let projector = Projector(contentRect: contentRect, motion: motion, sceneScale: sceneScale, targetSize: targetSize)
        return [
            projector.project(u: 0, v: 0), projector.project(u: 1, v: 0),
            projector.project(u: 0, v: 1), projector.project(u: 1, v: 1),
        ]
    }

    struct Projector {
        let center: CGPoint
        let dx: CGFloat, dy: CGFloat
        let halfW: CGFloat, halfH: CGFloat
        let cosT: CGFloat, sinT: CGFloat
        let cosS: CGFloat, sinS: CGFloat
        let pivotY: CGFloat
        let keyTop: CGFloat, keyBottom: CGFloat
        let shearX: CGFloat, shearY: CGFloat
        let focal: CGFloat

        init(contentRect: CGRect, motion: AnimationMotion, sceneScale: CGFloat, targetSize: CGSize) {
            center = CGPoint(x: contentRect.midX, y: contentRect.midY)
            dx = CGFloat(motion.translate.dx) * sceneScale
            dy = CGFloat(motion.translate.dy) * sceneScale
            let scale = CGFloat(motion.scale)
            let scaleY = CGFloat(motion.scaleY ?? motion.scale)
            halfW = contentRect.width / 2 * scale
            halfH = contentRect.height / 2 * scaleY
            let theta = CGFloat(motion.tilt) * .pi / 180
            cosT = cos(theta); sinT = sin(theta)
            let phi = CGFloat(motion.swing) * .pi / 180
            cosS = cos(phi); sinS = sin(phi)

            pivotY = switch motion.tiltPivot {
            case .top: -halfH
            case .center: 0
            case .bottom: halfH
            }
            keyTop = CGFloat(motion.keystoneTop)
            keyBottom = CGFloat(motion.keystoneBottom)

            shearX = tan(CGFloat(min(max(motion.skewX, -85), 85)) * .pi / 180)
            shearY = tan(CGFloat(min(max(motion.skewY, -85), 85)) * .pi / 180)
            focal = tiltFocalDistance(targetSize: targetSize)
        }

        func project(u: CGFloat, v: CGFloat) -> CGPoint {

            let edgeScale = keyTop + (keyBottom - keyTop) * v
            let kx = (u * 2 - 1) * halfW * edgeScale
            let ky = (v * 2 - 1) * halfH

            let rx = kx - ky * shearX
            let ry = ky + kx * shearY

            let ay = ry - pivotY
            var z = -ay * sinT
            let py = pivotY + ay * cosT

            let px = rx * cosS - z * sinS
            z = rx * sinS + z * cosS
            let depth = max(focal + z, 1)
            let k = focal / depth
            return CGPoint(x: center.x + dx + px * k, y: center.y + dy + py * k)
        }
    }
}
