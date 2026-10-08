import Foundation

/// Reads and composes bold/italic variants from PostScript-style font names
/// ("HelveticaNeue-BoldItalic"). This is the fallback where no font system can
/// be asked (Windows, until DirectWrite matching lands) and what the importers
/// use when a family is not installed.
public enum FontNameHeuristics {

    public static func traits(ofFontNamed name: String) -> (bold: Bool, italic: Bool) {
        let style = styleTokens(in: name)
        let bold = style.contains { boldWords.contains($0) }
        let italic = style.contains { italicWords.contains($0) }
        return (bold, italic)
    }

    /// `family` plus the conventional "-Bold", "-Italic" or "-BoldItalic" suffix.
    public static func name(family: String, bold: Bool, italic: Bool) -> String {
        switch (bold, italic) {
        case (false, false): family
        case (true, false): family + "-Bold"
        case (false, true): family + "-Italic"
        case (true, true): family + "-BoldItalic"
        }
    }

    /// A name for the same family as `name` with the requested traits, keeping
    /// any other style words (Condensed, Light, ...) the original carried.
    public static func fontName(basedOn name: String, bold: Bool, italic: Bool) -> String {
        let family = String(name.prefix { $0 != "-" })
        let kept = styleTokens(in: name).filter { !boldWords.contains($0) && !italicWords.contains($0) && $0 != "Regular" }
        var style = kept
        if bold { style.append("Bold") }
        if italic { style.append("Italic") }
        return style.isEmpty ? family : family + "-" + style.joined()
    }

    static func styleTokens(in name: String) -> [String] {
        guard let dash = name.firstIndex(of: "-") else { return [] }
        let style = name[name.index(after: dash)...]
        var tokens: [String] = []
        var current = ""
        for character in style {
            if character.isUppercase, !current.isEmpty {
                tokens.append(current)
                current = ""
            }
            if character.isLetter || character.isNumber {
                current.append(character)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    static let boldWords: Set<String> = ["Bold", "Black", "Heavy", "Semibold", "Demibold", "Extrabold", "Ultrabold"]
    static let italicWords: Set<String> = ["Italic", "Oblique"]
}
