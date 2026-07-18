import Foundation

/// Records metadata-only diagnostics when an AX focused-text read has no context.
@MainActor
final class FocusedTextContextDiagnosticsHost {
    func recordMissingContext(
        app: RunningApplicationInfo,
        diagnostics: FocusedTextDiagnostics?
    ) {
        guard let diagnostics else {
            DiagnosticsLog.shared.record(
                "focused-text-context-missing",
                metadata: [
                    "app": app.bundleIdentifier,
                    "diagnostics": "unavailable"
                ]
            )
            return
        }

        DiagnosticsLog.shared.record(
            "focused-text-context-missing",
            metadata: metadata(for: diagnostics, appBundleIdentifier: app.bundleIdentifier)
        )
    }

    func metadata(
        for diagnostics: FocusedTextDiagnostics,
        appBundleIdentifier: String
    ) -> [String: String] {
        let searchable = diagnostics.fingerprint.searchableText
        return [
            "app": appBundleIdentifier,
            "role": diagnostics.role ?? "none",
            "subrole": diagnostics.subrole ?? "none",
            "selectedRange": diagnostics.selectedRangeDescription,
            "isSecure": String(diagnostics.isSecure),
            "beforeChars": String(diagnostics.textBeforeCursorLength),
            "afterChars": String(diagnostics.textAfterCursorLength),
            "hasCaretRect": String(diagnostics.caretRect != nil),
            "hasElementRect": String(diagnostics.elementRect != nil),
            "hasWindowRect": String(diagnostics.windowRect != nil),
            "canReadValue": String(diagnostics.capabilities.canReadValue),
            "canReadRange": String(diagnostics.capabilities.canReadSelectedTextRange),
            "canReadBounds": String(diagnostics.capabilities.canReadBoundsForRange),
            "canSetSelectedText": String(diagnostics.capabilities.canSetSelectedText),
            "chromeSmokeHint": String(searchable.contains("autocomplete lab chrome")
                && searchable.contains("smoke")),
            "monacoHint": String(searchable.contains("monaco")),
            "prosemirrorHint": String(searchable.contains("prosemirror")),
            "attributeNames": diagnostics.attributeDump.attributes
                .map(\.name)
                .joined(separator: ",")
        ]
    }
}
