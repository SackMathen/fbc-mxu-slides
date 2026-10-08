import Foundation
import Testing

@testable import PresenterCore

@Suite struct ImageHeaderProbeTests {
    private func be32(_ value: Int) -> [UInt8] {
        [UInt8(value >> 24 & 0xFF), UInt8(value >> 16 & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF)]
    }

    private func le16(_ value: Int) -> [UInt8] { [UInt8(value & 0xFF), UInt8(value >> 8 & 0xFF)] }
    private func le24(_ value: Int) -> [UInt8] { le16(value) + [UInt8(value >> 16 & 0xFF)] }
    private func le32(_ value: Int) -> [UInt8] { le24(value) + [UInt8(value >> 24 & 0xFF)] }

    @Test func png() {
        var bytes: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        bytes += be32(13) + Array("IHDR".utf8) + be32(640) + be32(480) + [8, 6, 0, 0, 0] + be32(0)
        #expect(ImageHeaderProbe.probe(data: Data(bytes)) == ImageHeaderProbe(width: 640, height: 480, hasAlpha: true))

        bytes[25] = 2
        #expect(ImageHeaderProbe.probe(data: Data(bytes))?.hasAlpha == false)
    }

    @Test func gif() {
        let bytes = Array("GIF89a".utf8) + le16(800) + le16(600) + [0xF7, 0, 0]
        #expect(ImageHeaderProbe.probe(data: Data(bytes)) == ImageHeaderProbe(width: 800, height: 600, hasAlpha: nil))
    }

    @Test func bmpWithTopDownHeight() {
        var bytes = Array("BM".utf8) + [UInt8](repeating: 0, count: 16)
        bytes += le32(320) + le32(-200) + le16(1) + le16(24) + [UInt8](repeating: 0, count: 8)
        #expect(ImageHeaderProbe.probe(data: Data(bytes)) == ImageHeaderProbe(width: 320, height: 200, hasAlpha: false))
    }

    @Test func jpegSkipsSegmentsBeforeStartOfFrame() {
        var bytes: [UInt8] = [0xFF, 0xD8]
        bytes += [0xFF, 0xE0, 0x00, 0x10] + [UInt8](repeating: 0, count: 14)
        bytes += [0xFF, 0xE1, 0x00, 0x06] + [UInt8](repeating: 0, count: 4)
        bytes += [0xFF, 0xC0, 0x00, 0x11, 0x08] + [0x01, 0xE0] + [0x02, 0x80] + [UInt8](repeating: 0, count: 10)
        #expect(ImageHeaderProbe.probe(data: Data(bytes)) == ImageHeaderProbe(width: 640, height: 480, hasAlpha: false))
    }

    @Test func jpegWithoutFrameHeaderIsRejected() {
        let bytes: [UInt8] = [0xFF, 0xD8, 0xFF, 0xDA, 0x00, 0x02, 0xFF, 0xD9, 0, 0]
        #expect(ImageHeaderProbe.probe(data: Data(bytes)) == nil)
    }

    @Test func webpExtended() {
        var bytes = Array("RIFF".utf8) + le32(30) + Array("WEBP".utf8)
        bytes += Array("VP8X".utf8) + le32(10) + [0x10, 0, 0, 0] + le24(1919) + le24(1079)
        #expect(ImageHeaderProbe.probe(data: Data(bytes)) == ImageHeaderProbe(width: 1920, height: 1080, hasAlpha: true))
    }

    @Test func webpLossless() {
        let bits = 99 | 49 << 14 | 1 << 28
        var bytes = Array("RIFF".utf8) + le32(30) + Array("WEBP".utf8)
        bytes += Array("VP8L".utf8) + le32(5) + [0x2F] + le32(bits) + [0, 0, 0, 0]
        #expect(ImageHeaderProbe.probe(data: Data(bytes)) == ImageHeaderProbe(width: 100, height: 50, hasAlpha: true))
    }

    @Test func webpLossy() {
        var bytes = Array("RIFF".utf8) + le32(30) + Array("WEBP".utf8)
        bytes += Array("VP8 ".utf8) + le32(10) + [0, 0, 0, 0x9D, 0x01, 0x2A] + le16(1280) + le16(720) + [0, 0]
        #expect(ImageHeaderProbe.probe(data: Data(bytes)) == ImageHeaderProbe(width: 1280, height: 720, hasAlpha: false))
    }

    @Test func unknownBytesAreRejected() {
        #expect(ImageHeaderProbe.probe(data: Data("not an image at all".utf8)) == nil)
        #expect(ImageHeaderProbe.probe(data: Data([0x89, 0x50])) == nil)
    }

    @Test func mediaFileKindTables() {
        #expect(MediaFileKind.of(fileExtension: "PNG") == .image)
        #expect(MediaFileKind.of(fileExtension: "m4a") == .audio)
        #expect(MediaFileKind.of(fileExtension: "MOV") == .video)
        #expect(MediaFileKind.of(fileExtension: "txt") == .other(identifier: "txt"))
        #expect(MediaFileKind.of(fileExtension: "") == .other(identifier: "public.data"))
    }
}
