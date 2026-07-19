import AutocompleteLabCore
import Foundation

struct ResidualSuggestionPlacement {
    static func shiftedCaretRect(
        from caretRect: CGRect,
        horizontalOffset: CGFloat,
        clippingRect: CGRect?
    ) -> CGRect? {
        guard horizontalOffset != 0, horizontalOffset.isFinite else {
            return nil
        }

        let shiftedCaretRect = caretRect.offsetBy(dx: horizontalOffset, dy: 0)
        if let clippingRect,
           (shiftedCaretRect.minX < clippingRect.minX
               || shiftedCaretRect.maxX > clippingRect.maxX) {
            return nil
        }
        return shiftedCaretRect
    }

    static func advancedCaretRect(
        from caretRect: CGRect,
        acceptedTextWidth: CGFloat,
        clippingRect: CGRect?
    ) -> CGRect? {
        guard acceptedTextWidth > 0, acceptedTextWidth.isFinite else {
            return nil
        }
        return shiftedCaretRect(
            from: caretRect,
            horizontalOffset: acceptedTextWidth,
            clippingRect: clippingRect
        )
    }
}

@MainActor
struct SuggestionPresentationPromptMatch {
    let canSuggest: Bool
    let reason: String
}

@MainActor
struct SuggestionPresentationRefreshHostDependencies {
    let frontmostApplication: () -> RunningApplicationInfo?
    let focusedTextContext: (RunningApplicationInfo, CompatibilityProfile) -> FocusedTextContext?
    let frontmostAppMatchesSuggestion: (RunningApplicationInfo, String, CompatibilityProfile) -> Bool
    let terminalHostProofBlockReason: (RunningApplicationInfo, FocusedTextContext, CompatibilityProfile) -> String?
    let promptTextAreaMatch: (String, FocusedTextContext) -> SuggestionPresentationPromptMatch
    let continuityHost: CodexPromptTargetContinuityHost
    let currentFieldIdentity: () -> FocusedFieldIdentity?
    let lastTextSnapshot: () -> FocusedTextSnapshot?
    let cancelAndRearmCodexPromptTargetWork: (
        RunningApplicationInfo,
        FocusedTextContext,
        CompatibilityProfile,
        String,
        String
    ) -> Void
    let presentationAdjustedContext: (
        FocusedTextContext,
        RunningApplicationInfo,
        CompatibilityProfile,
        FocusedTextSnapshot?
    ) -> FocusedTextContext?
    let fieldIdentity: (RunningApplicationInfo, FocusedTextContext, CompatibilityProfile) -> FocusedFieldIdentity?
    let canTrustPromptProofFieldIdentityRefresh: (
        FocusedFieldIdentity,
        FocusedFieldIdentity,
        CompatibilityProfile
    ) -> Bool
    let recordDiagnostic: (String, [String: String]) -> Void
}

/// Owns the AX and prompt-target freshness checks that happen immediately before
/// presentation. It returns only a trusted context or a privacy-safe suppression reason;
/// presentation and native rendering remain outside this host.
@MainActor
final class SuggestionPresentationRefreshHost {
    private let dependencies: SuggestionPresentationRefreshHostDependencies

    init(dependencies: SuggestionPresentationRefreshHostDependencies) {
        self.dependencies = dependencies
    }

    func refresh(
        for request: CompletionRequest,
        requestContext: FocusedTextContext,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity
    ) -> (context: FocusedTextContext?, reason: String?) {
        let expectedBundleIdentifier = request.appBundleIdentifier ?? profile.bundleIdentifier
        guard let frontmostApp = dependencies.frontmostApplication(),
              dependencies.frontmostAppMatchesSuggestion(
                  frontmostApp,
                  expectedBundleIdentifier,
                  profile
              ) else {
            return (nil, "stale-app")
        }

        guard let rawContext = dependencies.focusedTextContext(frontmostApp, profile),
              !rawContext.isSecure,
              rawContext.selectedTextLength == 0 else {
            return (nil, "stale-focused-context")
        }

        if expectedBundleIdentifier != "com.openai.codex",
           dependencies.terminalHostProofBlockReason(frontmostApp, rawContext, profile) != nil {
            return (nil, "stale-terminal-host-proof")
        }

        let promptMatch = dependencies.promptTextAreaMatch(
            frontmostApp.bundleIdentifier,
            rawContext
        )
        if !promptMatch.canSuggest {
            let snapshot = dependencies.lastTextSnapshot()
            let requestMatchesCurrentSnapshot = snapshot?.fieldIdentity == fieldIdentity
                && snapshot?.textBeforeCursor == request.textBeforeCursor
                && snapshot?.textAfterCursor == request.textAfterCursor
            let resolution = requestMatchesCurrentSnapshot
                ? dependencies.continuityHost.presentationRefreshResolution(
                    app: frontmostApp,
                    promptBlockReason: promptMatch.reason,
                    currentFieldIdentity: dependencies.currentFieldIdentity(),
                    currentSnapshot: snapshot,
                    observedContext: rawContext,
                    trustedContext: requestContext
                )
                : .reject
            guard resolution != .reject else {
                return (nil, "stale-prompt-target")
            }
            if resolution == .cancelAndRetry {
                dependencies.cancelAndRearmCodexPromptTargetWork(
                    frontmostApp,
                    rawContext,
                    profile,
                    promptMatch.reason,
                    "presentation-refresh"
                )
                return (nil, "quarantined-codex-prompt-target")
            }

            dependencies.recordDiagnostic(
                resolution == .reuseTrustedTextAreaContext
                    ? "codex-prompt-target-bounds-reused"
                    : "codex-prompt-target-refresh-retry-needed",
                [
                    "app": frontmostApp.bundleIdentifier,
                    "reason": promptMatch.reason,
                    "role": rawContext.role ?? "unknown",
                    "beforeChars": String(rawContext.textBeforeCursor.count),
                    "afterChars": String(rawContext.textAfterCursor.count)
                ]
            )
            return resolution == .reuseTrustedTextAreaContext
                ? (requestContext, nil)
                : (nil, "transient-codex-prompt-target")
        }

        guard let context = dependencies.presentationAdjustedContext(
            rawContext,
            frontmostApp,
            profile,
            dependencies.lastTextSnapshot()
        ) else {
            return (nil, "stale-focused-context")
        }
        guard context.textBeforeCursor.hasPrefix(request.textBeforeCursor),
              context.textAfterCursor == request.textAfterCursor else {
            return (nil, "stale-text")
        }

        guard let refreshedFieldIdentity = dependencies.fieldIdentity(frontmostApp, context, profile) else {
            return (nil, "stale-field")
        }
        if refreshedFieldIdentity != fieldIdentity {
            guard dependencies.canTrustPromptProofFieldIdentityRefresh(
                fieldIdentity,
                refreshedFieldIdentity,
                profile
            ) else {
                return (nil, "stale-field")
            }
            dependencies.recordDiagnostic(
                "prompt-proof-field-identity-refresh-relaxed",
                [
                    "app": profile.bundleIdentifier,
                    "requestFieldIdentity": fieldIdentity.traceDescription,
                    "refreshedFieldIdentity": refreshedFieldIdentity.traceDescription
                ]
            )
        }

        return (context, nil)
    }
}
