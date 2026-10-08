import Foundation

public enum HostPaths {

    /// Where the library lives when nothing else is asked for:
    /// `%LOCALAPPDATA%\MxU Slides\Library` on Windows, the application support
    /// folder elsewhere (the same place the Mac app uses).
    public static func defaultLibraryRoot() -> URL {
        #if os(Windows)
        if let local = ProcessInfo.processInfo.environment["LOCALAPPDATA"], !local.isEmpty {
            return URL(fileURLWithPath: local, isDirectory: true)
                .appendingPathComponent("MxU Slides", isDirectory: true)
                .appendingPathComponent("Library", isDirectory: true)
        }
        #endif
        let support = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        return support
            .appendingPathComponent("MxU Slides", isDirectory: true)
            .appendingPathComponent("Library", isDirectory: true)
    }

    /// The folder with index.html and the UI scripts. Looked for next to the
    /// executable (`web`), then up the tree from it (a development build sits
    /// in `apps/windows/.build/...`, the sources in `apps/windows/web`).
    public static func defaultWebRoot(executable: URL = Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])) -> URL? {
        var directory = executable.deletingLastPathComponent()
        for _ in 0..<8 {
            let candidate = directory.appendingPathComponent("web", isDirectory: true)
            if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("index.html").path) {
                return candidate
            }
            let parent = directory.deletingLastPathComponent()
            if parent.path == directory.path { break }
            directory = parent
        }
        return nil
    }

    public static func todayISO() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
