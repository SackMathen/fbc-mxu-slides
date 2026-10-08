#if canImport(QuartzCore)
import Foundation
import QuartzCore

// `Locked` lives in Locked.swift so the platform-neutral files can use it.

public final class RenderThread: @unchecked Sendable {
    public static let shared = RenderThread()

    private final class LoopBox: @unchecked Sendable {
        var runLoop: RunLoop?
    }

    private let thread: Thread
    private let loopBox = LoopBox()

    private init() {
        let box = loopBox
        let ready = DispatchSemaphore(value: 0)
        let thread = Thread {
            box.runLoop = RunLoop.current

            RunLoop.current.add(NSMachPort(), forMode: .default)
            ready.signal()
            while !Thread.current.isCancelled {
                RunLoop.current.run(mode: .default, before: .distantFuture)
            }
        }
        thread.name = "RenderEngine.RenderThread"
        thread.qualityOfService = .userInteractive
        thread.threadPriority = 1.0
        self.thread = thread
        thread.start()
        ready.wait()
    }

    public var runLoop: RunLoop {
        loopBox.runLoop!
    }

    public var isCurrent: Bool {
        Thread.current === thread
    }

    public func perform(_ work: @escaping @Sendable () -> Void) {
        if isCurrent {
            work()
            return
        }
        guard let runLoop = loopBox.runLoop else { return }
        runLoop.perform(work)
        CFRunLoopWakeUp(runLoop.getCFRunLoop())
    }
}
#endif
