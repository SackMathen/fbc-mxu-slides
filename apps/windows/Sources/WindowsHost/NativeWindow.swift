import Foundation
#if canImport(CWebView2Host)
import CWebView2Host
#endif

/// The app's own window: Win32 plus WebView2, run on its own thread so the
/// main thread stays free for the servers and the model.
public enum NativeWindow {

    public enum Outcome: Int32, Sendable {
        case closed = 0
        case runtimeMissing = 1
        case windowFailed = 2
        case browserFailed = 3
        case unavailable = 100
    }

    public static var isAvailable: Bool {
        #if canImport(CWebView2Host)
        return mxu_webview_runtime_available() == 1
        #else
        return false
        #endif
    }

    /// Opens the window on `url` and returns when it closes.
    public static func run(url: String, title: String, userDataFolder: URL, width: Int = 1480, height: Int = 920) async -> Outcome {
        #if canImport(CWebView2Host)
        try? FileManager.default.createDirectory(at: userDataFolder, withIntermediateDirectories: true)
        let folder = userDataFolder.withUnsafeFileSystemRepresentation { $0.map { String(cString: $0) } } ?? userDataFolder.path
        return await withCheckedContinuation { continuation in
            let thread = Thread {
                let code = url.withCString(encodedAs: UTF16.self) { urlPointer in
                    title.withCString(encodedAs: UTF16.self) { titlePointer in
                        folder.withCString(encodedAs: UTF16.self) { folderPointer in
                            mxu_webview_run(urlPointer, titlePointer, folderPointer, Int32(width), Int32(height))
                        }
                    }
                }
                continuation.resume(returning: Outcome(rawValue: code) ?? .browserFailed)
            }
            thread.name = "MxU Slides window"
            thread.stackSize = 4 << 20
            thread.start()
        }
        #else
        return .unavailable
        #endif
    }

    public static func close() {
        #if canImport(CWebView2Host)
        mxu_webview_close()
        #endif
    }
}
