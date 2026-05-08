import AutocompleteLabCore
import Foundation

enum TrustFlowEvidenceKind: String, Equatable, Sendable {
    case requested
    case presented
    case suppressed
    case accepted
    case verified
}

struct TrustFlowEvidence: Equatable, Sendable {
    let kind: TrustFlowEvidenceKind
    let appBundleIdentifier: String
    let fieldIdentity: String
    let requestMode: String
    let acceptMode: String
    let reason: String
    let acceptedChars: Int
    let visibleChars: Int
    let metadata: [String: String]
}

@MainActor
struct TrustFlowHarness {
    private let profile: CompatibilityProfile
    private let fieldIdentity: FocusedFieldIdentity
    private let fieldClassification: AXFieldClassification
    private let presentationRefreshPolicy = SuggestionPresentationRefreshPolicy()
    private let acceptanceProofPolicy = SuggestionAcceptanceProofPolicy()
    private let insertionVerification = InsertionVerification()
    private let keyboardActionRouter: KeyboardActionRouter
    private var suggestionOrchestrator: SuggestionOrchestrator
    private var suggestionSession = SuggestionSession()
    private var request: CompletionRequest?
    private var pendingVerification: TrustFlowPendingVerification?

    private(set) var evidence: [TrustFlowEvidence] = []

    init(
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity,
        fieldClassification: AXFieldClassification = AXFieldClassification(kind: .multilineCompose, reason: "trust-flow-harness"),
        keyboardShortcutConfiguration: KeyboardShortcutConfiguration = .default
    ) {
        self.profile = profile
        self.fieldIdentity = fieldIdentity
        self.fieldClassification = fieldClassification
        self.keyboardActionRouter = KeyboardActionRouter(shortcutConfiguration: keyboardShortcutConfiguration)
        self.suggestionOrchestrator = SuggestionOrchestrator(engine: TrustFlowCompletionEngine())
    }

    mutating func requestSuggestion(
        context: FocusedTextContext,
        requestMode: CompletionRequestMode
    ) {
        let orchestration = suggestionOrchestrator.beginRequest(SuggestionRequestInput(
            context: context,
            appBundleIdentifier: profile.bundleIdentifier,
            fieldIdentity: fieldIdentity,
            fieldClassification: fieldClassification,
            acceptedTextStyleSketch: nil,
            maxVisibleWords: 4,
            requestMode: requestMode,
            suggestionAggressiveness: .quiet
        ))
        request = orchestration.request
        evidence.append(event(
            kind: .requested,
            requestMode: requestMode,
            metadata: [
                "fieldKind": fieldClassification.kind.rawValue,
                "fieldKindReason": fieldClassification.reason
            ]
        ))
    }

