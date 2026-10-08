#if canImport(ImageIO)
import CoreGraphics
import Foundation
import ImageIO

public enum PosterDecode {

    public static let maxPixelSize = 512

    public static func image(original: URL, diskPoster: URL?) -> CGImage? {
        let source = CGImageSourceCreateWithURL(original as CFURL, nil)
        let opaque = source.map { !hasAlpha($0) } ?? false
        if opaque, let diskPoster, FileManager.default.fileExists(atPath: diskPoster.path) {
            return downsampled(url: diskPoster) ?? source.flatMap(downsampled(source:))
        } else {
            return source.flatMap(downsampled(source:))
        }
    }

    public static func downsampled(url: URL) -> CGImage? {
        CGImageSourceCreateWithURL(url as CFURL, nil).flatMap(downsampled(source:))
    }

    static func hasAlpha(_ source: CGImageSource) -> Bool {
        if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            return properties[kCGImagePropertyHasAlpha] as? Bool ?? false
        } else {
            return true
        }
    }

    static func downsampled(source: CGImageSource) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: false,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
#else
// TODO(windows): poster decoding produces a CGImage for the Mac thumbnail
// pipeline; the Windows thumbnail path will decode through Windows Imaging
// Component into its own bitmap type.
public enum PosterDecode {
    public static let maxPixelSize = 512
}
#endif
