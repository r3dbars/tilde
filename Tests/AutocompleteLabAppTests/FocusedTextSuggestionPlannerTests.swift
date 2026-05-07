import AutocompleteLabCore
import CoreGraphics
import Testing
@testable import AutocompleteLabApp

@Suite("Focused text suggestion planner")
struct FocusedTextSuggestionPlannerTests {
    @Test("Unchanged snapshots only refresh current visible state")
    func unchangedSnapshotTracksCurrentField() {
        let planner = planner()
        let context = focusedTextContext(textBeforeCursor: "hello there")
        let identity = fieldIdentity()
        let snapshot = FocusedTextSnapshot(
            fieldIdentity: identity,
            textBeforeCursor: "hello there",
            textAfterCursor: ""
        )

        let plan = planner.plan(
            context: context,
            profile: textEditProfile(),
            fieldIdentity: identity,
            lastTextSnapshot: snapshot,
            hasVisibleSuggestion: true,
            runtimeReport: readyRuntime(),
            isFieldSuppressed: false,
            lastRequestedTextBeforeCursor: nil,
            effectiveRenderMode: { $0 }
        )

        #expect(plan == .unchanged(FocusedTextSuggestionUnchangedPlan(
            decisionText: "Shown: tracking current field"
        )))
    }

    @Test("Diagnostics-only profiles block before runtime and activation")
    func diagnosticsOnlyProfilesBlock() {
        let plan = planner().plan(
            context: focusedTextContext(textBeforeCursor: "hello there"),
            profile: diagnosticsOnlyProfile(),
            fieldIdentity: fieldIdentity(),
            lastTextSnapshot: nil,
            hasVisibleSuggestion: false,
            runtimeReport: readyRuntime(),
            isFieldSuppressed: false,
            lastRequestedTextBeforeCursor: nil,
            effectiveRenderMode: { $0 }
        )

        guard case let .blocked(block) = plan else {
            Issue.record("Expected blocked plan")
            return
        }
        #expect(block.decisionText == "Blocked: profile diagnostics only")
        #expect(block.metadata == ["reason": "profile-diagnostics-only"])
        #expect(block.hideReason == nil)
    }

    @Test("Runtime not ready blocks with readiness metadata")
    func runtimeNotReadyBlocks() {
        let plan = planner().plan(
            context: focusedTextContext(textBeforeCursor: "hello there"),
            profile: textEditProfile(),
            fieldIdentity: fieldIdentity(),
            lastTextSnapshot: nil,
            hasVisibleSuggestion: false,
            runtimeReport: RuntimeReadinessReport(
                stage: .warming,
                summary: "Warming",
                action: .wait
            ),
            isFieldSuppressed: false,
            lastRequestedTextBeforeCursor: nil,
            effectiveRenderMode: { $0 }
        )

        guard case let .blocked(block) = plan else {
            Issue.record("Expected blocked plan")
            return
        }
        #expect(block.decisionText == "Blocked: runtime warming")
        #expect(block.metadata == [
            "reason": "runtime-not-ready",
            "readinessStage": "warming"
        ])
    }

    @Test("Activation blocks selected text with a hide reason")
    func activationBlocksSelectedText() {
        let plan = planner().plan(
            context: focusedTextContext(
                textBeforeCursor: "hello there",
                selectedTextLength: 3
            ),
            profile: textEditProfile(),
            fieldIdentity: fieldIdentity(),
            lastTextSnapshot: nil,
            hasVisibleSuggestion: false,
            runtimeReport: readyRuntime(),
            isFieldSuppressed: false,
            lastRequestedTextBeforeCursor: nil,
            effectiveRenderMode: { $0 }
        )

        guard case let .blocked(block) = plan else {
            Issue.record("Expected blocked plan")
            return
        }
        #expect(block.decisionText == "Blocked: selectedText")
        #expect(block.metadata == ["reason": "selectedText"])
        #expect(block.hideReason == "activation-selectedText")
    }

    @Test("Missing presentation capabilities block before trigger")
    func missingPresentationCapabilitiesBlock() {
        let plan = planner().plan(
            context: focusedTextContext(
                textBeforeCursor: "hello there ",
                caretRect: nil,
                elementRect: nil,
                windowRect: nil,
                canReadBoundsForRange: false
            ),
            profile: textEditProfile(),
            fieldIdentity: fieldIdentity(),
            lastTextSnapshot: nil,
            hasVisibleSuggestion: false,
            runtimeReport: readyRuntime(),
            isFieldSuppressed: false,
            lastRequestedTextBeforeCursor: nil,
            effectiveRenderMode: { $0 }
        )

        guard case let .blocked(block) = plan else {
            Issue.record("Expected blocked plan")
            return
        }
        #expect(block.decisionText == "Blocked: missing inline capabilities")
        #expect(block.metadata == ["reason": "missing-inline-capabilities"])
    }

    @Test("Detached mirror suppression is explicit")
    func detachedMirrorSuppressionIsExplicit() {
        let plan = planner().plan(
            context: focusedTextContext(
                textBeforeCursor: "hello there ",
                caretRect: nil,
                canReadBoundsForRange: false
            ),
            profile: detachedMirrorBlockedProfile(),
            fieldIdentity: fieldIdentity(),
            lastTextSnapshot: nil,
            hasVisibleSuggestion: false,
            runtimeReport: readyRuntime(),
            isFieldSuppressed: false,
            lastRequestedTextBeforeCursor: nil,
            effectiveRenderMode: { $0 }
        )

        guard case let .presentationSuppressed(suppression) = plan else {
            Issue.record("Expected presentation suppression")
            return
        }
        #expect(suppression.decisionText == "Blocked: detached suggestion disabled")
        #expect(suppression.renderMode == .floatingMirror)
        #expect(suppression.reason == .detachedSuggestionDisabled)
    }

    @Test("Cadence skip waits or repositions visible suggestions")
    func cadenceSkipWaitsOrRepositions() {
        let hiddenPlan = planner().plan(
            context: focusedTextContext(textBeforeCursor: "hello there "),
            profile: textEditProfile(),
            fieldIdentity: fieldIdentity(),
            lastTextSnapshot: nil,
            hasVisibleSuggestion: false,
            runtimeReport: readyRuntime(),
            isFieldSuppressed: false,
            lastRequestedTextBeforeCursor: "hello there ",
            effectiveRenderMode: { $0 }
        )
        let visiblePlan = planner().plan(
            context: focusedTextContext(textBeforeCursor: "hello there "),
            profile: textEditProfile(),
            fieldIdentity: fieldIdentity(),
            lastTextSnapshot: nil,
            hasVisibleSuggestion: true,
            runtimeReport: readyRuntime(),
            isFieldSuppressed: false,
            lastRequestedTextBeforeCursor: "hello there ",
            effectiveRenderMode: { $0 }
        )

        #expect(hiddenPlan == .cadenceWait(FocusedTextCadenceWaitPlan(
            snapshot: snapshot(textBeforeCursor: "hello there "),
            decisionText: "Waiting: cadence policy",
            shouldRepositionVisibleSuggestion: false,
            shouldRecordTriggerSkipped: true
        )))
        #expect(visiblePlan == .cadenceWait(FocusedTextCadenceWaitPlan(
            snapshot: snapshot(textBeforeCursor: "hello there "),
            decisionText: "Shown: waiting for cadence",
            shouldRepositionVisibleSuggestion: true,
            shouldRecordTriggerSkipped: false
        )))
    }

    @Test("Eligible changed text requests a suggestion")
    func eligibleChangedTextRequestsSuggestion() {
        let plan = planner().plan(
            context: focusedTextContext(textBeforeCursor: "hello there "),
            profile: textEditProfile(),
            fieldIdentity: fieldIdentity(),
            lastTextSnapshot: nil,
            hasVisibleSuggestion: false,
            runtimeReport: readyRuntime(),
            isFieldSuppressed: false,
            lastRequestedTextBeforeCursor: "hello there",
            effectiveRenderMode: { $0 }
        )

        #expect(plan == .request(FocusedTextSuggestionRequestPlan(
            snapshot: snapshot(textBeforeCursor: "hello there "),
            requestMode: .phraseContinuation,
            renderMode: .inlineAdjacent,
            delayMilliseconds: 0
        )))
    }

    private func planner() -> FocusedTextSuggestionPlanner {
        FocusedTextSuggestionPlanner(
            activationPolicy: CompletionActivationPolicy(minimumPhraseContinuationWords: 2),
            triggerPolicy: SuggestionTriggerPolicy(
                charactersBeforePauseRequest: 1,
                wordCompletionDelayMilliseconds: 0,
                wordBoundaryDelayMilliseconds: 0,
                pauseDelayMilliseconds: 15
            ),
            presentationPolicy: SuggestionPresentationPolicy()
        )
    }

    private func textEditProfile() -> CompatibilityProfile {
        CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit")!
    }

    private func diagnosticsOnlyProfile() -> CompatibilityProfile {
        CompatibilityProfile(
            bundleIdentifier: "com.example.Diagnostics",
            displayName: "Diagnostics",
            supportLevel: .diagnosticsOnly,
            supportReason: "Diagnostics only.",
            renderMode: .disabled,
            insertionMode: .disabled,
            notes: "Test profile."
        )
    }

    private func detachedMirrorBlockedProfile() -> CompatibilityProfile {
        CompatibilityProfile(
            bundleIdentifier: "com.example.Mirror",
            displayName: "Mirror",
            supportLevel: .yellow,
            supportReason: "Mirror only.",
            renderMode: .floatingMirror,
            insertionMode: .keyEvents,
            allowsDetachedSuggestions: false,
            notes: "Test profile."
        )
    }

    private func readyRuntime() -> RuntimeReadinessReport {
        RuntimeReadinessReport(
            stage: .ready,
            summary: "Ready",
            action: .none,
            isReady: true
        )
    }

    private func fieldIdentity() -> FocusedFieldIdentity {
        FocusedFieldIdentity(
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 42,
            elementIdentifier: 7
        )
    }

    private func snapshot(textBeforeCursor: String) -> FocusedTextSnapshot {
        FocusedTextSnapshot(
            fieldIdentity: fieldIdentity(),
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: ""
        )
    }

    private func focusedTextContext(
        textBeforeCursor: String,
        textAfterCursor: String = "",
        selectedTextLength: Int = 0,
        caretRect: CGRect? = CGRect(x: 10, y: 10, width: 1, height: 18),
        elementRect: CGRect? = CGRect(x: 0, y: 0, width: 300, height: 120),
        windowRect: CGRect? = CGRect(x: 0, y: 0, width: 600, height: 400),
        canReadBoundsForRange: Bool = true
    ) -> FocusedTextContext {
        FocusedTextContext(
            elementIdentifier: 7,
            role: "AXTextArea",
            subrole: nil,
            fingerprint: .init(identifier: "editor"),
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor,
            selectedTextLength: selectedTextLength,
            caretRect: caretRect,
            elementRect: elementRect,
            windowRect: windowRect,
            textLineRect: caretRect,
            visibleCharacterRange: nil,
            insertionPointLineNumber: nil,
            textStyle: nil,
            isSecure: false,
            caretIsSynthetic: false,
            capabilities: FocusedTextCapabilities(
                canReadValue: true,
                canReadSelectedTextRange: true,
                canReadBoundsForRange: canReadBoundsForRange,
                canReadAttributedText: false,
                canSetSelectedText: true
            ),
            axReadErrors: []
        )
    }
}
