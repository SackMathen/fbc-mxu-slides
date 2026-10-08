import Foundation
import Testing
#if canImport(ImageIO)
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
#endif
@testable import PresenterCore

@Test func editorPastePrefersObjectsThenSlidesThenFilesThenImages() {
    let tiff = "public.tiff"
    let png = "public.png"
    #expect(EditorPaste.source(types: [EditorPaste.objectsType, EditorPaste.slidesType]) == .objects)
    #expect(EditorPaste.source(types: [EditorPaste.slideType, EditorPaste.slidesType]) == .slides)

    #expect(EditorPaste.source(types: [tiff, "public.file-url"]) == .files)
    #expect(EditorPaste.source(types: ["com.apple.iWork.TSPNativeData", tiff]) == .image)
    #expect(EditorPaste.source(types: ["public.utf8-plain-text"]) == nil)
    #expect(EditorPaste.imageType(in: [tiff, png]) == png)
}

#if canImport(ImageIO)
@Test func editorPasteIdentifiersMatchTheSystemTypes() {
    #expect(EditorPaste.fileURLType == UTType.fileURL.identifier)
    #expect(EditorPaste.tiffType == UTType.tiff.identifier)
    #expect(EditorPaste.keptImageTypes.map(\.identifier) == [UTType.png, .jpeg, .heic, .gif].map(\.identifier))
    #expect(EditorPaste.keptImageTypes.map(\.fileExtension) == [UTType.png, .jpeg, .heic, .gif].map { $0.preferredFilenameExtension })
}

@Test func pastedTIFFBecomesAPNGFileAndPNGIsKeptAsCopied() throws {
    let context = try #require(CGContext(
        data: nil, width: 40, height: 20, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 40, height: 20))
    let image = try #require(context.makeImage())
    func encoded(_ type: UTType) throws -> Data {
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }

    let fromTIFF = try #require(EditorPaste.writeImage(try encoded(.tiff), type: UTType.tiff.identifier, into: directory))
    #expect(fromTIFF.lastPathComponent == "Pasted Image.png")
    let source = try #require(CGImageSourceCreateWithURL(fromTIFF as CFURL, nil))
    #expect(CGImageSourceGetType(source) as String? == UTType.png.identifier)
    #expect(CGImageSourceCreateImageAtIndex(source, 0, nil)?.width == 40)

    let png = try encoded(.png)
    let other = directory.appendingPathComponent("png")
    let kept = try #require(EditorPaste.writeImage(png, type: UTType.png.identifier, into: other))
    #expect(try Data(contentsOf: kept) == png)

    #expect(EditorPaste.writeImage(Data("not an image".utf8), type: UTType.tiff.identifier, into: directory.appendingPathComponent("bad")) == nil)
}
#else
@Test func pastedPNGIsKeptAndOtherFormatsAreDeclinedWithoutImageIO() throws {
    var png: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
    png += [0, 0, 0, 13] + Array("IHDR".utf8) + [0, 0, 0, 40, 0, 0, 0, 20, 8, 6, 0, 0, 0] + [0, 0, 0, 0]
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }

    let kept = try #require(EditorPaste.writeImage(Data(png), type: "public.png", into: directory))
    #expect(kept.lastPathComponent == "Pasted Image.png")
    #expect(try Data(contentsOf: kept) == Data(png))

    #expect(EditorPaste.writeImage(Data(png), type: "public.tiff", into: directory.appendingPathComponent("tiff")) == nil)
    #expect(EditorPaste.writeImage(Data("not an image".utf8), type: "public.png", into: directory.appendingPathComponent("bad")) == nil)
}
#endif
