import AppKit
import AutocompleteLabCore
import Testing
@testable import AutocompleteLabApp

@Suite("Codex prompt target continuity policy")
struct CodexPromptTargetContinuityPolicyTests {
    private let policy = CodexPromptTargetContinuityPolicy()

    @Test("Presentation preparation defers before any focused-context refresh")
    func presentationPreparationDefersBeforeAnyFocusedContextRefresh() {
        let preparationPolicy = CodexPromptPresentationPreparationPolicy()

        #expect(preparationPolicy.preparation(
            refreshBeforePresenting: true,
            cooldownDelayMilliseconds: 250
        ) == .deferForAXCooldown(delayMilliseconds: 250))
        #expect(preparationPolicy.preparation(
            refreshBeforePresenting: true,
            cooldownDelayMilliseconds: 0
        ) == .refreshFocusedContext)
        #expect(preparationPolicy.preparation(
            refreshBeforePresenting: false,
            cooldownDelayMilliseconds: 250
        ) == .useOriginalContext)
    }

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

    @Test("Quarantines a request across an empty wrapper and appended cursor split")
    func quarantinesRequestAcrossTransientCodexTextSplit() throws {
        let fieldIdentity = identity()
        let before = String(repeating: "a", count: 15)
        let trustedContext = context(textBeforeCursor: before)
        let anchor = try #require(policy.anchor(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            context: trustedContext
        ))
        let currentSnapshot = snapshot(
            fieldIdentity: fieldIdentity,
            textBeforeCursor: before
        )
        let emptyWrapper = context(
            elementIdentifier: 99,
            role: "AXWebArea",
            fingerprint: FocusedElementFingerprint(),
            textBeforeCursor: "",
            textAfterCursor: "",
            caretRect: nil,
            elementRect: CGRect(x: 0, y: 0, width: 900, height: 700),
            windowRect: nil
        )
        let afterOnlyTextArea = context(
            textBeforeCursor: "",
            textAfterCursor: before + String(repeating: "b", count: 11),
            caretRect: nil,
            windowRect: nil
        )

        #expect(policy.invalidationResolution(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            promptBlockReason: "missing-prompt-fingerprint",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: currentSnapshot,
            trustedAnchor: anchor,
            observedContext: emptyWrapper,
            trustedContext: trustedContext
        ) == .cancelAndRetry)
        #expect(!policy.canDeferInvalidation(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            promptBlockReason: "missing-prompt-bounds",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: currentSnapshot,
            trustedAnchor: anchor,
            observedContext: afterOnlyTextArea,
            trustedContext: trustedContext
        ))
        #expect(policy.axHealthInvalidationResolution(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: currentSnapshot,
            trustedAnchor: anchor,
            observedContext: afterOnlyTextArea
        ) == .cancelAndRetry)
        #expect(policy.invalidationResolution(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            promptBlockReason: "missing-prompt-bounds",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: currentSnapshot,
            trustedAnchor: anchor,
            observedContext: afterOnlyTextArea,
            trustedContext: trustedContext
        ) == .cancelAndRetry)
        let presentationResolution = policy.presentationRefreshResolution(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            promptBlockReason: "missing-prompt-bounds",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: currentSnapshot,
            trustedAnchor: anchor,
            observedContext: afterOnlyTextArea,
            trustedContext: trustedContext
        )
        #expect(presentationResolution == .cancelAndRetry)

        var retryState = SuggestionIdleRetryState(settleDelayMilliseconds: 240)
        retryState.noteTextChange(
            snapshot: currentSnapshot,
            cancelledPendingRequest: true,
            nowMilliseconds: 0
        )
        let recoveredSnapshot = snapshot(
            fieldIdentity: fieldIdentity,
            textBeforeCursor: afterOnlyTextArea.textAfterCursor
        )
        retryState.noteTextChange(
            snapshot: recoveredSnapshot,
            cancelledPendingRequest: false,
            nowMilliseconds: 750
        )
        #expect(retryState.consumeRetryIfReady(
            snapshot: recoveredSnapshot,
            nowMilliseconds: 989,
            hasVisibleSuggestion: false
        ) == nil)
        #expect(retryState.consumeRetryIfReady(
            snapshot: recoveredSnapshot,
            nowMilliseconds: 990,
            hasVisibleSuggestion: false
        ) == .requestCancelled)

        let changedAfterOnlyTextArea = context(
            textBeforeCursor: "",
            textAfterCursor: String(repeating: "c", count: 26),
            caretRect: nil,
            windowRect: nil
        )
        #expect(policy.invalidationResolution(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            promptBlockReason: "missing-prompt-bounds",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: currentSnapshot,
            trustedAnchor: anchor,
            observedContext: changedAfterOnlyTextArea,
            trustedContext: trustedContext
        ) == .reject)
        #expect(policy.invalidationResolution(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            promptBlockReason: "missing-prompt-bounds",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: currentSnapshot,
            trustedAnchor: anchor,
            observedContext: context(
                elementIdentifier: 99,
                textBeforeCursor: "",
                textAfterCursor: before + String(repeating: "b", count: 11),
                caretRect: nil,
                windowRect: nil
            ),
            trustedContext: trustedContext
        ) == .reject)
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
        #expect(!policy.canDeferInvalidation(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            promptBlockReason: "missing-prompt-bounds",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: snapshot,
            trustedAnchor: anchor,
            observedContext: context(
                elementRect: CGRect(x: 100, y: 620, width: 700, height: 100)
            )
        ))
        #expect(!policy.canDeferInvalidation(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            promptBlockReason: "missing-prompt-bounds",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: snapshot,
            trustedAnchor: anchor,
            observedContext: context(
                elementRect: CGRect(x: 100, y: 620, width: 0, height: 80)
            )
        ))
        #expect(policy.canDeferInvalidation(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            promptBlockReason: "missing-prompt-bounds",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: snapshot,
            trustedAnchor: anchor,
            observedContext: context(
                elementRect: CGRect(x: 104, y: 616, width: 704, height: 84)
            )
        ))
    }

    @Test("Rejects a web-area wrapper without affirmative same-window identity")
    func rejectsWebAreaWrapperWithoutAffirmativeSameWindowIdentity() throws {
        let fieldIdentity = identity()
        let anchor = try #require(policy.anchor(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            context: context()
        ))
        let inconclusiveWrapper = context(
            elementIdentifier: 99,
            role: "AXWebArea",
            fingerprint: FocusedElementFingerprint(),
            caretRect: nil,
            elementRect: nil,
            windowIdentifier: nil,
            windowRect: nil
        )

        #expect(!policy.canDeferInvalidation(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            promptBlockReason: "missing-prompt-fingerprint",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: snapshot(fieldIdentity: fieldIdentity),
            trustedAnchor: anchor,
            observedContext: inconclusiveWrapper
        ))
        #expect(!policy.canBeginAXCooldownPreservation(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: snapshot(fieldIdentity: fieldIdentity),
            trustedAnchor: anchor,
            observedContext: inconclusiveWrapper,
            hasActiveSuggestionWork: true
        ))
        #expect(!policy.canDeferInvalidation(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            promptBlockReason: "missing-prompt-fingerprint",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: snapshot(fieldIdentity: fieldIdentity),
            trustedAnchor: anchor,
            observedContext: context(
                elementIdentifier: 99,
                role: "AXWebArea",
                fingerprint: FocusedElementFingerprint(windowTitle: "Codex"),
                caretRect: nil,
                elementRect: nil,
                windowIdentifier: nil,
                windowRect: nil
            )
        ))
        #expect(!policy.canDeferInvalidation(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            promptBlockReason: "missing-prompt-fingerprint",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: snapshot(fieldIdentity: fieldIdentity),
            trustedAnchor: anchor,
            observedContext: context(
                elementIdentifier: 99,
                role: "AXWebArea",
                fingerprint: FocusedElementFingerprint(),
                caretRect: nil,
                elementRect: nil,
                windowIdentifier: nil
            )
        ))
    }

    @Test("Accepts a web-area wrapper with matching window bounds and title")
    func acceptsWebAreaWrapperWithMatchingWindowBoundsAndTitle() throws {
        let fieldIdentity = identity()
        let anchor = try #require(policy.anchor(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            context: context(windowIdentifier: nil)
        ))
        let verifiedWrapper = context(
            elementIdentifier: 99,
            role: "AXWebArea",
            fingerprint: FocusedElementFingerprint(windowTitle: "Codex"),
            caretRect: nil,
            elementRect: nil,
            windowIdentifier: nil
        )

        #expect(policy.canDeferInvalidation(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            promptBlockReason: "missing-prompt-fingerprint",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: snapshot(fieldIdentity: fieldIdentity),
            trustedAnchor: anchor,
            observedContext: verifiedWrapper
        ))
    }

    @Test("Production Codex reads retain identity required by wrapper continuity")
    func productionCodexReadsRetainIdentityRequiredByWrapperContinuity() throws {
        let app = RunningApplicationInfo(
            bundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            localizedName: "Codex",
            processIdentifier: 42
        )
        let profile = try #require(CompatibilityProfileStore.mvp.profile(
            for: CodexProofFocusedTargetPolicy.bundleIdentifier
        ))
        let options = FocusedTextReadOptionsPolicy.options(for: app, profile: profile)
        #expect(options.windowReadMode == .identifierOnly)
        #expect(!options.windowReadMode.plan.readsBounds)
        #expect(!options.windowReadMode.plan.allowsFocusedWindowFallback)

        let fieldIdentity = identity()
        let anchor = try #require(policy.anchor(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            context: context()
        ))
        let verifiedWrapper = context(
            elementIdentifier: 99,
            role: "AXWebArea",
            fingerprint: FocusedElementFingerprint(),
            caretRect: nil,
            elementRect: nil
        )

        #expect(policy.canDeferInvalidation(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: app.processIdentifier,
            promptBlockReason: "missing-prompt-fingerprint",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: snapshot(fieldIdentity: fieldIdentity),
            trustedAnchor: anchor,
            observedContext: verifiedWrapper
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

    @Test("Rejects zero-size anchors before missing-bounds continuity")
    func rejectsZeroSizeAnchorsBeforeMissingBoundsContinuity() {
        let fieldIdentity = identity()
        let invalidAnchorContexts = [
            context(elementRect: CGRect(x: 100, y: 620, width: 0, height: 80)),
            context(elementRect: CGRect(x: 100, y: 620, width: 700, height: 0))
        ]

        for invalidContext in invalidAnchorContexts {
            let anchor = policy.anchor(
                appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
                fieldIdentity: fieldIdentity,
                context: invalidContext
            )
            #expect(anchor == nil)
            #expect(!policy.canDeferInvalidation(
                appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
                processIdentifier: 42,
                promptBlockReason: "missing-prompt-bounds",
                currentFieldIdentity: fieldIdentity,
                currentSnapshot: snapshot(fieldIdentity: fieldIdentity),
                trustedAnchor: anchor,
                observedContext: context(caretRect: nil, elementRect: nil)
            ))
        }
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

    @Test("Presentation never reuses an unresolved web-area wrapper")
    func presentationNeverReusesUnresolvedWebAreaWrapper() throws {
        let fieldIdentity = identity()
        let trustedContext = context()
        let anchor = try #require(policy.anchor(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            context: trustedContext
        ))
        let currentSnapshot = snapshot(fieldIdentity: fieldIdentity)
        let wrapper = context(
            role: "AXWebArea",
            fingerprint: FocusedElementFingerprint(windowTitle: "Codex"),
            caretRect: nil,
            elementRect: nil
        )
        let missingBoundsTextArea = context(caretRect: nil, elementRect: nil)

        #expect(policy.presentationRefreshResolution(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            promptBlockReason: "missing-prompt-fingerprint",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: currentSnapshot,
            trustedAnchor: anchor,
            observedContext: wrapper,
            trustedContext: trustedContext
        ) == .retry)
        #expect(policy.presentationRefreshResolution(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            promptBlockReason: "missing-prompt-bounds",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: currentSnapshot,
            trustedAnchor: anchor,
            observedContext: missingBoundsTextArea,
            trustedContext: trustedContext
        ) == .reuseTrustedTextAreaContext)
        #expect(policy.presentationRefreshResolution(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            promptBlockReason: "missing-prompt-fingerprint",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: currentSnapshot,
            trustedAnchor: anchor,
            observedContext: context(
                role: "AXWebArea",
                fingerprint: FocusedElementFingerprint(windowTitle: "Codex"),
                textBeforeCursor: "synthetic prompt changed",
                caretRect: nil,
                elementRect: nil
            ),
            trustedContext: trustedContext
        ) == .reject)
    }

    @Test("Verified transient target preserves work through the full AX cooldown")
    func verifiedTransientTargetPreservesWorkThroughFullAXCooldown() throws {
        let fieldIdentity = identity()
        let trustedContext = context()
        let anchor = try #require(policy.anchor(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            context: trustedContext,
            nowMilliseconds: 100
        ))
        let currentSnapshot = snapshot(fieldIdentity: fieldIdentity)
        let transientWrapper = context(
            role: "AXWebArea",
            fingerprint: FocusedElementFingerprint(windowTitle: "Codex"),
            caretRect: nil,
            elementRect: nil
        )
        #expect(policy.canDeferInvalidation(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            promptBlockReason: "missing-prompt-fingerprint",
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: currentSnapshot,
            trustedAnchor: anchor,
            observedContext: transientWrapper,
            nowMilliseconds: 200
        ))
        #expect(policy.canBeginAXCooldownPreservation(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: currentSnapshot,
            trustedAnchor: anchor,
            observedContext: transientWrapper,
            hasActiveSuggestionWork: true,
            nowMilliseconds: 200
        ))
        #expect(policy.canBeginAXCooldownPreservation(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: currentSnapshot,
            trustedAnchor: anchor,
            observedContext: trustedContext,
            hasActiveSuggestionWork: true,
            nowMilliseconds: 200
        ))

        let preservation = try #require(policy.axCooldownPreservation(
            trustedAnchor: anchor,
            cooldownMilliseconds: 750,
            nowMilliseconds: 200
        ))
        #expect(policy.canPreserveDuringAXCooldown(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: currentSnapshot,
            trustedAnchor: anchor,
            preservation: preservation,
            hasActiveSuggestionWork: true,
            nowMilliseconds: 360
        ))
        #expect(policy.remainingAXCooldownMilliseconds(
            preservation: preservation,
            nowMilliseconds: 360
        ) == 590)
        #expect(policy.canPreserveDuringAXCooldown(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: currentSnapshot,
            trustedAnchor: anchor,
            preservation: preservation,
            hasActiveSuggestionWork: true,
            nowMilliseconds: 950
        ))
        #expect(!policy.canPreserveDuringAXCooldown(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: currentSnapshot,
            trustedAnchor: anchor,
            preservation: preservation,
            hasActiveSuggestionWork: true,
            nowMilliseconds: 951
        ))
    }

    @Test("Cooldown preservation fails closed for changed or inactive requests")
    func cooldownPreservationFailsClosedForChangedOrInactiveRequests() throws {
        let fieldIdentity = identity()
        let anchor = try #require(policy.anchor(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            context: context(),
            nowMilliseconds: 100
        ))
        let preservation = try #require(policy.axCooldownPreservation(
            trustedAnchor: anchor,
            cooldownMilliseconds: 750,
            nowMilliseconds: 200
        ))
        let changedSnapshot = FocusedTextSnapshot(
            fieldIdentity: fieldIdentity,
            textBeforeCursor: "synthetic prompt changed",
            textAfterCursor: ""
        )

        #expect(!policy.canPreserveDuringAXCooldown(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: changedSnapshot,
            trustedAnchor: anchor,
            preservation: preservation,
            hasActiveSuggestionWork: true,
            nowMilliseconds: 300
        ))
        #expect(!policy.canBeginAXCooldownPreservation(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: changedSnapshot,
            trustedAnchor: anchor,
            observedContext: context(),
            hasActiveSuggestionWork: true,
            nowMilliseconds: 300
        ))
        #expect(!policy.canPreserveDuringAXCooldown(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: snapshot(fieldIdentity: fieldIdentity),
            trustedAnchor: anchor,
            preservation: preservation,
            hasActiveSuggestionWork: false,
            nowMilliseconds: 300
        ))
        #expect(!policy.canPreserveDuringAXCooldown(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 43,
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: snapshot(fieldIdentity: fieldIdentity),
            trustedAnchor: anchor,
            preservation: preservation,
            hasActiveSuggestionWork: true,
            nowMilliseconds: 300
        ))
    }

    @Test("Accepts the same Codex prompt when its live text-area identity churns")
    func acceptsStablePromptAcrossIdentityChurn() throws {
        let fieldIdentity = identity()
        let trustedContext = context()
        let anchor = try #require(policy.anchor(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            context: trustedContext,
            nowMilliseconds: 100
        ))
        let currentSnapshot = snapshot(fieldIdentity: fieldIdentity)
        let shownSnapshot = SuggestionAcceptanceSnapshot(
            snapshot: currentSnapshot,
            targetFingerprint: anchor.targetFingerprint,
            selectedTextLength: 0
        )

        #expect(policy.canAcceptStablePrompt(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: currentSnapshot,
            shownSnapshot: shownSnapshot,
            trustedAnchor: anchor,
            observedContext: context(
                elementIdentifier: 99,
                elementRect: CGRect(x: 102, y: 619, width: 702, height: 82)
            ),
            nowMilliseconds: 1_000
        ))
        #expect(!policy.canAcceptStablePrompt(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: currentSnapshot,
            shownSnapshot: shownSnapshot,
            trustedAnchor: anchor,
            observedContext: context(),
            nowMilliseconds: 1_101
        ))
    }

    @Test("Stable prompt acceptance rejects changed sensitive or moved targets")
    func stablePromptAcceptanceRejectsUnsafeTargets() throws {
        let fieldIdentity = identity()
        let anchor = try #require(policy.anchor(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            context: context(),
            nowMilliseconds: 100
        ))
        let currentSnapshot = snapshot(fieldIdentity: fieldIdentity)
        let shownSnapshot = SuggestionAcceptanceSnapshot(
            snapshot: currentSnapshot,
            targetFingerprint: anchor.targetFingerprint,
            selectedTextLength: 0
        )
        let unsafeContexts = [
            context(textBeforeCursor: "synthetic prompt changed"),
            context(textBeforeCursor: "", textAfterCursor: "synthetic prompt"),
            context(selectedTextLength: 1),
            context(elementRect: CGRect(x: 100, y: 500, width: 700, height: 80)),
            context(windowIdentifier: nil, windowRect: nil),
            context(isSecure: true),
            context(role: "AXButton")
        ]

        for observedContext in unsafeContexts {
            #expect(!policy.canAcceptStablePrompt(
                appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
                processIdentifier: 42,
                currentFieldIdentity: fieldIdentity,
                currentSnapshot: currentSnapshot,
                shownSnapshot: shownSnapshot,
                trustedAnchor: anchor,
                observedContext: observedContext,
                nowMilliseconds: 1_000
            ))
        }

        let replacementWindowContext = context(
            elementIdentifier: 99,
            windowIdentifier: 2
        )
        let replacementWindowAnchor = try #require(policy.anchor(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            context: replacementWindowContext,
            nowMilliseconds: 100
        ))
        #expect(!policy.canAcceptStablePrompt(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: currentSnapshot,
            shownSnapshot: shownSnapshot,
            trustedAnchor: replacementWindowAnchor,
            observedContext: replacementWindowContext,
            nowMilliseconds: 1_000
        ))
    }

    @Test("Stable prompt acceptance uses bounds and title when window identity is unavailable")
    func stablePromptAcceptanceUsesAffirmativeWindowFallback() throws {
        let fieldIdentity = identity()
        let trustedContext = context(windowIdentifier: nil)
        let anchor = try #require(policy.anchor(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            context: trustedContext,
            nowMilliseconds: 100
        ))
        let currentSnapshot = snapshot(fieldIdentity: fieldIdentity)
        let shownSnapshot = SuggestionAcceptanceSnapshot(
            snapshot: currentSnapshot,
            targetFingerprint: anchor.targetFingerprint,
            selectedTextLength: 0
        )

        #expect(policy.canAcceptStablePrompt(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: currentSnapshot,
            shownSnapshot: shownSnapshot,
            trustedAnchor: anchor,
            observedContext: trustedContext,
            nowMilliseconds: 1_000
        ))

        let inconclusiveContext = context(
            fingerprint: FocusedElementFingerprint(),
            windowIdentifier: nil
        )
        let inconclusiveAnchor = try #require(policy.anchor(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            context: inconclusiveContext,
            nowMilliseconds: 100
        ))
        let inconclusiveShownSnapshot = SuggestionAcceptanceSnapshot(
            snapshot: currentSnapshot,
            targetFingerprint: inconclusiveAnchor.targetFingerprint,
            selectedTextLength: 0
        )
        #expect(!policy.canAcceptStablePrompt(
            appBundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            currentFieldIdentity: fieldIdentity,
            currentSnapshot: currentSnapshot,
            shownSnapshot: inconclusiveShownSnapshot,
            trustedAnchor: inconclusiveAnchor,
            observedContext: inconclusiveContext,
            nowMilliseconds: 1_000
        ))
    }

    private func identity() -> FocusedFieldIdentity {
        FocusedFieldIdentity(
            bundleIdentifier: CodexProofFocusedTargetPolicy.bundleIdentifier,
            processIdentifier: 42,
            elementIdentifier: 7
        )
    }

    private func snapshot(
        fieldIdentity: FocusedFieldIdentity,
        textBeforeCursor: String = "synthetic prompt",
        textAfterCursor: String = ""
    ) -> FocusedTextSnapshot {
        FocusedTextSnapshot(
            fieldIdentity: fieldIdentity,
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor
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
        textAfterCursor: String = "",
        selectedTextLength: Int = 0,
        caretRect: CGRect? = CGRect(x: 120, y: 650, width: 1, height: 20),
        elementRect: CGRect? = CGRect(x: 100, y: 620, width: 700, height: 80),
        windowIdentifier: Int? = 1,
        windowRect: CGRect? = CGRect(x: 0, y: 0, width: 900, height: 700),
        isSecure: Bool = false
    ) -> FocusedTextContext {
        FocusedTextContext(
            elementIdentifier: elementIdentifier,
            role: role,
            subrole: nil,
            fingerprint: fingerprint,
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor,
            selectedTextLength: selectedTextLength,
            caretRect: caretRect,
            elementRect: elementRect,
            windowRect: windowRect,
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
