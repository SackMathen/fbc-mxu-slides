import Foundation
#if canImport(Darwin)
import Darwin
#elseif os(Windows)
import WinSDK
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

extension DocumentFileStamp {

    /// The file's identity, size, and last-write time at nanosecond precision,
    /// or nil when it cannot be read. Two stamps compare equal only when the
    /// file is unchanged, which is what the resident tables and the blob
    /// store use to skip re-reading.
    public static func of(_ url: URL) -> DocumentFileStamp? {
        #if os(Windows)
        return windowsStamp(of: url)
        #else
        return posixStamp(of: url)
        #endif
    }

    #if os(Windows)
    private static func windowsStamp(of url: URL) -> DocumentFileStamp? {
        let path = url.withUnsafeFileSystemRepresentation { $0.map { String(cString: $0) } } ?? url.path
        return path.withCString(encodedAs: UTF16.self) { wide -> DocumentFileStamp? in
            // FILE_FLAG_BACKUP_SEMANTICS lets us open directories as well as files.
            let handle = CreateFileW(
                wide, DWORD(FILE_READ_ATTRIBUTES),
                DWORD(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE),
                nil, DWORD(OPEN_EXISTING), DWORD(FILE_FLAG_BACKUP_SEMANTICS), nil
            )
            guard handle != INVALID_HANDLE_VALUE else { return nil }
            defer { CloseHandle(handle) }
            var info = BY_HANDLE_FILE_INFORMATION()
            guard GetFileInformationByHandle(handle, &info) else { return nil }

            let size = Int64(UInt64(info.nFileSizeHigh) << 32 | UInt64(info.nFileSizeLow))
            let fileIndex = UInt64(info.nFileIndexHigh) << 32 | UInt64(info.nFileIndexLow)
            // FILETIME counts 100 ns ticks since 1601-01-01; shift to the Unix epoch
            // before widening to nanoseconds so the value fits in Int64.
            let ticks = Int64(bitPattern: UInt64(info.ftLastWriteTime.dwHighDateTime) << 32
                | UInt64(info.ftLastWriteTime.dwLowDateTime))
            let unixTicks = ticks - 116_444_736_000_000_000
            return DocumentFileStamp(inode: fileIndex, size: size, modifiedNanoseconds: unixTicks * 100)
        }
    }
    #else
    private static func posixStamp(of url: URL) -> DocumentFileStamp? {
        var info = stat()
        let found = url.withUnsafeFileSystemRepresentation { path in
            path.map { stat($0, &info) == 0 } ?? false
        }
        guard found else { return nil }
        #if canImport(Darwin)
        let modified = info.st_mtimespec
        #else
        let modified = info.st_mtim
        #endif
        return DocumentFileStamp(
            inode: UInt64(info.st_ino),
            size: Int64(info.st_size),
            modifiedNanoseconds: Int64(modified.tv_sec) * 1_000_000_000 + Int64(modified.tv_nsec)
        )
    }
    #endif
}
