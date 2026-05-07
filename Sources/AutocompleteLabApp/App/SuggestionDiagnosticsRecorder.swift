import AutocompleteLabCore
import Foundation

struct SuggestionDiagnosticsRecorder {
    var recordDiagnostics: (String, [String: String]) -> Void = { event, metadata in
        DiagnosticsLog.shared.record(event, metadata: metadata)
    }

    private var blockLogGate = SuggestionBlockLogGate()

    init(recordDiagnostics: @escaping (String, [String: String]) -> Void = { event, metadata in
        DiagnosticsLog.shared.record(event, metadata: metadata)
    }) {
        self.recordDiagnostics = recordDiagnostics
    }

    mutating func resetBlockedSuggestionGate() {
        blockLogGate.reset()
    }

    func traceGeometryMetadata(
        context: FocusedTextContext,
        renderMode: SuggestionRenderMode,
        updateSource: FocusedTextUpdateSource? = nil
    ) -> [String: String] {
        var metadata = [
            "effectiveRenderMode": renderMode.rawValue,
            "hasCaretRect": String(context.caretRect != nil),
            "caretIsSynthetic": String(context.caretIsSynthetic),
            "hasElementRect": String(context.elementRect != nil),
            "hasWindowRect": String(context.windowRect != nil),
            "visibleCharacterRange": context.visibleCharacterRange.map { "\($0.location):\($0.length)" } ?? "missing",
            "insertionPointLineNumber": context.insertionPointLineNumber.map(String.init) ?? "missing",
            "canReadBounds": String(context.capabilities.canReadBoundsForRange),
            "canReadVisibleRange": String(context.capabilities.canReadVisibleCharacterRange),
            "canReadInsertionLine": String(context.capabilities.canReadInsertionPointLineNumber),
            "axReadErrorCount": String(context.axReadErrors.count),
            "axCannotCompleteCount": String(context.axReadErrors.filter(\.isTimeoutOrCannotComplete).count)
        ]

        if let updateSource {
            metadata.merge(traceUpdateSourceMetadata(updateSource)) { current, _ in current }
        }

        return metadata
    }

    func traceUpdateSourceMetadata(_ updateSource: FocusedTextUpdateSource) -> [String: String] {
        ["updateSource": updateSource.rawValue]
    }

    func recordSuggestionEvent(
        _ event: String,
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        metadata: [String: String] = [:]
    ) {
        var safeMetadata = metadata
        safeMetadata["app"] = profile.bundleIdentifier
        safeMetadata["renderMode"] = profile.renderMode.rawValue
        safeMetadata["insertionMode"] = profile.insertionMode.rawValue
        safeMetadata["fieldIdentityMode"] = profile.fieldIdentityMode.rawValue
        safeMetadata["role"] = context.role ?? "unknown"
        safeMetadata["subrole"] = context.subrole ?? "none"
        safeMetadata["beforeChars"] = String(context.textBeforeCursor.count)
        safeMetadata["afterChars"] = String(context.textAfterCursor.count)
        safeMetadata["hasCaretRect"] = String(context.caretRect != nil)
        safeMetadata["hasElementRect"] = String(context.elementRect != nil)
        safeMetadata["hasWindowRect"] = String(context.windowRect != nil)
        safeMetadata["canReadValue"] = String(context.capabilities.canReadValue)
        safeMetadata["canReadRange"] = String(context.capabilities.canReadSelectedTextRange)
        safeMetadata["canReadBounds"] = String(context.capabilities.canReadBoundsForRange)
        safeMetadata["canSetSelectedText"] = String(context.capabilities.canSetSelectedText)
        safeMetadata["canReadVisibleRange"] = String(context.capabilities.canReadVisibleCharacterRange)
        safeMetadata["canReadInsertionLine"] = String(context.capabilities.canReadInsertionPointLineNumber)
        safeMetadata["visibleCharacterRange"] = context.visibleCharacterRange.map { "\($0.location):\($0.length)" } ?? "missing"
        safeMetadata["insertionPointLineNumber"] = context.insertionPointLineNumber.map(String.init) ?? "missing"
        safeMetadata["axReadErrorCount"] = String(context.axReadErrors.count)
        safeMetadata["axCannotCompleteCount"] = String(context.axReadErrors.filter(\.isTimeoutOrCannotComplete).count)

        recordDiagnostics(event, safeMetadata)
    }

    mutating func recordBlockedSuggestionEvent(
        _ event: String,
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity,
        metadata: [String: String] = [:]
    ) {
        let signature = blockedSuggestionSignature(
            context: context,
            profile: profile,
            fieldIdentity: fieldIdentity,
            metadata: metadata
        )

        guard blockLogGate.shouldRecord(signature: signature) else {
            return
        }

        recordSuggestionEvent(event, context: context, profile: profile, metadata: metadata)
    }

    func blockedSuggestionSignature(
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity,
        metadata: [String: String]
    ) -> String {
        [
            profile.bundleIdentifier,
            String(fieldIdentity.processIdentifier),
            String(fieldIdentity.elementIdentifier),
            metadata["reason"] ?? "unknown",
            metadata["readinessStage"] ?? "none",
            String(context.textBeforeCursor.count),
            String(context.textAfterCursor.count)
        ].joined(separator: "|")
    }
}
