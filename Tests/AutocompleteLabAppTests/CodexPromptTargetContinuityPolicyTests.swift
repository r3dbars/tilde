import AppKit
import AutocompleteLabCore
import Testing
@testable import AutocompleteLabApp

@Suite("Codex prompt target continuity policy")
struct CodexPromptTargetContinuityPolicyTests {
    private let policy = CodexPromptTargetContinuityPolicy()

    @Test("Preserves exact prompt through transient AX wrapper and bounds loss")
    func preservesExactPromptThroughTransientAXWrapperAndBoundsLoss() throws {
        let fieldIdentity = identity()
        let trustedContext = context()
        let anchor = try #require(policy.anchor(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            context: trustedContext
        ))
        let snapshot = snapshot(fieldIdentity: fieldIdentity)
        let wrapperContext = context(
            role: "AXWebArea",
            fingerprint: FocusedElementFingerprint(windowTitle: "Codex"),
            caretRect: nil,
            elementRect: CGRect(x: 0, y: 0, width: 900, height: 700)
        )
        let missingBoundsContext = context(caretRect: nil, elementRect: nil)

        #expect(policy.canDeferInvalidation(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            promptBlockReason: "missing-prompt-fingerprint",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: snapshot,
            trustedAnchor: anchor,
            observedContext: wrapperContext,
            trustedContext: trustedContext
        ))
        #expect(policy.canDeferInvalidation(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            promptBlockReason: "missing-prompt-bounds",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: snapshot,
            trustedAnchor: anchor,
            observedContext: missingBoundsContext,
            trustedContext: trustedContext
        ))
    }

    @Test("Preserves an in-flight request without requiring a visible suggestion")
    func preservesInflightRequestWithoutVisibleSuggestion() throws {
        let fieldIdentity = identity()
        let trustedContext = context()
        let anchor = try #require(policy.anchor(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            context: trustedContext
        ))

        #expect(policy.canDeferInvalidation(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            promptBlockReason: "missing-prompt-fingerprint",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: snapshot(fieldIdentity: fieldIdentity),
            trustedAnchor: anchor,
            observedContext: context(
                role: "AXWebArea",
                fingerprint: FocusedElementFingerprint(windowTitle: "Codex"),
                caretRect: nil,
                elementRect: nil
            )
        ))
    }

    @Test("Rejects wrapper continuity when text changes")
    func rejectsWrapperContinuityWhenTextChanges() throws {
        let fieldIdentity = identity()
        let trustedContext = context()
        let anchor = try #require(policy.anchor(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            context: trustedContext
        ))

        #expect(!policy.canDeferInvalidation(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            promptBlockReason: "missing-prompt-fingerprint",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: snapshot(fieldIdentity: fieldIdentity),
            trustedAnchor: anchor,
            observedContext: context(
                role: "AXWebArea",
                fingerprint: FocusedElementFingerprint(windowTitle: "Codex"),
                textBeforeCursor: "synthetic prompt changed",
                caretRect: nil,
                elementRect: nil
            )
        ))
    }

    @Test("Rejects continuity across process window or text-area movement")
    func rejectsContinuityAcrossProcessWindowOrTextAreaMovement() throws {
        let fieldIdentity = identity()
        let trustedContext = context()
        let anchor = try #require(policy.anchor(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            context: trustedContext
        ))
        let snapshot = snapshot(fieldIdentity: fieldIdentity)

        #expect(!policy.canDeferInvalidation(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 43,
            promptBlockReason: "missing-prompt-bounds",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: snapshot,
            trustedAnchor: anchor,
            observedContext: context(caretRect: nil, elementRect: nil)
        ))
        #expect(!policy.canDeferInvalidation(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            promptBlockReason: "missing-prompt-bounds",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: snapshot,
            trustedAnchor: anchor,
            observedContext: context(caretRect: nil, elementRect: nil, windowIdentifier: 9)
        ))
        #expect(!policy.canDeferInvalidation(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            promptBlockReason: "missing-prompt-bounds",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: snapshot,
            trustedAnchor: anchor,
            observedContext: context(
                elementRect: CGRect(x: 80, y: 500, width: 700, height: 80)
            )
        ))
    }

    @Test("Rejects secure selected unsupported or unanchored contexts")
    func rejectsSecureSelectedUnsupportedOrUnanchoredContexts() throws {
        let fieldIdentity = identity()
        let trustedContext = context()
        let anchor = try #require(policy.anchor(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            context: trustedContext
        ))
        let snapshot = snapshot(fieldIdentity: fieldIdentity)

        for observedContext in [
            context(isSecure: true),
            context(selectedTextLength: 1),
            context(role: "AXButton")
        ] {
            #expect(!policy.canDeferInvalidation(
                appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
                processIdentifier: 42,
                promptBlockReason: "missing-prompt-bounds",
                currentFieldIdentity: fieldIdentity,
                currentSnapshot: snapshot,
                trustedAnchor: anchor,
                observedContext: observedContext
            ))
        }

        #expect(!policy.canDeferInvalidation(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            promptBlockReason: "non-prompt-role",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: snapshot,
            trustedAnchor: anchor,
            observedContext: context(elementRect: nil)
        ))
        #expect(!policy.canDeferInvalidation(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            promptBlockReason: "missing-prompt-bounds",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: snapshot,
            trustedAnchor: nil,
            observedContext: context(elementRect: nil)
        ))
    }

    @Test("Rejects an expired trusted prompt anchor")
    func rejectsExpiredTrustedPromptAnchor() throws {
        let fieldIdentity = identity()
        let anchor = try #require(policy.anchor(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            context: context(),
            nowMilliseconds: 100
        ))

        #expect(!policy.canDeferInvalidation(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            promptBlockReason: "missing-prompt-bounds",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: snapshot(fieldIdentity: fieldIdentity),
            trustedAnchor: anchor,
            observedContext: context(caretRect: nil, elementRect: nil),
            nowMilliseconds: 1_101
        ))
    }

    @Test("Rejects missing bounds from a different raw text area")
    func rejectsMissingBoundsFromDifferentRawTextArea() throws {
        let fieldIdentity = identity()
        let anchor = try #require(policy.anchor(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            context: context()
        ))

        #expect(!policy.canDeferInvalidation(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            promptBlockReason: "missing-prompt-bounds",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: snapshot(fieldIdentity: fieldIdentity),
            trustedAnchor: anchor,
            observedContext: context(elementIdentifier: 99, caretRect: nil, elementRect: nil)
        ))
    }

    @Test("Presentation refresh retries are bounded")
    func presentationRefreshRetriesAreBounded() {
        let retryPolicy = CodexPromptPresentationRefreshRetryPolicy(
            maximumAttempts: 3,
            delayMilliseconds: 80
        )

        #expect(retryPolicy.next(after: 0) == CodexPromptPresentationRefreshRetry(
            attempt: 1,
            delayMilliseconds: 80
        ))
        #expect(retryPolicy.next(after: 1)?.attempt == 2)
        #expect(retryPolicy.next(after: 2)?.attempt == 3)
        #expect(retryPolicy.next(after: 3) == nil)
        #expect(retryPolicy.next(after: -1) == nil)
    }

    private func identity() -> FocusedFieldIdentity {
        FocusedFieldIdentity(
            bundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            elementIdentifier: 7
        )
    }

    private func snapshot(fieldIdentity: FocusedFieldIdentity) -> FocusedTextSnapshot {
        FocusedTextSnapshot(
            fieldIdentity: fieldIdentity,
            textBeforeCursor: "synthetic prompt",
            textAfterCursor: ""
        )
    }

    private func context(
        elementIdentifier: Int = 7,
        role: String = "AXTextArea",
        fingerprint: FocusedElementFingerprint = FocusedElementFingerprint(
            identifier: "prompt",
            title: "Codex",
            placeholder: "Ask Codex",
            windowTitle: "Codex"
        ),
        textBeforeCursor: String = "synthetic prompt",
        selectedTextLength: Int = 0,
        caretRect: CGRect? = CGRect(x: 120, y: 650, width: 1, height: 20),
        elementRect: CGRect? = CGRect(x: 100, y: 620, width: 700, height: 80),
        windowIdentifier: Int? = 1,
        isSecure: Bool = false
    ) -> FocusedTextContext {
        FocusedTextContext(
            elementIdentifier: elementIdentifier,
            role: role,
            subrole: nil,
            fingerprint: fingerprint,
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: "",
            selectedTextLength: selectedTextLength,
            caretRect: caretRect,
            elementRect: elementRect,
            windowRect: CGRect(x: 0, y: 0, width: 900, height: 700),
            windowIdentifier: windowIdentifier,
            textLineRect: nil,
            textStyle: nil,
            isSecure: isSecure,
            caretIsSynthetic: false,
            capabilities: FocusedTextCapabilities(
                canReadValue: true,
                canReadSelectedTextRange: true,
                canReadBoundsForRange: caretRect != nil,
                canReadAttributedText: false,
                canSetSelectedText: true
            )
        )
    }
}
