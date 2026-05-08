import CoreGraphics
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Trust flow harness")
struct TrustFlowHarnessTests {
    @MainActor
    @Test("Poll request present Tab accept and verify emits evidence without raw text")
    func pollRequestPresentAcceptAndVerifyIsEvidenceSafe() throws {
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        let field = fieldIdentity(bundleIdentifier: profile.bundleIdentifier)
        let context = focusedContext(
            textBeforeCursor: "private draft token inst",
            textAfterCursor: ""
        )
        var harness = TrustFlowHarness(profile: profile, fieldIdentity: field)

        harness.requestSuggestion(context: context, requestMode: .wordCompletion)
        let presented = harness.presentSuggestion("ant for later", focusedContext: context)
        let accepted = harness.accept(key: .tab)
        let verified = harness.verifyInsertion(currentTextBeforeCursor: "private draft token instant")
        #expect(presented)
        #expect(accepted)
        #expect(verified)

        #expect(harness.evidence.map(\.kind) == [.requested, .presented, .accepted, .verified])
        #expect(harness.evidence[2].acceptMode == KeyboardAction.acceptNextWord.diagnosticName)
        #expect(harness.evidence[2].acceptedChars == 3)
        #expect(harness.evidence[2].metadata["acceptanceProof"] == "passed")
        #expect(harness.evidence[3].metadata["verificationResult"] == "verified")

        let evidenceText = renderedEvidence(harness.evidence)
        #expect(!evidenceText.contains("private draft token"))
        #expect(!evidenceText.contains("instant"))
        #expect(!evidenceText.contains("ant for later"))
    }

    @MainActor
    @Test("Stale text suppresses before presentation")
    func staleTextSuppressesBeforePresentation() throws {
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        let field = fieldIdentity(bundleIdentifier: profile.bundleIdentifier)
        let requestContext = focusedContext(textBeforeCursor: "Can we", textAfterCursor: "")
        let currentContext = focusedContext(textBeforeCursor: "Can we changed", textAfterCursor: "")
        var harness = TrustFlowHarness(profile: profile, fieldIdentity: field)

        harness.requestSuggestion(context: requestContext, requestMode: .phraseContinuation)
        let presented = harness.presentSuggestion(" make this better", focusedContext: currentContext)
        #expect(!presented)

        #expect(harness.evidence.map(\.kind) == [.requested, .suppressed])
        #expect(harness.evidence.last?.reason == "stale-text")
    }

    @MainActor
    @Test("Marked text composition suppresses before presentation")
    func markedTextCompositionSuppressesBeforePresentation() throws {
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        let field = fieldIdentity(bundleIdentifier: profile.bundleIdentifier)
        let requestContext = focusedContext(textBeforeCursor: "nih", textAfterCursor: "")
        let composingContext = focusedContext(
            textBeforeCursor: "nih",
            textAfterCursor: "",
            hasMarkedText: true
        )
        var harness = TrustFlowHarness(profile: profile, fieldIdentity: field)

        harness.requestSuggestion(context: requestContext, requestMode: .wordCompletion)
        let presented = harness.presentSuggestion("on", focusedContext: composingContext)
        #expect(!presented)

        #expect(harness.evidence.map(\.kind) == [.requested, .suppressed])
        #expect(harness.evidence.last?.reason == "composition-active")
    }

