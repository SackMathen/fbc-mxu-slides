import Foundation
#if canImport(Darwin)
import Darwin
import MachO
#elseif os(Windows)
import WinSDK
#endif

public struct BuildIdentity: Equatable, Sendable {
    public var version: String
    public var build: String

    public var commit: String?

    public static let commitKey = "MXUGitCommit"

    public init(version: String, build: String, commit: String?) {
        self.version = version
        self.build = build
        self.commit = commit
    }

    public init(info: [String: Any]?) {
        let commit = (info?[Self.commitKey] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        self.init(
            version: info?["CFBundleShortVersionString"] as? String ?? "?",
            build: info?["CFBundleVersion"] as? String ?? "?",
            commit: commit.isEmpty || commit.contains("$(") ? nil : commit)
    }

    public var commitLabel: String {
        commit ?? "unknown"
    }

    public var reportFields: [String: String] {
        ["app_version": version, "app_build": build, "app_commit": commitLabel]
    }

    public func launchLine(os: String, image: LoadedImage?) -> String {
        let base = "v\(version) (\(build)) commit \(commitLabel) on \(Self.platformName) \(os)"
        if let image {
            return base + ", image \(image.description)"
        } else {
            return base + ", image unknown"
        }
    }

    static var platformName: String {
        #if os(macOS)
        "macOS"
        #elseif os(Windows)
        "Windows"
        #elseif os(Linux)
        "Linux"
        #else
        "unknown OS"
        #endif
    }
}

public struct LoadedImage: Equatable, Sendable {
    public var name: String
    public var loadAddress: UInt
    // Spelled out because WinSDK also exports a `UUID`.
    public var uuid: Foundation.UUID?

    public init(name: String, loadAddress: UInt, uuid: Foundation.UUID?) {
        self.name = name
        self.loadAddress = loadAddress
        self.uuid = uuid
    }

    /// The loaded module (dylib, framework, DLL, or main executable) that
    /// contains `address`, or nil when the address is not inside any module.
    public init?(containing address: UnsafeRawPointer) {
        #if canImport(Darwin)
        var info = Dl_info()
        if dladdr(address, &info) != 0, let base = info.dli_fbase {
            let path = info.dli_fname.map { String(cString: $0) } ?? "?"
            self.init(
                name: (path as NSString).lastPathComponent,
                loadAddress: UInt(bitPattern: base),
                uuid: Self.uuid(inMachHeader: UnsafeRawPointer(base)))
        } else {
            return nil
        }
        #elseif os(Windows)
        var module: HMODULE?
        let flags = DWORD(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT)
        let found = address.withMemoryRebound(to: WCHAR.self, capacity: 1) {
            GetModuleHandleExW(flags, $0, &module)
        }
        guard found, let module else { return nil }
        var buffer = [WCHAR](repeating: 0, count: 4096)
        let length = GetModuleFileNameW(module, &buffer, DWORD(buffer.count))
        let path = length > 0 ? String(decoding: buffer.prefix(Int(length)), as: UTF16.self) : ""
        self.init(
            name: path.split(whereSeparator: { $0 == "\\" || $0 == "/" }).last.map(String.init) ?? "",
            loadAddress: UInt(bitPattern: module),
            uuid: nil)
        #else
        return nil
        #endif
    }

    public var description: String {
        "\(name) at 0x\(String(loadAddress, radix: 16)) uuid \(uuid?.uuidString ?? "unknown")"
    }

    #if canImport(Darwin)
    public static func uuid(inMachHeader header: UnsafeRawPointer) -> Foundation.UUID? {
        let mach = header.loadUnaligned(as: mach_header_64.self)
        var found: Foundation.UUID?
        if mach.magic == MH_MAGIC_64 {
            var cursor = header + MemoryLayout<mach_header_64>.size
            var remaining = mach.ncmds
            while remaining > 0, found == nil {
                let command = cursor.loadUnaligned(as: load_command.self)
                if command.cmd == UInt32(LC_UUID) {
                    found = Foundation.UUID(uuid: cursor.loadUnaligned(as: uuid_command.self).uuid)
                }
                cursor += Int(command.cmdsize)
                remaining -= 1
            }
        }
        return found
    }
    #endif
}
