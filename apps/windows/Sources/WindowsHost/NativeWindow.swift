import Foundation
#if canImport(CWebView2Host)
import CWebView2Host
#endif

/// The app's own windows: the main window (Win32 plus WebView2, run on its own
/// thread so the main thread stays free for the servers and the model) and
/// borderless output windows on chosen displays.
public enum NativeWindow {

    public enum Outcome: Int32, Sendable {
        case closed = 0
        case runtimeMissing = 1
        case windowFailed = 2
        case browserFailed = 3
        case unavailable = 100
    }

    /// An attached display, in the host's order (primary first).
    public struct Display: Codable, Sendable, Equatable {
        public var index: Int
        public var name: String
        public var x: Int
        public var y: Int
        public var width: Int
        public var height: Int
        public var isPrimary: Bool
    }

    /// An open output window.
    public struct Output: Codable, Sendable, Equatable {
        public var id: Int
        public var display: Int
    }

    public static var isAvailable: Bool {
        #if canImport(CWebView2Host)
        return mxu_webview_runtime_available() == 1
        #else
        return false
        #endif
    }

    /// True while the main window exists, which output windows need.
    public static var isRunning: Bool {
        #if canImport(CWebView2Host)
        return mxu_webview_is_running() == 1
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

    public static func displays() -> [Display] {
        #if canImport(CWebView2Host)
        let count = Int(mxu_display_count())
        var result: [Display] = []
        for index in 0..<count {
            var name = [UInt16](repeating: 0, count: 128)
            var x: Int32 = 0, y: Int32 = 0, width: Int32 = 0, height: Int32 = 0, primary: Int32 = 0
            let ok = name.withUnsafeMutableBufferPointer { buffer in
                mxu_display_info(Int32(index), buffer.baseAddress, Int32(buffer.count), &x, &y, &width, &height, &primary)
            }
            guard ok == 1 else { continue }
            let text = String(decoding: name.prefix { $0 != 0 }, as: UTF16.self)
            result.append(Display(index: index, name: text, x: Int(x), y: Int(y), width: Int(width), height: Int(height), isPrimary: primary == 1))
        }
        return result
        #else
        return []
        #endif
    }

    /// Opens (or replaces) the output window on a display. Returns its id.
    @discardableResult
    public static func openOutput(url: String, display: Int) -> Int? {
        #if canImport(CWebView2Host)
        let id = url.withCString(encodedAs: UTF16.self) { mxu_output_open($0, Int32(display)) }
        return id >= 0 ? Int(id) : nil
        #else
        return nil
        #endif
    }

    public static func closeOutput(id: Int) {
        #if canImport(CWebView2Host)
        mxu_output_close(Int32(id))
        #endif
    }

    public static func outputs() -> [Output] {
        #if canImport(CWebView2Host)
        var ids = [Int32](repeating: 0, count: 16)
        var displays = [Int32](repeating: 0, count: 16)
        let count = ids.withUnsafeMutableBufferPointer { idBuffer in
            displays.withUnsafeMutableBufferPointer { displayBuffer in
                mxu_output_list(idBuffer.baseAddress, displayBuffer.baseAddress, 16)
            }
        }
        return (0..<min(Int(count), 16)).map { Output(id: Int(ids[$0]), display: Int(displays[$0])) }
        #else
        return []
        #endif
    }
}
