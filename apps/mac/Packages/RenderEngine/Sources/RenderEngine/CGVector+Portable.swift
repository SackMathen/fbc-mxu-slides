#if !canImport(CoreGraphics)
import Foundation

/// CoreGraphics' `CGVector` for platforms whose Foundation provides the other
/// geometry types (`CGFloat`, `CGPoint`, `CGSize`, `CGRect`) but not this one.
/// Public so the packages built on RenderEngine (SlideScene) see the same type
/// on every platform.
public struct CGVector: Equatable, Hashable, Sendable {
    public var dx: CGFloat
    public var dy: CGFloat

    public init() {
        dx = 0
        dy = 0
    }

    public init(dx: CGFloat, dy: CGFloat) {
        self.dx = dx
        self.dy = dy
    }

    public init(dx: Double, dy: Double) {
        self.init(dx: CGFloat(dx), dy: CGFloat(dy))
    }

    public init(dx: Int, dy: Int) {
        self.init(dx: CGFloat(dx), dy: CGFloat(dy))
    }

    public static let zero = CGVector()
}

extension CGVector: Codable {
    // Matches CoreGraphics, which encodes a vector as the two-element array [dx, dy].
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let dx = try container.decode(CGFloat.self)
        let dy = try container.decode(CGFloat.self)
        self.init(dx: dx, dy: dy)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(dx)
        try container.encode(dy)
    }
}

extension CGVector: CustomDebugStringConvertible {
    public var debugDescription: String {
        "(\(dx), \(dy))"
    }
}
#endif
