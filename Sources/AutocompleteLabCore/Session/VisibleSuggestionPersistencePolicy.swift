import Foundation

public struct VisibleSuggestionPersistencePolicy: Equatable, Sendable {
    public let maximumTransientEmptyContextAgeMilliseconds: Int
    public let maximumSameTextMiddleSplitAgeMilliseconds: Int
    public let maximumObsidianDocumentStartTeleportAgeMilliseconds: Int
    public let maximumPromptProofTargetGeometryChurnAgeMilliseconds: Int

    public init(
        maximumTransientEmptyContextAgeMilliseconds: Int = 1_200,
        maximumSameTextMiddleSplitAgeMilliseconds: Int = 5_000,
        maximumObsidianDocumentStartTeleportAgeMilliseconds: Int = 2_500,
        maximumPromptProofTargetGeometryChurnAgeMilliseconds: Int = 10_000
    ) {
        self.maximumTransientEmptyContextAgeMilliseconds = maximumTransientEmptyContextAgeMilliseconds
        self.maximumSameTextMiddleSplitAgeMilliseconds = maximumSameTextMiddleSplitAgeMilliseconds
        self.maximumObsidianDocumentStartTeleportAgeMilliseconds = maximumObsidianDocumentStartTeleportAgeMilliseconds
        self.maximumPromptProofTargetGeometryChurnAgeMilliseconds = maximumPromptProofTargetGeometryChurnAgeMilliseconds
    }

    public func shouldPreserveAfterActivationBlock(
        blockReason: CompletionActivationBlockReason,
        appBundleIdentifier: String,
        fieldIdentity: FocusedFieldIdentity,
        currentSuggestionBundleIdentifier: String?,
        currentSuggestionFieldIdentity: FocusedFieldIdentity?,
        currentSuggestionTextBeforeCursor: String?,
        currentSuggestionAgeMilliseconds: Int?,
        isInvalidatedByUserTyping: Bool,
        textBeforeCursor: String,
        textAfterCursor: String
    ) -> Bool {
        guard !isInvalidatedByUserTyping,
              currentSuggestionBundleIdentifier == appBundleIdentifier,
              currentSuggestionFieldIdentity == fieldIdentity,
              let currentSuggestionAgeMilliseconds else {
            return false
        }

        let shouldPreserveObsidianTeleport = currentSuggestionAgeMilliseconds <= maximumObsidianDocumentStartTeleportAgeMilliseconds
            && shouldPreserveObsidianDocumentStartTeleport(
                appBundleIdentifier: appBundleIdentifier,
                currentSuggestionTextBeforeCursor: currentSuggestionTextBeforeCursor,
                textBeforeCursor: textBeforeCursor,
                textAfterCursor: textAfterCursor
            )

        switch blockReason {
        case .tooLittleContext:
            if shouldPreserveObsidianTeleport {
                return true
            }

            guard currentSuggestionAgeMilliseconds <= maximumTransientEmptyContextAgeMilliseconds else {
                return false
            }

            return textBeforeCursor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && textAfterCursor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .markdownCodeContext:
            return shouldPreserveObsidianTeleport
        case .middleOfLine:
            guard currentSuggestionAgeMilliseconds <= maximumSameTextMiddleSplitAgeMilliseconds else {
                return false
            }

            return isSameTextMiddleSplit(
                currentSuggestionTextBeforeCursor: currentSuggestionTextBeforeCursor,
                textBeforeCursor: textBeforeCursor,
                textAfterCursor: textAfterCursor
            )
        default:
            return false
        }
    }

