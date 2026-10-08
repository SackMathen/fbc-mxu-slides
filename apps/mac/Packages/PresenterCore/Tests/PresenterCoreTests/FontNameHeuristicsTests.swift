import Testing

@testable import PresenterCore

@Suite struct FontNameHeuristicsTests {
    @Test func readsTraitsFromPostScriptNames() {
        #expect(FontNameHeuristics.traits(ofFontNamed: "HelveticaNeue-Bold") == (true, false))
        #expect(FontNameHeuristics.traits(ofFontNamed: "HelveticaNeue-BoldItalic") == (true, true))
        #expect(FontNameHeuristics.traits(ofFontNamed: "Georgia-Italic") == (false, true))
        #expect(FontNameHeuristics.traits(ofFontNamed: "Avenir-Black") == (true, false))
        #expect(FontNameHeuristics.traits(ofFontNamed: "HelveticaNeue") == (false, false))
        #expect(FontNameHeuristics.traits(ofFontNamed: "Futura-CondensedExtraBold") == (true, false))
    }

    @Test func composesFamilyNames() {
        #expect(FontNameHeuristics.name(family: "Lato", bold: false, italic: false) == "Lato")
        #expect(FontNameHeuristics.name(family: "Lato", bold: true, italic: false) == "Lato-Bold")
        #expect(FontNameHeuristics.name(family: "Lato", bold: false, italic: true) == "Lato-Italic")
        #expect(FontNameHeuristics.name(family: "Lato", bold: true, italic: true) == "Lato-BoldItalic")
    }

    @Test func derivesVariantsKeepingOtherStyleWords() {
        #expect(FontNameHeuristics.fontName(basedOn: "HelveticaNeue", bold: true, italic: false) == "HelveticaNeue-Bold")
        #expect(FontNameHeuristics.fontName(basedOn: "HelveticaNeue-Bold", bold: true, italic: true) == "HelveticaNeue-BoldItalic")
        #expect(FontNameHeuristics.fontName(basedOn: "HelveticaNeue-Light", bold: true, italic: false) == "HelveticaNeue-LightBold")
        #expect(FontNameHeuristics.fontName(basedOn: "Georgia-Regular", bold: false, italic: false) == "Georgia")
    }
}
