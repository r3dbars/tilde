import AutocompleteLabCore
import CoreGraphics
import Foundation
import Testing
@testable import AutocompleteLabApp

@MainActor
@Suite("Suggestion presentation refresh host")
struct SuggestionPresentationRefreshHostTests {
    @Test("Advances a residual suggestion to the optimistic post-accept caret")
    func advancesResidualSuggestionCaret() throws {
        let caretRect = CGRect(x: 40, y: 20, width: 1, height: 18)

        let result = ResidualSuggestionPlacement.advancedCaretRect(
            from: caretRect,
            acceptedTextWidth: 32,
            clippingRect: CGRect(x: 0, y: 0, width: 200, height: 80)
        )

        #expect(result == CGRect(x: 72, y: 20, width: 1, height: 18))
    }

    @Test("Refuses an optimistic residual placement that may wrap")
    func refusesResidualSuggestionCaretBeyondClippingBounds() throws {
        let result = ResidualSuggestionPlacement.advancedCaretRect(
            from: CGRect(x: 180, y: 20, width: 1, height: 18),
            acceptedTextWidth: 24,
            clippingRect: CGRect(x: 0, y: 0, width: 200, height: 80)
        )

        #expect(result == nil)
    }

    @Test("Refuses a residual placement without a measurable advance")
    func refusesResidualSuggestionCaretWithoutAdvance() throws {
        let caretRect = CGRect(x: 40, y: 20, width: 1, height: 18)

        #expect(ResidualSuggestionPlacement.advancedCaretRect(
            from: caretRect,
            acceptedTextWidth: 0,
            clippingRect: nil
        ) == nil)
    }

    @Test("Moves an optimistic type-through placement with the typed character")
    func shiftsTypeThroughCaretForward() throws {
        let result = ResidualSuggestionPlacement.shiftedCaretRect(
            from: CGRect(x: 40, y: 20, width: 1, height: 18),
            horizontalOffset: 9,
            clippingRect: CGRect(x: 0, y: 0, width: 200, height: 80)
        )

        #expect(result == CGRect(x: 49, y: 20, width: 1, height: 18))
    }

    @Test("Moves an optimistic type-through placement back after Backspace")
    func shiftsTypeThroughCaretBackward() throws {
        let result = ResidualSuggestionPlacement.shiftedCaretRect(
            from: CGRect(x: 49, y: 20, width: 1, height: 18),
            horizontalOffset: -9,
            clippingRect: CGRect(x: 0, y: 0, width: 200, height: 80)
        )

        #expect(result == CGRect(x: 40, y: 20, width: 1, height: 18))
    }

    @Test("Refuses an optimistic type-through shift outside clipping bounds")
    func refusesTypeThroughCaretOutsideClippingBounds() throws {
        let clippingRect = CGRect(x: 10, y: 0, width: 190, height: 80)

        #expect(ResidualSuggestionPlacement.shiftedCaretRect(
            from: CGRect(x: 14, y: 20, width: 1, height: 18),
            horizontalOffset: -8,
            clippingRect: clippingRect
        ) == nil)
        #expect(ResidualSuggestionPlacement.shiftedCaretRect(
            from: CGRect(x: 196, y: 20, width: 1, height: 18),
            horizontalOffset: 8,
            clippingRect: clippingRect
        ) == nil)
    }

    @Test("Fails closed when the frontmost application is unavailable")
    func failsClosedWithoutFrontmostApplication() throws {
        let fixtures = Fixtures()
        fixtures.frontmostApplication = nil

        let result = makeHost(fixtures).refresh(
            for: fixtures.request,
            requestContext: fixtures.context,
            profile: fixtures.profile,
            fieldIdentity: fixtures.fieldIdentity
        )

        #expect(result.context == nil)
        #expect(result.reason == "stale-app")
    }

    @Test("Rejects secure and selected fields before any presentation refresh")
    func rejectsUnsafeFocusedContext() throws {
        let fixtures = Fixtures()
        fixtures.context = makeContext(isSecure: true, selectedTextLength: 0)

        let result = makeHost(fixtures).refresh(
            for: fixtures.request,
            requestContext: fixtures.context,
            profile: fixtures.profile,
            fieldIdentity: fixtures.fieldIdentity
        )

        #expect(result.context == nil)
        #expect(result.reason == "stale-focused-context")

        fixtures.context = makeContext(isSecure: false, selectedTextLength: 2)
        let selectedTextResult = makeHost(fixtures).refresh(
            for: fixtures.request,
            requestContext: fixtures.context,
            profile: fixtures.profile,
            fieldIdentity: fixtures.fieldIdentity
        )

        #expect(selectedTextResult.context == nil)
        #expect(selectedTextResult.reason == "stale-focused-context")
    }

    @Test("Accepts a fresh matching context and rejects text drift")
    func keepsFreshContextAndRejectsDrift() throws {
        let fixtures = Fixtures()
        let host = makeHost(fixtures)

        let fresh = host.refresh(
            for: fixtures.request,
            requestContext: fixtures.context,
            profile: fixtures.profile,
            fieldIdentity: fixtures.fieldIdentity
        )
        #expect(fresh.context?.textBeforeCursor == fixtures.context.textBeforeCursor)
        #expect(fresh.reason == nil)

        fixtures.adjustedContext = makeContext(textBeforeCursor: "changed")
        let stale = host.refresh(
            for: fixtures.request,
            requestContext: fixtures.context,
            profile: fixtures.profile,
            fieldIdentity: fixtures.fieldIdentity
        )
        #expect(stale.context == nil)
        #expect(stale.reason == "stale-text")
    }

    @Test("Accepts compatible forward typing while a result is running")
    func acceptsForwardTyping() throws {
        let fixtures = Fixtures()
        fixtures.context = makeContext(textBeforeCursor: "drafting")
        fixtures.adjustedContext = fixtures.context

        let result = makeHost(fixtures).refresh(
            for: fixtures.request,
            requestContext: fixtures.context,
            profile: fixtures.profile,
            fieldIdentity: fixtures.fieldIdentity
        )

        #expect(result.context?.textBeforeCursor == "drafting")
        #expect(result.reason == nil)
    }

    @Test("Native Codex uses its prompt safety checks instead of terminal-host proof")
    func nativeCodexSkipsTerminalHostProof() throws {
        let fixtures = Fixtures()
        fixtures.profile = CompatibilityProfileStore.mvp.profile(for: "com.openai.codex")!
        fixtures.request = CompletionRequest(
            textBeforeCursor: "draft",
            textAfterCursor: "",
            appBundleIdentifier: "com.openai.codex",
            maxVisibleWords: 5,
            mode: .phraseContinuation,
            suggestionID: "codex-refresh"
        )
        fixtures.terminalHostProofBlockReason = "terminal-proof-not-applicable"

        let result = makeHost(fixtures).refresh(
            for: fixtures.request,
            requestContext: fixtures.context,
            profile: fixtures.profile,
            fieldIdentity: fixtures.fieldIdentity
        )

        #expect(result.context != nil)
        #expect(result.reason == nil)
    }

    private func makeHost(_ fixtures: Fixtures) -> SuggestionPresentationRefreshHost {
        SuggestionPresentationRefreshHost(
            dependencies: SuggestionPresentationRefreshHostDependencies(
                frontmostApplication: { fixtures.frontmostApplication },
                focusedTextContext: { _, _ in fixtures.context },
                frontmostAppMatchesSuggestion: { _, _, _ in true },
                terminalHostProofBlockReason: { _, _, _ in fixtures.terminalHostProofBlockReason },
                promptTextAreaMatch: { _, _ in fixtures.promptMatch },
                continuityHost: CodexPromptTargetContinuityHost(),
                currentFieldIdentity: { fixtures.fieldIdentity },
                lastTextSnapshot: { fixtures.snapshot },
                cancelAndRearmCodexPromptTargetWork: { _, _, _, _, _ in },
                presentationAdjustedContext: { _, _, _, _ in fixtures.adjustedContext },
                fieldIdentity: { _, _, _ in fixtures.fieldIdentity },
                canTrustPromptProofFieldIdentityRefresh: { _, _, _ in false },
                recordDiagnostic: { _, _ in }
            )
        )
    }
}

