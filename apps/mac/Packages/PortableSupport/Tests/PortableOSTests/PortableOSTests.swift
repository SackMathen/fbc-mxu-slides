import Foundation
import PortableOS
import Testing

@Suite struct UnfairLockTests {
    @Test func withLockReturnsValueAndMutatesState() {
        let lock = OSAllocatedUnfairLock(initialState: 1)
        let seen = lock.withLock { state -> Int in
            state += 41
            return state
        }
        #expect(seen == 42)
        #expect(lock.withLock { $0 } == 42)
    }

    @Test func voidLockVariants() {
        let lock = OSAllocatedUnfairLock()
        let value = lock.withLockUnchecked { () -> (count: Int, flag: Bool) in (3, true) }
        #expect(value.count == 3)
        #expect(value.flag)
        #expect(lock.lockIfAvailable())
        lock.unlock()
    }

    @Test func serializesConcurrentIncrements() async {
        let lock = OSAllocatedUnfairLock(initialState: 0)
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<32 {
                group.addTask {
                    for _ in 0..<1000 {
                        lock.withLock { $0 += 1 }
                    }
                }
            }
        }
        #expect(lock.withLock { $0 } == 32_000)
    }
}

@Suite(.serialized) struct LoggerTests {
    @Test func interpolationAcceptsPrivacyArguments() {
        let captured = OSAllocatedUnfairLock(initialState: [String]())
        PortableLogSink.install { _, subsystem, category, text in
            captured.withLock { $0.append("\(subsystem)/\(category): \(text)") }
        }
        defer { PortableLogSink.resetToStandardError() }

        let log = Logger(subsystem: "com.example", category: "tests")
        let id = "abc"
        let elapsed = Duration.milliseconds(12)
        log.debug("slow open \(id, privacy: .public): \(elapsed.description, privacy: .public) \(42, privacy: .private)")

        #expect(captured.withLock { $0 } == ["com.example/tests: slow open abc: 0.012 seconds 42"])
    }

    @Test func signposterIsInert() {
        let signposter = OSSignposter(subsystem: "com.example", category: "tests")
        let state = signposter.beginInterval("open")
        signposter.endInterval("open", state)
        #expect(!signposter.isEnabled)
    }
}
