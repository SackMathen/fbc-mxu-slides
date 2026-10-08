import Foundation
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

/// What kind of media a file is, judged by its name. On Apple platforms this
/// asks the system type database (so anything that conforms to `public.image`
/// and friends counts); elsewhere it uses the extension tables below.
enum MediaFileKind: Equatable, Sendable {
    case image
    case audio
    case video
    case other(identifier: String)

    static func of(url: URL) -> MediaFileKind {
        #if canImport(UniformTypeIdentifiers)
        let type = UTType(filenameExtension: url.pathExtension) ?? .data
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .audio) { return .audio }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
        return .other(identifier: type.identifier)
        #else
        return of(fileExtension: url.pathExtension)
        #endif
    }

    /// Extension-table classification; the fallback where there is no system
    /// type database, kept available everywhere so it can be tested.
    static func of(fileExtension: String) -> MediaFileKind {
        let ext = fileExtension.lowercased()
        if imageExtensions.contains(ext) { return .image }
        if audioExtensions.contains(ext) { return .audio }
        if videoExtensions.contains(ext) { return .video }
        return .other(identifier: ext.isEmpty ? "public.data" : ext)
    }

    static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "jpe", "jfif", "gif", "bmp", "dib", "tif", "tiff",
        "heic", "heif", "heics", "avif", "webp", "jp2", "j2k", "psd", "ico", "svg",
    ]

    static let audioExtensions: Set<String> = [
        "mp3", "wav", "wave", "aac", "m4a", "m4b", "flac", "aif", "aiff", "aifc", "caf",
        "ogg", "oga", "opus", "wma", "au", "snd", "ac3", "amr",
    ]

    static let videoExtensions: Set<String> = [
        "mp4", "m4v", "mov", "qt", "avi", "mkv", "webm", "wmv", "asf", "mpg", "mpeg", "mpe",
        "m2v", "ts", "m2ts", "mts", "mxf", "3gp", "3g2", "flv", "f4v", "ogv", "vob", "dv",
        "mjpeg", "mjpg", "hevc", "h264", "264", "265",
    ]
}
