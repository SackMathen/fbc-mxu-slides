import Foundation

public enum MediaRelink {

    public struct Probe: Sendable {
        public var mediaKind: MediaKind
        public var fileStatus: MediaFileStatus
        public var statusDetail: String
        public var durationSeconds: Double?
        public var pixelWidth: Int?
        public var pixelHeight: Int?
    }

    public static func probe(url: URL) async -> Probe? {
        switch MediaFileKind.of(url: url) {
        case .image:
            guard let dimensions = MediaImporter.imageDimensions(at: url) else { return nil }
            return Probe(
                mediaKind: .image, fileStatus: .ready, statusDetail: "",
                durationSeconds: nil,
                pixelWidth: dimensions.width,
                pixelHeight: dimensions.height
            )
        case .video:
            let probe = await MediaImporter.probeVideo(url: url)
            return Probe(
                mediaKind: .video, fileStatus: probe.status, statusDetail: probe.detail,
                durationSeconds: probe.duration,
                pixelWidth: probe.width, pixelHeight: probe.height
            )
        case .audio, .other:
            return nil
        }
    }

    public static func restored(tombstone: MediaItem, hash: String, fileURL: URL, probe: Probe) -> MediaItem {
        var out = tombstone
        out.fileHash = hash
        out.fileName = fileURL.lastPathComponent
        out.name = fileURL.deletingPathExtension().lastPathComponent
        out.mediaKind = probe.mediaKind
        out.fileStatus = probe.fileStatus
        out.statusDetail = probe.statusDetail
        out.durationSeconds = probe.durationSeconds
        out.pixelWidth = probe.pixelWidth
        out.pixelHeight = probe.pixelHeight
        return out
    }

    public static func carriedSettings(of item: MediaItem) -> [String] {
        var out: [String] = []
        if item.inPoint != nil || item.outPoint != nil { out.append("Trim") }
        if let rate = item.playRate, rate != 1 { out.append("Play Rate") }
        if !(item.effects ?? []).isEmpty { out.append("Effects") }
        if item.transition != nil { out.append("Transition") }
        if !(item.actions ?? []).isEmpty { out.append("Actions") }
        if item.autoAdvance != nil { out.append("Auto Advance") }
        return out
    }
}