@MainActor
private final class Fixtures {
    var profile = CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit")!
    let fieldIdentity = FocusedFieldIdentity(
        bundleIdentifier: "com.apple.TextEdit",
        processIdentifier: 42,
        elementIdentifier: 7
    )
    var request = CompletionRequest(
        textBeforeCursor: "draft",
        textAfterCursor: "",
        appBundleIdentifier: "com.apple.TextEdit",
        maxVisibleWords: 5,
        mode: .phraseContinuation,
        suggestionID: "refresh"
    )
    let snapshot: FocusedTextSnapshot?
    let frontmost = RunningApplicationInfo(
        bundleIdentifier: "com.apple.TextEdit",
        localizedName: "TextEdit",
        processIdentifier: 42
    )
    var frontmostApplication: RunningApplicationInfo?
    var context: FocusedTextContext
    var adjustedContext: FocusedTextContext
    var promptMatch = SuggestionPresentationPromptMatch(canSuggest: true, reason: "text-area")
    var terminalHostProofBlockReason: String?

    init() {
        context = makeContext()
        adjustedContext = context
        snapshot = FocusedTextSnapshot(
            fieldIdentity: fieldIdentity,
            textBeforeCursor: request.textBeforeCursor,
            textAfterCursor: request.textAfterCursor
        )
        frontmostApplication = frontmost
    }
}

private func makeContext(
    textBeforeCursor: String = "draft",
    isSecure: Bool = false,
    selectedTextLength: Int = 0
) -> FocusedTextContext {
    FocusedTextContext(
        elementIdentifier: 7,
        role: "AXTextArea",
        subrole: nil,
        fingerprint: FocusedElementFingerprint(windowTitle: "TextEdit"),
        textBeforeCursor: textBeforeCursor,
        textAfterCursor: "",
        selectedTextLength: selectedTextLength,
        caretRect: CGRect(x: 10, y: 10, width: 1, height: 18),
        elementRect: CGRect(x: 0, y: 0, width: 500, height: 300),
        windowRect: CGRect(x: 0, y: 0, width: 600, height: 400),
        windowIdentifier: 42,
        textLineRect: CGRect(x: 10, y: 10, width: 140, height: 18),
        textStyle: nil,
        isSecure: isSecure,
        fieldClassification: AXFieldClassification(kind: .multilineCompose, reason: "test"),
        caretIsSynthetic: false,
        capabilities: FocusedTextCapabilities(
            canReadValue: true,
            canReadSelectedTextRange: true,
            canReadBoundsForRange: true,
            canReadAttributedText: false,
            canSetSelectedText: true
        )
    )
}