    @MainActor
    @Test("Prompt no-submit hard cap blocks full accept")
    func promptNoSubmitHardCapBlocksFullAccept() throws {
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "com.openai.codex"))
        let field = fieldIdentity(bundleIdentifier: profile.bundleIdentifier)
        let context = focusedContext(
            textBeforeCursor: "AUTOCOMPLETE_LAB_CODEX_PROOF Can we",
            textAfterCursor: "",
            windowTitle: "Codex"
        )
        var harness = TrustFlowHarness(profile: profile, fieldIdentity: field)

        harness.requestSuggestion(context: context, requestMode: .phraseContinuation)
        let presented = harness.presentSuggestion(" make this safer", focusedContext: context)
        let accepted = harness.accept(key: .backtick)
        let verified = harness.verifyInsertion(currentTextBeforeCursor: "AUTOCOMPLETE_LAB_CODEX_PROOF Can we make this safer")
        #expect(presented)
        #expect(!accepted)
        #expect(!verified)

        #expect(harness.evidence.map(\.kind) == [.requested, .presented, .suppressed, .suppressed])
        let fullAcceptBlock = try #require(harness.evidence.dropFirst(2).first)
        #expect(fullAcceptBlock.acceptMode == KeyboardAction.acceptAllVisible.diagnosticName)
        #expect(fullAcceptBlock.reason == "unsupported-full")
        #expect(fullAcceptBlock.metadata["noSubmitHardCap"] == "true")
        #expect(fullAcceptBlock.metadata["fieldSend"] == "false")
        #expect(!harness.evidence.contains { $0.kind == .accepted })
    }

    @MainActor
    @Test("Focus change blocks acceptance before insertion")
    func focusChangeBlocksAcceptanceBeforeInsertion() throws {
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))
        let field = fieldIdentity(bundleIdentifier: profile.bundleIdentifier)
        let context = focusedContext(textBeforeCursor: "Can we", textAfterCursor: "")
        var harness = TrustFlowHarness(profile: profile, fieldIdentity: field)

        harness.requestSuggestion(context: context, requestMode: .phraseContinuation)
        let presented = harness.presentSuggestion(" make this safer", focusedContext: context)
        let accepted = harness.accept(key: .tab, currentFieldMatchesSuggestion: false)
        #expect(presented)
        #expect(!accepted)

        #expect(harness.evidence.map(\.kind) == [.requested, .presented, .suppressed])
        #expect(harness.evidence.last?.reason == "focus-changed")
        #expect(!harness.evidence.contains { $0.kind == .accepted })
    }

    @MainActor
    @Test("Browser action-bearing surface suppresses before presentation")
    func browserActionBearingSurfaceSuppressesBeforePresentation() throws {
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))
        let field = fieldIdentity(bundleIdentifier: profile.bundleIdentifier)
        let context = focusedContext(
            textBeforeCursor: "Can we",
            textAfterCursor: "",
            windowTitle: "ChatGPT"
        )
        var harness = TrustFlowHarness(profile: profile, fieldIdentity: field)

        harness.requestSuggestion(context: context, requestMode: .phraseContinuation)
        let presented = harness.presentSuggestion(
            " make this safer",
            focusedContext: context,
            browserHostedSurfaceDecision: .blocked(BrowserHostedSurfaceBlock(surface: .chatGPT))
        )
        #expect(!presented)

        #expect(harness.evidence.map(\.kind) == [.requested, .suppressed])
        #expect(harness.evidence.last?.reason == "unsupported-browser-surface")
    }
}

private func fieldIdentity(bundleIdentifier: String) -> FocusedFieldIdentity {
    FocusedFieldIdentity(
        bundleIdentifier: bundleIdentifier,
        processIdentifier: 42,
        elementIdentifier: 7
    )
}

private func focusedContext(
    textBeforeCursor: String,
    textAfterCursor: String,
    windowTitle: String? = nil,
    hasMarkedText: Bool = false
) -> FocusedTextContext {
    FocusedTextContext(
        elementIdentifier: 7,
        role: "AXTextArea",
        subrole: nil,
        fingerprint: FocusedElementFingerprint(windowTitle: windowTitle),
        textBeforeCursor: textBeforeCursor,
        textAfterCursor: textAfterCursor,
        selectedTextLength: 0,
        caretRect: CGRect(x: 10, y: 10, width: 1, height: 18),
        elementRect: CGRect(x: 0, y: 0, width: 400, height: 200),
        windowRect: CGRect(x: 0, y: 0, width: 500, height: 300),
        textLineRect: CGRect(x: 10, y: 10, width: 120, height: 18),
        textStyle: nil,
        isSecure: false,
        caretIsSynthetic: false,
        capabilities: FocusedTextCapabilities(
            canReadValue: true,
            canReadSelectedTextRange: true,
            canReadBoundsForRange: true,
            canReadAttributedText: false,
            canSetSelectedText: true,
            hasMarkedText: hasMarkedText
        )
    )
}

private func renderedEvidence(_ evidence: [TrustFlowEvidence]) -> String {
    evidence.map { item in
        [
            item.kind.rawValue,
            item.appBundleIdentifier,
            item.fieldIdentity,
            item.requestMode,
            item.acceptMode,
            item.reason,
            String(item.acceptedChars),
            String(item.visibleChars),
            item.metadata
                .map { "\($0.key)=\($0.value)" }
                .sorted()
                .joined(separator: ",")
        ].joined(separator: "|")
    }.joined(separator: "\n")
}
