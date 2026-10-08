import Foundation

// A source-compatible stand-in for the parts of Apple's `os` module that the
// portable packages use. Messages go to standard error with the subsystem and
// category as a prefix; privacy annotations are accepted and ignored because
// nothing here is persisted to a system log.

public struct OSLogPrivacy: Sendable {
    public static let `public` = OSLogPrivacy()
    public static let `private` = OSLogPrivacy()
    public static let auto = OSLogPrivacy()
    public static let sensitive = OSLogPrivacy()

    public init() {}
}

public struct OSLogType: Equatable, Hashable, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let debug = OSLogType(rawValue: 0x02)
    public static let info = OSLogType(rawValue: 0x01)
    public static let `default` = OSLogType(rawValue: 0x00)
    public static let error = OSLogType(rawValue: 0x10)
    public static let fault = OSLogType(rawValue: 0x11)

    var label: String {
        switch self {
        case .debug: "debug"
        case .info: "info"
        case .error: "error"
        case .fault: "fault"
        default: "notice"
        }
    }
}

public struct OSLogMessage: ExpressibleByStringInterpolation, Sendable {
    public let text: String

    public init(stringLiteral value: String) {
        text = value
    }

    public init(stringInterpolation: OSLogInterpolation) {
        text = stringInterpolation.text
    }
}

public struct OSLogInterpolation: StringInterpolationProtocol, Sendable {
    public typealias StringLiteralType = String

    var text = ""

    public init(literalCapacity: Int, interpolationCount: Int) {
        text.reserveCapacity(literalCapacity + interpolationCount * 8)
    }

    public mutating func appendLiteral(_ literal: String) {
        text += literal
    }

    public mutating func appendInterpolation(_ value: @autoclosure () -> String, privacy: OSLogPrivacy = .auto) {
        text += value()
    }

    public mutating func appendInterpolation<T: CustomStringConvertible>(
        _ value: @autoclosure () -> T, privacy: OSLogPrivacy = .auto
    ) {
        text += value().description
    }

    public mutating func appendInterpolation<T>(_ value: @autoclosure () -> T, privacy: OSLogPrivacy = .auto) {
        text += String(describing: value())
    }
}

public struct Logger: Sendable {
    public let subsystem: String
    public let category: String

    public init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
    }

    public init() {
        self.init(subsystem: "", category: "")
    }

    public func log(_ message: OSLogMessage) { emit(.default, message) }
    public func log(level: OSLogType, _ message: OSLogMessage) { emit(level, message) }
    public func debug(_ message: OSLogMessage) { emit(.debug, message) }
    public func trace(_ message: OSLogMessage) { emit(.debug, message) }
    public func info(_ message: OSLogMessage) { emit(.info, message) }
    public func notice(_ message: OSLogMessage) { emit(.default, message) }
    public func warning(_ message: OSLogMessage) { emit(.error, message) }
    public func error(_ message: OSLogMessage) { emit(.error, message) }
    public func critical(_ message: OSLogMessage) { emit(.fault, message) }
    public func fault(_ message: OSLogMessage) { emit(.fault, message) }

    private func emit(_ level: OSLogType, _ message: OSLogMessage) {
        PortableLogSink.write(
            level: level, subsystem: subsystem, category: category, text: message.text)
    }
}

/// Where `Logger` output goes. Standard error by default; tests and the app
/// can install their own handler.
public enum PortableLogSink {
    public typealias Handler = @Sendable (_ level: OSLogType, _ subsystem: String, _ category: String, _ text: String) -> Void

    nonisolated(unsafe) private static var handler: Handler = standardError
    private static let lock = NSLock()

    public static func install(_ handler: @escaping Handler) {
        lock.lock()
        defer { lock.unlock() }
        self.handler = handler
    }

    public static func resetToStandardError() {
        install(standardError)
    }

    static func write(level: OSLogType, subsystem: String, category: String, text: String) {
        let handler = { lock.lock(); defer { lock.unlock() }; return self.handler }()
        handler(level, subsystem, category, text)
    }

    private static let standardError: Handler = { level, subsystem, category, text in
        let scope = [subsystem, category].filter { !$0.isEmpty }.joined(separator: ":")
        let line = "[\(level.label)]\(scope.isEmpty ? "" : " [\(scope)]") \(text)\n"
        FileHandle.standardError.write(Data(line.utf8))
    }
}
