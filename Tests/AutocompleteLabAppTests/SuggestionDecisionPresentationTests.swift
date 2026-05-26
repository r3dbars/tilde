import Testing
@testable import AutocompleteLabApp

@Suite("Suggestion decision presentation")
struct SuggestionDecisionPresentationTests {
    @Test("Blocked decisions become visible quiet menu copy")
    func blockedDecisionsBecomeVisibleQuietMenuCopy() {
        let presentation = SuggestionDecisionPresentation("Blocked: search fields stay quiet")

        #expect(presentation.statusKind == .quiet)
        #expect(presentation.summary == "search fields stay quiet")
        #expect(presentation.menuTitle == "Why: search fields stay quiet")
    }

    @Test("Shown decisions hide suggestion-like detail")
    func shownDecisionsHideSuggestionLikeDetail() {
        let presentation = SuggestionDecisionPresentation("Shown: typing 143ms")

        #expect(presentation.statusKind == .shown)
        #expect(presentation.summary == "Shown")
        #expect(presentation.menuTitle == "Why: Shown")
    }

    @Test("Long reasons stay one line")
    func longReasonsStayOneLine() {
        let presentation = SuggestionDecisionPresentation(
            "Blocked: this reason is intentionally long and contains\nprivate-shaped spacing that should collapse before it reaches the menu title because menu rows need to stay calm"
        )

        #expect(!presentation.menuTitle.contains("\n"))
        #expect(presentation.menuTitle.count <= 101)
    }
}
