import CoreGraphics
import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion geometry change policy")
struct SuggestionGeometryChangePolicyTests {
    private let policy = SuggestionGeometryChangePolicy()

    @Test("Screen layout changes hide visible suggestions")
    func screenLayoutChangesHideVisibleSuggestions() {
        #expect(policy.shouldInvalidateSuggestionState(
            hasVisibleSuggestion: true,
            hasPendingSuggestionRequest: false,
            previousScreenLayoutFingerprint: "0,0,1440x900@200",
            currentScreenLayoutFingerprint: "0,0,1728x1117@200"
        ))
    }

    @Test("Screen layout changes cancel pending requests")
    func screenLayoutChangesCancelPendingRequests() {
        #expect(policy.shouldInvalidateSuggestionState(
            hasVisibleSuggestion: false,
            hasPendingSuggestionRequest: true,
            previousScreenLayoutFingerprint: "0,0,1440x900@200",
            currentScreenLayoutFingerprint: "-1920,0,1920x1080@100|0,0,1440x900@200"
        ))
    }

    @Test("Unchanged screen layout keeps suggestion state")
    func unchangedScreenLayoutKeepsSuggestionState() {
        #expect(!policy.shouldInvalidateSuggestionState(
            hasVisibleSuggestion: true,
            hasPendingSuggestionRequest: true,
            previousScreenLayoutFingerprint: "0,0,1440x900@200",
            currentScreenLayoutFingerprint: "0,0,1440x900@200"
        ))
    }

    @Test("Missing fingerprints fail closed only when suggestion state exists")
    func missingFingerprintsFailClosedOnlyWhenSuggestionStateExists() {
        #expect(policy.shouldInvalidateSuggestionState(
            hasVisibleSuggestion: true,
            hasPendingSuggestionRequest: false,
            previousScreenLayoutFingerprint: nil,
            currentScreenLayoutFingerprint: "0,0,1440x900@200"
        ))
        #expect(!policy.shouldInvalidateSuggestionState(
            hasVisibleSuggestion: false,
            hasPendingSuggestionRequest: false,
            previousScreenLayoutFingerprint: nil,
            currentScreenLayoutFingerprint: "0,0,1440x900@200"
        ))
    }

    @Test("Stale scroll geometry hides visible suggestion")
    func staleScrollGeometryHidesVisibleSuggestion() {
        let previous = snapshot(textLineRect: CGRect(x: 120, y: 600, width: 480, height: 22))
        let current = snapshot(textLineRect: CGRect(x: 120, y: 548, width: 480, height: 22))

        let decision = policy.invalidationDecision(
            hasVisibleSuggestion: true,
            hasPendingSuggestionRequest: false,
            previousSnapshot: previous,
            currentSnapshot: current
        )

        #expect(decision == .invalidate(.textLineChanged))
        #expect(decision.metadata["geometryInvalidated"] == "true")
        #expect(decision.metadata["geometryInvalidationReason"] == "text-line-changed")
    }

    @Test("Caller-approved caret churn keeps visible suggestion")
    func callerApprovedCaretChurnKeepsVisibleSuggestion() {
        let previous = snapshot(caretRect: CGRect(x: 260, y: 445, width: 0, height: 20))
        let current = snapshot(caretRect: CGRect(x: 260, y: 230, width: 0, height: 20))

        let decision = policy.invalidationDecision(
            hasVisibleSuggestion: true,
            hasPendingSuggestionRequest: false,
            previousSnapshot: previous,
            currentSnapshot: current,
            allowsCaretRectChange: true
        )

        #expect(decision == .keep)
    }

    @Test("Caller-approved caret churn still blocks text line movement")
    func callerApprovedCaretChurnStillBlocksTextLineMovement() {
        let previous = snapshot(
            caretRect: CGRect(x: 260, y: 445, width: 0, height: 20),
            textLineRect: CGRect(x: 120, y: 600, width: 480, height: 22)
        )
        let current = snapshot(
            caretRect: CGRect(x: 260, y: 230, width: 0, height: 20),
            textLineRect: CGRect(x: 120, y: 548, width: 480, height: 22)
        )

        let decision = policy.invalidationDecision(
            hasVisibleSuggestion: true,
            hasPendingSuggestionRequest: false,
            previousSnapshot: previous,
            currentSnapshot: current,
            allowsCaretRectChange: true
        )

        #expect(decision == .invalidate(.textLineChanged))
    }

    @Test("Caller-approved editor geometry churn keeps text line movement")
    func callerApprovedEditorGeometryChurnKeepsTextLineMovement() {
        let previous = snapshot(
            caretRect: CGRect(x: 260, y: 445, width: 0, height: 20),
            textLineRect: nil
        )
        let current = snapshot(
            caretRect: CGRect(x: 260, y: 230, width: 0, height: 20),
            textLineRect: CGRect(x: 120, y: 548, width: 480, height: 22)
        )

        let decision = policy.invalidationDecision(
            hasVisibleSuggestion: true,
            hasPendingSuggestionRequest: false,
            previousSnapshot: previous,
            currentSnapshot: current,
            allowsCaretRectChange: true,
            allowsTextLineRectChange: true
        )

        #expect(decision == .keep)
    }

    @Test("Window moves invalidate visible geometry")
    func windowMovesInvalidateVisibleGeometry() {
        let previous = snapshot(windowRect: CGRect(x: 40, y: 80, width: 900, height: 700))
        let current = snapshot(windowRect: CGRect(x: 520, y: 80, width: 900, height: 700))

        let decision = policy.invalidationDecision(
            hasVisibleSuggestion: true,
            hasPendingSuggestionRequest: false,
            previousSnapshot: previous,
            currentSnapshot: current
        )

        #expect(decision == .invalidate(.windowChanged))
    }

    @Test("Multiple editable areas invalidate when field identity changes")
    func multipleEditableAreasInvalidateWhenFieldIdentityChanges() {
        let previous = snapshot(fieldIdentity: fieldIdentity(elementIdentifier: 1001))
        let current = snapshot(fieldIdentity: fieldIdentity(elementIdentifier: 2002))

        let decision = policy.invalidationDecision(
            hasVisibleSuggestion: true,
            hasPendingSuggestionRequest: false,
            previousSnapshot: previous,
            currentSnapshot: current
        )

        #expect(decision == .invalidate(.fieldChanged))
    }

    @Test("Vertical display topology changes cancel pending geometry")
    func verticalDisplayTopologyChangesCancelPendingGeometry() {
        let previous = snapshot(screenLayoutFingerprint: "0,0,1512x982@200")
        let current = snapshot(screenLayoutFingerprint: "0,-1080,1920x1080@100|0,0,1512x982@200")

        let decision = policy.invalidationDecision(
            hasVisibleSuggestion: false,
            hasPendingSuggestionRequest: true,
            previousSnapshot: previous,
            currentSnapshot: current
        )

        #expect(decision == .invalidate(.screenLayoutChanged))
    }

    @Test("Missing geometry snapshots fail closed only when state exists")
    func missingGeometrySnapshotsFailClosedOnlyWhenStateExists() {
        #expect(policy.invalidationDecision(
            hasVisibleSuggestion: true,
            hasPendingSuggestionRequest: false,
            previousSnapshot: nil,
            currentSnapshot: snapshot()
        ) == .invalidate(.missingGeometry))

        #expect(!policy.invalidationDecision(
            hasVisibleSuggestion: false,
            hasPendingSuggestionRequest: false,
            previousSnapshot: nil,
            currentSnapshot: snapshot()
        ).shouldInvalidate)
    }

    @Test("Stale visible geometry preserves current pending request")
    func staleVisibleGeometryPreservesCurrentPendingRequest() {
        #expect(policy.shouldPreservePendingRequestWhenVisibleSuggestionInvalidates(
            hasVisibleSuggestion: true,
            hasPendingSuggestionRequest: true,
            pendingRequestTextBeforeCursor: "Private beta recovery feels safer because ",
            pendingRequestTextAfterCursor: "",
            pendingRequestFieldIdentityDescription: "com.apple.TextEdit:42:1001",
            currentTextBeforeCursor: "Private beta recovery feels safer because ",
            currentTextAfterCursor: "",
            currentFieldIdentityDescription: "com.apple.TextEdit:42:1001"
        ))
    }

    @Test("Stale visible geometry cancels stale pending request")
    func staleVisibleGeometryCancelsStalePendingRequest() {
        #expect(!policy.shouldPreservePendingRequestWhenVisibleSuggestionInvalidates(
            hasVisibleSuggestion: true,
            hasPendingSuggestionRequest: true,
            pendingRequestTextBeforeCursor: "The local model stays responsive when ",
            pendingRequestTextAfterCursor: "",
            pendingRequestFieldIdentityDescription: "com.apple.TextEdit:42:1001",
            currentTextBeforeCursor: "Private beta recovery feels safer because ",
            currentTextAfterCursor: "",
            currentFieldIdentityDescription: "com.apple.TextEdit:42:1001"
        ))
    }

    @Test("Stale visible geometry cancels pending request for another field")
    func staleVisibleGeometryCancelsPendingRequestForAnotherField() {
        #expect(!policy.shouldPreservePendingRequestWhenVisibleSuggestionInvalidates(
            hasVisibleSuggestion: true,
            hasPendingSuggestionRequest: true,
            pendingRequestTextBeforeCursor: "Private beta recovery feels safer because ",
            pendingRequestTextAfterCursor: "",
            pendingRequestFieldIdentityDescription: "com.apple.TextEdit:42:1001",
            currentTextBeforeCursor: "Private beta recovery feels safer because ",
            currentTextAfterCursor: "",
            currentFieldIdentityDescription: "com.apple.TextEdit:42:2002"
        ))
    }

    private func fieldIdentity(elementIdentifier: Int = 1001) -> FocusedFieldIdentity {
        FocusedFieldIdentity(
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 42,
            elementIdentifier: elementIdentifier
        )
    }

    private func snapshot(
        fieldIdentity: FocusedFieldIdentity? = nil,
        screenLayoutFingerprint: String? = "0,0,1512x982@200",
        caretRect: CGRect? = CGRect(x: 320, y: 612, width: 2, height: 22),
        textLineRect: CGRect? = CGRect(x: 120, y: 600, width: 480, height: 22),
        elementRect: CGRect? = CGRect(x: 96, y: 220, width: 720, height: 540),
        windowRect: CGRect? = CGRect(x: 40, y: 80, width: 900, height: 700)
    ) -> SuggestionGeometrySnapshot {
        SuggestionGeometrySnapshot(
            fieldIdentity: fieldIdentity ?? self.fieldIdentity(),
            screenLayoutFingerprint: screenLayoutFingerprint,
            caretRect: caretRect,
            textLineRect: textLineRect,
            elementRect: elementRect,
            windowRect: windowRect
        )
    }
}
