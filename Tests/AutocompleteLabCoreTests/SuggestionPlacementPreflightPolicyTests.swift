import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion placement preflight policy")
struct SuggestionPlacementPreflightPolicyTests {
    private let policy = SuggestionPlacementPreflightPolicy()

    @Test("Allows requests when placement can present")
    func allowsPresentablePlacement() {
        let plan = PlacementHealthPlan.present(PlacementHealthPresentation(
            requestedRenderMode: .inlineAdjacent,
            renderMode: .inlineAdjacent,
            anchorRect: CGRect(x: 10, y: 20, width: 0, height: 18),
            anchorSource: .caret,
            textLineRect: nil,
            clippingRect: nil,
            reason: .healthy
        ))

        let decision = policy.decision(for: plan)

        #expect(decision.canRequest)
        #expect(decision.suppression == nil)
    }

    @Test("Blocks requests when placement is suppressed")
    func blocksSuppressedPlacement() {
        let suppression = PlacementHealthSuppression(
            requestedRenderMode: .floatingMirror,
            reason: .detachedSuggestionDisabled
        )
        let decision = policy.decision(for: .suppress(suppression))

        #expect(!decision.canRequest)
        #expect(decision.suppression == suppression)
    }
}
