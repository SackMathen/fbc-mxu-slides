import Foundation

/// A stand-in for `os.OSAllocatedUnfairLock`: a non-recursive mutex that owns
/// a piece of state and hands it out only inside `withLock`. Backed by an
/// `NSLock` because that is what every supported platform has.
public struct OSAllocatedUnfairLock<State>: @unchecked Sendable {
    private final class Storage: @unchecked Sendable {
        let lock = NSLock()
        var state: State

        init(_ state: State) {
            self.state = state
        }
    }

    private let storage: Storage

    public init(initialState: State) {
        storage = Storage(initialState)
    }

    public enum Ownership: Sendable {
        case owner
        case notOwner
    }

    public func withLock<R: Sendable>(_ body: @Sendable (inout State) throws -> R) rethrows -> R {
        storage.lock.lock()
        defer { storage.lock.unlock() }
        return try body(&storage.state)
    }

    public func withLockUnchecked<R>(_ body: (inout State) throws -> R) rethrows -> R {
        storage.lock.lock()
        defer { storage.lock.unlock() }
        return try body(&storage.state)
    }

    public func withLockIfAvailable<R: Sendable>(_ body: @Sendable (inout State) throws -> R) rethrows -> R? {
        guard storage.lock.try() else { return nil }
        defer { storage.lock.unlock() }
        return try body(&storage.state)
    }

    public func withLockIfAvailableUnchecked<R>(_ body: (inout State) throws -> R) rethrows -> R? {
        guard storage.lock.try() else { return nil }
        defer { storage.lock.unlock() }
        return try body(&storage.state)
    }

    public func precondition(_ condition: Ownership) {}
}

extension OSAllocatedUnfairLock where State == Void {
    public init() {
        self.init(initialState: ())
    }

    public func withLock<R: Sendable>(_ body: @Sendable () throws -> R) rethrows -> R {
        try withLockUnchecked { _ in try body() }
    }

    public func withLockUnchecked<R>(_ body: () throws -> R) rethrows -> R {
        try withLockUnchecked { (_: inout Void) in try body() }
    }

    public func withLockIfAvailable<R: Sendable>(_ body: @Sendable () throws -> R) rethrows -> R? {
        try withLockIfAvailableUnchecked { _ in try body() }
    }

    public func withLockIfAvailableUnchecked<R>(_ body: () throws -> R) rethrows -> R? {
        try withLockIfAvailableUnchecked { (_: inout Void) in try body() }
    }

    public func lock() {
        storage.lock.lock()
    }

    public func unlock() {
        storage.lock.unlock()
    }

    public func lockIfAvailable() -> Bool {
        storage.lock.try()
    }
}
