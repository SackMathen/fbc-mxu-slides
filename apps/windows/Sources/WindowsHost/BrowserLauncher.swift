import Foundation

/// Opens the UI in an Edge app window (no tabs, no address bar) until the
/// host has its own window.
///
/// TODO(windows): host a WebView2 control in a native window instead.
public enum BrowserLauncher {

    public static func edgeExecutable() -> URL? {
        let environment = ProcessInfo.processInfo.environment
        let roots = [
            environment["ProgramFiles(x86)"], environment["ProgramFiles"], environment["LOCALAPPDATA"],
        ].compactMap { $0 }
        for root in roots {
            let candidate = URL(fileURLWithPath: root)
                .appendingPathComponent("Microsoft").appendingPathComponent("Edge")
                .appendingPathComponent("Application").appendingPathComponent("msedge.exe")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    @discardableResult
    public static func open(url: String, width: Int = 1480, height: Int = 920) -> Bool {
        #if os(Windows)
        let process = Process()
        if let edge = edgeExecutable() {
            process.executableURL = edge
            process.arguments = ["--app=\(url)", "--window-size=\(width),\(height)", "--new-window"]
        } else {
            process.executableURL = URL(fileURLWithPath: "C:\\Windows\\System32\\cmd.exe")
            process.arguments = ["/c", "start", "", url]
        }
        do {
            try process.run()
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }
}
