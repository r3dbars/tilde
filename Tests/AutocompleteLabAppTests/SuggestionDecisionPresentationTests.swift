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

    @Test("Quiet decisions stay visibly quiet")
    func quietDecisionsStayVisiblyQuiet() {
        let presentation = SuggestionDecisionPresentation("Quiet: no useful suggestion")

        #expect(presentation.statusKind == .quiet)
        #expect(presentation.summary == "no useful suggestion")
        #expect(presentation.menuTitle == "Why: no useful suggestion")
        #expect(presentation.diagnosticsKind == "quiet")
    }

    @Test("Hidden and paused decisions stay visibly quiet")
    func hiddenAndPausedDecisionsStayVisiblyQuiet() {
        let hidden = SuggestionDecisionPresentation("Hidden: focus changed")
        let paused = SuggestionDecisionPresentation("Paused")

        #expect(hidden.statusKind == .quiet)
        #expect(hidden.summary == "focus changed")
        #expect(paused.statusKind == .quiet)
        #expect(paused.summary == "paused")
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
