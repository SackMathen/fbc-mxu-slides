import Foundation
import LocalAPI
#if os(Windows)
import WinSDK
#endif

/// Where the Local API's default key lives. The Mac keeps it in the Keychain;
/// here it is a file in the library folder sealed with DPAPI for the signed-in
/// Windows user, so only that user (on this machine) can read it back.
public enum WindowsKeyVault {

    public static func vault(fileURL: URL) -> APIDefaultKeyVault {
        #if os(Windows)
        return APIDefaultKeyVault(
            load: {
                guard let blob = try? Data(contentsOf: fileURL), let bytes = unprotect(blob) else { return nil }
                return String(data: bytes, encoding: .utf8)
            },
            save: { secret in
                guard let blob = protect(Data(secret.utf8)) else { return }
                try? blob.write(to: fileURL, options: .atomic)
            },
            clear: {
                try? FileManager.default.removeItem(at: fileURL)
            }
        )
        #else
        return .inMemory()
        #endif
    }

    #if os(Windows)
    static func protect(_ data: Data) -> Data? {
        transform(data) { input, output in
            CryptProtectData(input, nil, nil, nil, nil, DWORD(CRYPTPROTECT_UI_FORBIDDEN), output)
        }
    }

    static func unprotect(_ blob: Data) -> Data? {
        transform(blob) { input, output in
            CryptUnprotectData(input, nil, nil, nil, nil, DWORD(CRYPTPROTECT_UI_FORBIDDEN), output)
        }
    }

    private static func transform(
        _ data: Data,
        _ call: (UnsafeMutablePointer<DATA_BLOB>, UnsafeMutablePointer<DATA_BLOB>) -> Bool
    ) -> Data? {
        var bytes = [UInt8](data)
        return bytes.withUnsafeMutableBufferPointer { buffer -> Data? in
            var input = DATA_BLOB(cbData: DWORD(buffer.count), pbData: buffer.baseAddress)
            var output = DATA_BLOB()
            guard call(&input, &output), let result = output.pbData else { return nil }
            defer { LocalFree(UnsafeMutableRawPointer(result)) }
            return Data(bytes: result, count: Int(output.cbData))
        }
    }
    #endif
}
