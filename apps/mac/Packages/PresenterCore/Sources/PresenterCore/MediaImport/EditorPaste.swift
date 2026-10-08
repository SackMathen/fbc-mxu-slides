import Foundation
#if canImport(ImageIO)
import CoreGraphics
import ImageIO
#endif

public enum EditorPaste {
    public enum Source: Equatable, Sendable {
        case objects, slides, files, image
    }

    public static let objectsType = "com.example.mxuslides.slide-objects"
    public static let slideType = "com.example.mxuslides.slide"
    public static let slidesType = "com.example.mxuslides.slides"

    /// Uniform type identifiers for the pasteboard, spelled out so the logic is
    /// the same on every platform (they match `UTType.fileURL`, `.png`, ... on Apple).
    static let fileURLType = "public.file-url"
    static let tiffType = "public.tiff"

    struct ImageType: Equatable, Sendable {
        var identifier: String
        var fileExtension: String
    }

    static let keptImageTypes: [ImageType] = [
        ImageType(identifier: "public.png", fileExtension: "png"),
        ImageType(identifier: "public.jpeg", fileExtension: "jpeg"),
        ImageType(identifier: "public.heic", fileExtension: "heic"),
        ImageType(identifier: "com.compuserve.gif", fileExtension: "gif"),
    ]

    public static func source(types: [String]) -> Source? {
        if types.contains(objectsType) {
            .objects
        } else if types.contains(slideType) || types.contains(slidesType) {
            .slides
        } else if types.contains(fileURLType) {
            .files
        } else if imageType(in: types) != nil {
            .image
        } else {
            nil
        }
    }

    public static func imageType(in types: [String]) -> String? {
        (keptImageTypes.map(\.identifier) + [tiffType]).first(where: types.contains)
    }

    public static func writeImage(_ data: Data, type: String, into directory: URL) -> URL? {
        let kept = keptImageTypes.first { $0.identifier == type }
        let url = directory
            .appendingPathComponent("Pasted Image")
            .appendingPathExtension(kept?.fileExtension ?? "png")
        #if canImport(ImageIO)
        if let source = CGImageSourceCreateWithData(data as CFData, nil),
           CGImageSourceGetCount(source) > 0,
           (try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)) != nil {
            if kept != nil {
                return (try? data.write(to: url)) != nil ? url : nil
            } else if let destination = CGImageDestinationCreateWithURL(
                url as CFURL, "public.png" as CFString, 1, nil) {
                CGImageDestinationAddImageFromSource(destination, source, 0, nil)
                return CGImageDestinationFinalize(destination) ? url : nil
            } else {
                return nil
            }
        } else {
            return nil
        }
        #else
        // Without ImageIO only the kept formats can be written, and only when the
        // bytes look like an image. TIFF pasteboard data is left alone.
        // TODO(windows): convert other formats to PNG through Windows Imaging Component.
        guard kept != nil, !data.isEmpty,
              kept?.identifier == "public.heic" || ImageHeaderProbe.probe(data: data) != nil,
              (try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)) != nil
        else { return nil }
        return (try? data.write(to: url)) != nil ? url : nil
        #endif
    }
}
