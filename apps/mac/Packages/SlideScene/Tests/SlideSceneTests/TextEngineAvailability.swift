/// Tests that measure text (paging, overflow) need the CoreText-backed text
/// engine, which only the Apple build has.
enum TextEngine {
    #if canImport(CoreText)
    static let isAvailable = true
    #else
    static let isAvailable = false
    #endif
}
