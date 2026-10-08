import Foundation

// Signposts have no equivalent off Apple platforms; these accept the same
// calls and do nothing, so instrumented code stays identical across platforms.

public struct OSSignpostID: Equatable, Hashable, Sendable {
    public let rawValue: UInt64

    public init(_ rawValue: UInt64) { self.rawValue = rawValue }

    public static let exclusive = OSSignpostID(0xEEEE_B0B5)
    public static let invalid = OSSignpostID(0)
    public static let null = OSSignpostID(0)
}

public struct OSSignpostIntervalState: Sendable {
    public let id: OSSignpostID
}

public struct OSSignposter: Sendable {
    public let subsystem: String
    public let category: String

    public init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
    }

    public init() {
        self.init(subsystem: "", category: "")
    }

    public static let disabled = OSSignposter()

    public var isEnabled: Bool { false }

    public func makeSignpostID() -> OSSignpostID {
        OSSignpostID(UInt64.random(in: 1 ... .max))
    }

    public func beginInterval(_ name: StaticString, id: OSSignpostID = .exclusive) -> OSSignpostIntervalState {
        OSSignpostIntervalState(id: id)
    }

    public func beginInterval(
        _ name: StaticString, id: OSSignpostID = .exclusive, _ message: OSLogMessage
    ) -> OSSignpostIntervalState {
        OSSignpostIntervalState(id: id)
    }

    public func endInterval(_ name: StaticString, _ state: OSSignpostIntervalState) {}

    public func endInterval(_ name: StaticString, _ state: OSSignpostIntervalState, _ message: OSLogMessage) {}

    public func emitEvent(_ name: StaticString, id: OSSignpostID = .exclusive) {}

    public func emitEvent(_ name: StaticString, id: OSSignpostID = .exclusive, _ message: OSLogMessage) {}

    public func withIntervalSignpost<T>(
        _ name: StaticString, id: OSSignpostID = .exclusive, around task: () throws -> T
    ) rethrows -> T {
        try task()
    }
}
