import Testing
@testable import AutocompleteLabApp

@Suite("Ghost text line layout")
struct GhostTextLineLayoutTests {
    @Test("Uses stable font metrics for the inline line box")
    func usesStableFontMetrics() {
        let layout = GhostTextLineLayout.resolve(
            boundsHeight: 30,
            fontAscender: 19,
            fontDescender: -5,
            fontLeading: 0,
            minimumTopInset: 0
        )

        #expect(layout == GhostTextLineLayout(originY: 3, lineHeight: 24))
    }

    @Test("Honors the minimum top inset")
    func honorsMinimumTopInset() {
        let layout = GhostTextLineLayout.resolve(
            boundsHeight: 24,
            fontAscender: 14,
            fontDescender: -4,
            fontLeading: 0,
            minimumTopInset: 5
        )

        #expect(layout == GhostTextLineLayout(originY: 5, lineHeight: 18))
    }
}