    public func shouldPreserveDuringGeometryInvalidation(
        invalidationReason: SuggestionGeometryInvalidationReason?,
        appBundleIdentifier: String,
        fieldIdentity: FocusedFieldIdentity,
        currentSuggestionBundleIdentifier: String?,
        currentSuggestionFieldIdentity: FocusedFieldIdentity?,
        currentSuggestionTextBeforeCursor: String?,
        currentSuggestionAgeMilliseconds: Int?,
        isInvalidatedByUserTyping: Bool,
        textBeforeCursor: String,
        textAfterCursor: String,
        promptProofModeEnabled: Bool = false,
        promptProofBundleIdentifier: String = "",
        promptProofMarker: String = ""
    ) -> Bool {
        guard invalidationReason == .caretChanged || invalidationReason == .textLineChanged else {
            return false
        }

        guard !isInvalidatedByUserTyping,
              currentSuggestionBundleIdentifier == appBundleIdentifier,
              let currentSuggestionAgeMilliseconds else {
            return false
        }

        if shouldPreservePromptProofTargetGeometryChurn(
            proofModeEnabled: promptProofModeEnabled,
            proofBundleIdentifier: promptProofBundleIdentifier,
            proofMarker: promptProofMarker,
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentity: fieldIdentity,
            currentSuggestionFieldIdentity: currentSuggestionFieldIdentity,
            currentSuggestionTextBeforeCursor: currentSuggestionTextBeforeCursor,
            currentSuggestionAgeMilliseconds: currentSuggestionAgeMilliseconds,
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor
        ) {
            return true
        }

        guard currentSuggestionFieldIdentity == fieldIdentity else {
            return false
        }

        if currentSuggestionAgeMilliseconds <= maximumSameTextMiddleSplitAgeMilliseconds,
           currentSuggestionTextBeforeCursor == textBeforeCursor,
           textAfterCursor.isEmpty {
            return true
        }

        if currentSuggestionAgeMilliseconds <= maximumSameTextMiddleSplitAgeMilliseconds,
           isSameTextMiddleSplit(
            currentSuggestionTextBeforeCursor: currentSuggestionTextBeforeCursor,
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor
           ) {
            return true
        }

        guard currentSuggestionAgeMilliseconds <= maximumObsidianDocumentStartTeleportAgeMilliseconds else {
            return false
        }

        return shouldPreserveObsidianDocumentStartTeleport(
            appBundleIdentifier: appBundleIdentifier,
            currentSuggestionTextBeforeCursor: currentSuggestionTextBeforeCursor,
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor
        )
    }

    private func shouldPreserveObsidianDocumentStartTeleport(
        appBundleIdentifier: String,
        currentSuggestionTextBeforeCursor: String?,
        textBeforeCursor: String,
        textAfterCursor: String
    ) -> Bool {
        guard appBundleIdentifier == "md.obsidian",
              let currentSuggestionTextBeforeCursor,
              currentSuggestionTextBeforeCursor.count >= 24,
              textBeforeCursor.trimmingCharacters(in: .whitespacesAndNewlines).count <= 1,
              !textAfterCursor.isEmpty else {
            return false
        }

        return textAfterCursor.hasPrefix(currentSuggestionTextBeforeCursor)
    }

    private func shouldPreservePromptProofTargetGeometryChurn(
        proofModeEnabled: Bool,
        proofBundleIdentifier: String,
        proofMarker: String,
        appBundleIdentifier: String,
        fieldIdentity: FocusedFieldIdentity,
        currentSuggestionFieldIdentity: FocusedFieldIdentity?,
        currentSuggestionTextBeforeCursor: String?,
        currentSuggestionAgeMilliseconds: Int,
        textBeforeCursor: String,
        textAfterCursor: String
    ) -> Bool {
        let marker = proofMarker.trimmingCharacters(in: .whitespacesAndNewlines)
        let proofBundleIdentifier = proofBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)

        guard proofModeEnabled,
              !marker.isEmpty,
              !proofBundleIdentifier.isEmpty,
              appBundleIdentifier == proofBundleIdentifier,
              fieldIdentity.bundleIdentifier == proofBundleIdentifier,
              let currentSuggestionFieldIdentity,
              currentSuggestionFieldIdentity.bundleIdentifier == proofBundleIdentifier,
              currentSuggestionFieldIdentity.processIdentifier == fieldIdentity.processIdentifier,
              currentSuggestionAgeMilliseconds <= maximumPromptProofTargetGeometryChurnAgeMilliseconds,
              let currentSuggestionTextBeforeCursor,
              currentSuggestionTextBeforeCursor.contains(marker),
              currentSuggestionTextBeforeCursor == textBeforeCursor,
              textAfterCursor.isEmpty else {
            return false
        }

        return true
    }

    private func isSameTextMiddleSplit(
        currentSuggestionTextBeforeCursor: String?,
        textBeforeCursor: String,
        textAfterCursor: String
    ) -> Bool {
        !textBeforeCursor.isEmpty
            && !textAfterCursor.isEmpty
            && currentSuggestionTextBeforeCursor.map { textBeforeCursor + textAfterCursor == $0 } == true
    }
}
