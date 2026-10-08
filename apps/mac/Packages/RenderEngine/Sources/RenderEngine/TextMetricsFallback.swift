#if !canImport(CoreText)
import Foundation

/// Rough text measurement for platforms without CoreText. The real text engine
/// (TextRasterizer) lays glyphs out; this only estimates how tall a block of
/// text is so scrolling and ticker logic can run.
///
/// TODO(windows): replace with DirectWrite measurement once the Windows text
/// engine exists.
enum TextMetricsFallback {
    static func blockHeight(for text: StyledText, sceneWidth: CGFloat) -> CGFloat {
        guard !text.string.isEmpty, sceneWidth > 0, text.fontSize > 0 else { return 0 }
        let width = max(Double(sceneWidth) - (text.insetLeft + text.insetRight), 1)
        let averageGlyphWidth = text.fontSize * 0.55 + max(text.tracking, 0)
        let charactersPerLine = max(1, Int(width / averageGlyphWidth))
        var lines = 0
        var paragraphs = 0
        for paragraph in text.string.split(separator: "\n", omittingEmptySubsequences: false) {
            paragraphs += 1
            lines += max(1, Int((Double(paragraph.count) / Double(charactersPerLine)).rounded(.up)))
        }
        let lineHeight = text.fontSize * 1.2 * max(text.lineHeightMultiple, 0.1)
        let height = Double(lines) * lineHeight
            + Double(max(paragraphs - 1, 0)) * text.paragraphSpacing
            + text.insetTop + text.insetBottom
        return CGFloat(height)
    }
}
#endif
