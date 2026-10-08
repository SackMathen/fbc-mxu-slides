import Foundation

/// Reads an image's pixel size, and where the container records it whether it
/// carries alpha, straight from the file header. This is what media import uses
/// on platforms without ImageIO; it covers PNG, JPEG, GIF, BMP and WebP.
struct ImageHeaderProbe: Equatable, Sendable {
    var width: Int
    var height: Int

    /// nil when the format does not say up front (GIF, 32-bit BMP).
    var hasAlpha: Bool?

    /// Enough to get past large EXIF/APP segments in JPEGs.
    static let headerBytes = 256 * 1024

    static func probe(url: URL) -> ImageHeaderProbe? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: headerBytes) else { return nil }
        return probe(data: data)
    }

    static func probe(data: Data) -> ImageHeaderProbe? {
        let bytes = [UInt8](data)
        guard bytes.count >= 10 else { return nil }
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            return png(bytes)
        }
        if bytes.starts(with: Array("GIF8".utf8)) {
            return gif(bytes)
        }
        if bytes.starts(with: [0x42, 0x4D]) {
            return bmp(bytes)
        }
        if bytes.starts(with: Array("RIFF".utf8)), bytes.count >= 16, Array(bytes[8..<12]) == Array("WEBP".utf8) {
            return webp(bytes)
        }
        if bytes.starts(with: [0xFF, 0xD8]) {
            return jpeg(bytes)
        }
        return nil
    }

    private static func png(_ b: [UInt8]) -> ImageHeaderProbe? {
        guard b.count >= 29, Array(b[12..<16]) == Array("IHDR".utf8),
              let width = be32(b, 16), let height = be32(b, 20), width > 0, height > 0
        else { return nil }
        let colorType = b[25]
        return ImageHeaderProbe(width: width, height: height, hasAlpha: colorType == 4 || colorType == 6)
    }

    private static func gif(_ b: [UInt8]) -> ImageHeaderProbe? {
        guard let width = le16(b, 6), let height = le16(b, 8), width > 0, height > 0 else { return nil }
        return ImageHeaderProbe(width: width, height: height, hasAlpha: nil)
    }

    private static func bmp(_ b: [UInt8]) -> ImageHeaderProbe? {
        guard b.count >= 30, let width = le32(b, 18), let rawHeight = le32(b, 22), let bitsPerPixel = le16(b, 28),
              width > 0, rawHeight != 0
        else { return nil }
        return ImageHeaderProbe(width: width, height: abs(rawHeight), hasAlpha: bitsPerPixel == 32 ? nil : false)
    }

    private static func webp(_ b: [UInt8]) -> ImageHeaderProbe? {
        switch String(decoding: b[12..<16], as: UTF8.self) {
        case "VP8 ":
            guard b.count >= 30, let width = le16(b, 26), let height = le16(b, 28) else { return nil }
            return ImageHeaderProbe(width: width & 0x3FFF, height: height & 0x3FFF, hasAlpha: false)
        case "VP8L":
            guard b.count >= 25, b[20] == 0x2F, let bits = le32(b, 21) else { return nil }
            let width = (bits & 0x3FFF) + 1
            let height = ((bits >> 14) & 0x3FFF) + 1
            return ImageHeaderProbe(width: width, height: height, hasAlpha: (bits >> 28) & 1 == 1)
        case "VP8X":
            guard b.count >= 30, let width = le24(b, 24), let height = le24(b, 27) else { return nil }
            return ImageHeaderProbe(width: width + 1, height: height + 1, hasAlpha: b[20] & 0x10 != 0)
        default:
            return nil
        }
    }

    private static func jpeg(_ b: [UInt8]) -> ImageHeaderProbe? {
        var index = 2
        while index + 4 <= b.count {
            guard b[index] == 0xFF else { return nil }
            let marker = b[index + 1]
            if marker == 0xFF {
                index += 1
                continue
            }
            if marker == 0x01 || (0xD0...0xD8).contains(marker) {
                index += 2
                continue
            }
            if marker == 0xD9 || marker == 0xDA {
                return nil
            }
            guard let length = be16(b, index + 2), length >= 2 else { return nil }
            let isStartOfFrame = (0xC0...0xCF).contains(marker) && marker != 0xC4 && marker != 0xC8 && marker != 0xCC
            if isStartOfFrame {
                guard let height = be16(b, index + 5), let width = be16(b, index + 7), width > 0, height > 0 else { return nil }
                return ImageHeaderProbe(width: width, height: height, hasAlpha: false)
            }
            index += 2 + length
        }
        return nil
    }

    private static func be16(_ b: [UInt8], _ i: Int) -> Int? {
        guard i + 2 <= b.count else { return nil }
        return Int(b[i]) << 8 | Int(b[i + 1])
    }

    private static func be32(_ b: [UInt8], _ i: Int) -> Int? {
        guard i + 4 <= b.count else { return nil }
        return Int(b[i]) << 24 | Int(b[i + 1]) << 16 | Int(b[i + 2]) << 8 | Int(b[i + 3])
    }

    private static func le16(_ b: [UInt8], _ i: Int) -> Int? {
        guard i + 2 <= b.count else { return nil }
        return Int(b[i]) | Int(b[i + 1]) << 8
    }

    private static func le24(_ b: [UInt8], _ i: Int) -> Int? {
        guard i + 3 <= b.count else { return nil }
        return Int(b[i]) | Int(b[i + 1]) << 8 | Int(b[i + 2]) << 16
    }

    private static func le32(_ b: [UInt8], _ i: Int) -> Int? {
        guard i + 4 <= b.count else { return nil }
        let raw = UInt32(b[i]) | UInt32(b[i + 1]) << 8 | UInt32(b[i + 2]) << 16 | UInt32(b[i + 3]) << 24
        return Int(Int32(bitPattern: raw))
    }
}