    @discardableResult
    mutating func presentSuggestion(
        _ suggestionText: String,
        focusedContext: FocusedTextContext,
        frontmostAppMatchesExpected: Bool = true,
        currentFieldIdentity: FocusedFieldIdentity? = nil,
        terminalHostBlockReason: String? = nil,
        promptCanSuggest: Bool = true,
        browserHostedSurfaceDecision: BrowserHostedSurfaceDecision = .allowed
    ) -> Bool {
        guard let request else {
            evidence.append(event(kind: .suppressed, reason: "missing-request"))
            return false
        }

        let suggestion = CompletionSuggestion(text: suggestionText, maxVisibleWords: request.maxVisibleWords)
        let adjustedContext: FocusedTextContext?
        let adjustedFieldIdentity: FocusedFieldIdentity?
        if frontmostAppMatchesExpected,
           !focusedContext.isSecure,
           focusedContext.selectedTextLength == 0,
           !focusedContext.capabilities.hasMarkedText,
           terminalHostBlockReason == nil,
           promptCanSuggest,
           browserHostedSurfaceDecision.canSuggest {
            adjustedContext = focusedContext
            adjustedFieldIdentity = currentFieldIdentity ?? fieldIdentity
        } else {
            adjustedContext = nil
            adjustedFieldIdentity = nil
        }

        let decision = presentationRefreshPolicy.decision(for: SuggestionPresentationRefreshInput(
            request: request,
            expectedFieldIdentity: fieldIdentity,
            frontmostAppMatchesExpected: frontmostAppMatchesExpected,
            rawContext: focusedContext,
            terminalHostBlockReason: terminalHostBlockReason,
            promptCanSuggest: promptCanSuggest,
            browserHostedSurfaceDecision: browserHostedSurfaceDecision,
            adjustedContext: adjustedContext,
            adjustedFieldIdentity: adjustedFieldIdentity
        ))

        switch decision {
        case .allow:
            suggestionSession.present(suggestion)
            evidence.append(event(
                kind: .presented,
                requestMode: request.mode,
                visibleChars: suggestion.visibleText.count,
                metadata: [
                    "visibleWords": String(suggestion.visibleWordCount)
                ]
            ))
            return true

        case let .block(reason):
            suggestionSession.dismiss()
            evidence.append(event(
                kind: .suppressed,
                requestMode: request.mode,
                reason: reason,
                visibleChars: suggestion.visibleText.count
            ))
            return false
        }
    }

    @discardableResult
    mutating func accept(
        key: AutocompleteKey,
        currentFieldMatchesSuggestion: Bool = true,
        currentTextBeforeCursor: String? = nil,
        currentTextAfterCursor: String? = nil
    ) -> Bool {
        guard let request else {
            evidence.append(event(kind: .suppressed, reason: "missing-request"))
            return false
        }

        let action = keyboardActionRouter.action(
            for: key,
            hasVisibleSuggestion: suggestionSession.hasVisibleSuggestion
        )
        guard action.insertsSuggestionText else {
            evidence.append(event(
                kind: .suppressed,
                requestMode: request.mode,
                acceptMode: action.diagnosticName,
                reason: "pass-through"
            ))
            return false
        }

        guard currentFieldMatchesSuggestion else {
            suggestionSession.dismiss()
            evidence.append(event(
                kind: .suppressed,
                requestMode: request.mode,
                acceptMode: action.diagnosticName,
                reason: "focus-changed"
            ))
            return false
        }

        if let currentTextBeforeCursor,
           currentTextBeforeCursor != request.textBeforeCursor
            || (currentTextAfterCursor ?? request.textAfterCursor) != request.textAfterCursor {
            suggestionSession.dismiss()
            evidence.append(event(
                kind: .suppressed,
                requestMode: request.mode,
                acceptMode: action.diagnosticName,
                reason: "stale-text-at-accept"
            ))
            return false
        }

        if action == .acceptNextWord, !profile.supportsOneWordAcceptance {
            evidence.append(event(
                kind: .suppressed,
                requestMode: request.mode,
                acceptMode: action.diagnosticName,
                reason: "unsupported-one-word"
            ))
            return false
        }
        if action == .acceptAllVisible, !profile.supportsFullAcceptance {
            evidence.append(event(
                kind: .suppressed,
                requestMode: request.mode,
                acceptMode: action.diagnosticName,
                reason: "unsupported-full",
                metadata: [
                    "noSubmitHardCap": String(profile.hardCaps.contains(.noSubmitProofRequired)),
                    "fieldSend": "false"
                ]
            ))
            return false
        }

        let visibleText = suggestionSession.visibleSuggestion?.visibleText
        let acceptedText: String?
        switch action {
        case .acceptNextWord:
            acceptedText = suggestionSession.nextWordAcceptance()
        case .acceptAllVisible:
            acceptedText = suggestionSession.allVisibleAcceptance()
        case .dismiss, .passThrough, .undoAcceptedInsertion:
            acceptedText = nil
        }

        guard let acceptedText else {
            evidence.append(event(
                kind: .suppressed,
                requestMode: request.mode,
                acceptMode: action.diagnosticName,
                reason: "missing-accepted-text"
            ))
            return false
        }

        guard case let .allowed(proof) = acceptanceProofPolicy.decision(
            action: action,
            acceptedText: acceptedText,
            visibleText: visibleText
        ) else {
            evidence.append(event(
                kind: .suppressed,
                requestMode: request.mode,
                acceptMode: action.diagnosticName,
                reason: "acceptance-proof-failed"
            ))
            return false
        }

        switch action {
        case .acceptNextWord:
            suggestionSession.commitNextWordAcceptance(acceptedText, keepsResidual: false)
        case .acceptAllVisible:
            suggestionSession.commitAllVisibleAcceptance(acceptedText)
        case .dismiss, .passThrough, .undoAcceptedInsertion:
            break
        }

        pendingVerification = TrustFlowPendingVerification(
            requestMode: request.mode,
            acceptedText: acceptedText,
            previousTextBeforeCursor: request.textBeforeCursor,
            previousTextAfterCursor: request.textAfterCursor,
            acceptMode: action.diagnosticName
        )
        evidence.append(event(
            kind: .accepted,
            requestMode: request.mode,
            acceptMode: action.diagnosticName,
            acceptedChars: acceptedText.count,
            visibleChars: visibleText?.count ?? 0,
            metadata: proof.traceMetadata
        ))
        return true
    }

