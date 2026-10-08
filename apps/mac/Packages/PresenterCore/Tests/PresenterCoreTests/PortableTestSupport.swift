import Foundation

#if os(Windows)
/// POSIX `usleep` for tests that pace themselves with it; Windows has no such call.
@discardableResult
func usleep(_ microseconds: UInt32) -> Int32 {
    Thread.sleep(forTimeInterval: Double(microseconds) / 1_000_000)
    return 0
}
#endif
