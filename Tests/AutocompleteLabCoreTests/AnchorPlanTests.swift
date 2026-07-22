import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion anchor plans")
struct AnchorPlanTests {
    @Test("Bare anchor rect API preserves existing render behavior")
    func bareAnchorRectPreservesExistingRenderBehavior() {
        let caret = CGRect(x: 10, y: 20, width: 0, height: 18)
        let field = CGRect(x: 4, y: 12, width: 260, height: 44)
        let window = CGRect(x: 0, y: 0, width: 600, height: 420)

        #expect(RenderModePlan.anchorRect(
            for: .inlineAdjacent,
            caretRect: nil,
            elementRect: field,
            windowRect: window
        ) == nil)
        #expect(RenderModePlan.anchorRect(
            for: .floatingMirror,
            caretRect: caret,
            elementRect: field,
            windowRect: window
        ) == field)
        #expect(RenderModePlan.anchorRect(
            for: .floatingMirror,
            caretRect: caret,
            elementRect: nil,
            windowRect: window
        ) == window)
    }
}