    @discardableResult
    mutating func verifyInsertion(
        currentTextBeforeCursor: String,
        currentTextAfterCursor: String = ""
    ) -> Bool {
        guard let pendingVerification else {
            evidence.append(event(kind: .suppressed, reason: "missing-verification-baseline"))
            return false
        }

        let result = insertionVerification.verify(
            previousTextBeforeCursor: pendingVerification.previousTextBeforeCursor,
            acceptedText: pendingVerification.acceptedText,
            currentTextBeforeCursor: currentTextBeforeCursor,
            previousTextAfterCursor: pendingVerification.previousTextAfterCursor,
            currentTextAfterCursor: currentTextAfterCursor
        )
        if result.isVerified {
            evidence.append(event(
                kind: .verified,
                requestMode: pendingVerification.requestMode,
                acceptMode: pendingVerification.acceptMode,
                acceptedChars: pendingVerification.acceptedText.count,
                metadata: [
                    "verificationResult": String(describing: result)
                ]
            ))
            self.pendingVerification = nil
            return true
        }

        evidence.append(event(
            kind: .suppressed,
            requestMode: pendingVerification.requestMode,
            acceptMode: pendingVerification.acceptMode,
            reason: "insert-verification-failed",
            acceptedChars: pendingVerification.acceptedText.count,
            metadata: [
                "verificationResult": String(describing: result)
            ]
        ))
        return false
    }

    private func event(
        kind: TrustFlowEvidenceKind,
        requestMode: CompletionRequestMode? = nil,
        acceptMode: String = "",
        reason: String = "",
        acceptedChars: Int = 0,
        visibleChars: Int = 0,
        metadata: [String: String] = [:]
    ) -> TrustFlowEvidence {
        TrustFlowEvidence(
            kind: kind,
            appBundleIdentifier: profile.bundleIdentifier,
            fieldIdentity: fieldIdentity.traceDescription,
            requestMode: requestMode?.rawValue ?? request?.mode.rawValue ?? "",
            acceptMode: acceptMode,
            reason: reason,
            acceptedChars: acceptedChars,
            visibleChars: visibleChars,
            metadata: metadata
        )
    }
}

private struct TrustFlowPendingVerification {
    let requestMode: CompletionRequestMode
    let acceptedText: String
    let previousTextBeforeCursor: String
    let previousTextAfterCursor: String
    let acceptMode: String
}

private struct TrustFlowCompletionEngine: CompletionEngine {
    func suggestion(for request: CompletionRequest) async throws -> CompletionSuggestion? {
        nil
    }
}
