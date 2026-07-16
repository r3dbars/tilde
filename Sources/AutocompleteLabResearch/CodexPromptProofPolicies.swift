import AutocompleteLabCore
import CoreGraphics

struct ProofRunningApplicationInfo: Equatable, Sendable {
    let bundleIdentifier: String
    let localizedName: String
    let processIdentifier: Int32
}

struct ProofFocusedTextContext: Equatable, Sendable {
    let role: String?
    let subrole: String?
    let fingerprint: FocusedElementFingerprint
    let textBeforeCursor: String
    let textAfterCursor: String
    let selectedTextLength: Int
    let caretRect: CGRect?
    let elementRect: CGRect?
    let windowRect: CGRect?
    let windowIdentifier: Int?
    let isSecure: Bool
}

struct CodexProofFocusedTargetPolicy {
    static let bundleIdentifier = "com.openai.codex"
    static let marker = "AUTOCOMPLETE_LAB_CODEX_PROOF"

    static func allowsOneWordProofRequestMode(_ requestMode: CompletionRequestMode?) -> Bool {
        requestMode == .wordCompletion || requestMode == .phraseContinuation
    }

    static func allowsPromptProofProfile(_ profile: CompatibilityProfile) -> Bool {
        profile.bundleIdentifier == bundleIdentifier
            && profile.supportsOneWordAcceptance
            && profile.insertionMode == .axValueReplacement
            && (
                (!profile.supportsFullAcceptance && profile.requiresNoSubmitAcceptanceProof)
                    || (profile.supportsFullAcceptance && !profile.requiresNoSubmitAcceptanceProof)
            )
    }

    func matches(
        app: ProofRunningApplicationInfo,
        profile: CompatibilityProfile,
        suggestionBundleIdentifier: String?,
        requestMode: CompletionRequestMode?,
        expectedFieldIdentity: FocusedFieldIdentity,
        snapshot: FocusedTextSnapshot,
        focusedContext: ProofFocusedTextContext,
        focusedFieldIdentity: FocusedFieldIdentity,
        proofModeEnabled: Bool,
        expectedFocusedText: String? = nil,
        shownTargetFingerprint: FocusedTargetFingerprint? = nil
    ) -> Bool {
        guard suggestionBundleIdentifier == Self.bundleIdentifier,
              Self.allowsOneWordProofRequestMode(requestMode),
              Self.allowsPromptProofProfile(profile),
              proofModeEnabled,
              app.bundleIdentifier == Self.bundleIdentifier,
              app.processIdentifier == expectedFieldIdentity.processIdentifier,
              snapshot.fieldIdentity == expectedFieldIdentity,
              snapshot.textBeforeCursor.contains(Self.marker),
              snapshot.textAfterCursor.isEmpty,
              focusedContext.role == "AXTextArea",
              focusedContext.selectedTextLength == 0,
              focusedContext.elementRect != nil,
              !focusedContext.isSecure,
              focusedContext.textBeforeCursor.contains(Self.marker),
              focusedContext.textAfterCursor.isEmpty else {
            return false
        }

        let focusedText = focusedContext.textBeforeCursor + focusedContext.textAfterCursor
        let targetText = expectedFocusedText ?? snapshot.textBeforeCursor + snapshot.textAfterCursor
        guard targetText.contains(Self.marker), focusedText == targetText else {
            return false
        }
        if focusedFieldIdentity == expectedFieldIdentity {
            return true
        }
        guard focusedFieldIdentity.bundleIdentifier == expectedFieldIdentity.bundleIdentifier,
              focusedFieldIdentity.processIdentifier == expectedFieldIdentity.processIdentifier,
              let shownTargetFingerprint else {
            return false
        }

        let focusedTargetFingerprint = FocusedTargetFingerprint(
            role: focusedContext.role,
            subrole: focusedContext.subrole,
            elementFingerprint: focusedContext.fingerprint,
            windowIdentifier: focusedContext.windowIdentifier,
            elementRect: focusedContext.elementRect,
            windowRect: focusedContext.windowRect,
            caretRect: focusedContext.caretRect,
            textBeforeCursor: focusedContext.textBeforeCursor,
            textAfterCursor: focusedContext.textAfterCursor
        )
        return targetGeometryMatches(shown: shownTargetFingerprint, focused: focusedTargetFingerprint)
    }

    private func targetGeometryMatches(
        shown: FocusedTargetFingerprint,
        focused: FocusedTargetFingerprint,
        maxGeometryDelta: Int = 4
    ) -> Bool {
        let expected = shown.postInsertionScope
        let actual = focused.postInsertionScope
        guard expected.role == actual.role, expected.subrole == actual.subrole else {
            return false
        }
        if let expectedWindowIdentifier = expected.windowIdentifier,
           let actualWindowIdentifier = actual.windowIdentifier,
           expectedWindowIdentifier != actualWindowIdentifier {
            return false
        }
        if let expectedWindowBounds = expected.windowBounds,
           let actualWindowBounds = actual.windowBounds,
           expectedWindowBounds != actualWindowBounds {
            return false
        }
        guard let expectedBounds = expected.elementBounds,
              let actualBounds = actual.elementBounds else {
            return expected.elementBounds == actual.elementBounds
        }
        return abs(expectedBounds.x - actualBounds.x) <= maxGeometryDelta
            && abs(expectedBounds.y - actualBounds.y) <= maxGeometryDelta
            && abs(expectedBounds.width - actualBounds.width) <= maxGeometryDelta
            && expectedBounds.height > 0
            && actualBounds.height > 0
    }
}

struct PromptProofFieldIdentityRefreshPolicy {
    func canTrustRefresh(
        requestFieldIdentity: FocusedFieldIdentity,
        refreshedFieldIdentity: FocusedFieldIdentity,
        profile: CompatibilityProfile,
        proofModeEnabled: Bool,
        allowsFullAcceptNoSubmitProofProfile: Bool
    ) -> Bool {
        guard profile.promptAppSafetyMode == .wordOnly,
              proofModeEnabled,
              requestFieldIdentity.bundleIdentifier == refreshedFieldIdentity.bundleIdentifier,
              requestFieldIdentity.processIdentifier == refreshedFieldIdentity.processIdentifier else {
            return false
        }
        return profile.requiresNoSubmitAcceptanceProof || allowsFullAcceptNoSubmitProofProfile
    }
}
