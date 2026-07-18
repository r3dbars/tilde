import CoreGraphics
import Foundation
import AutocompleteLabCore
import Testing
@testable import AutocompleteLabApp

@MainActor
@Suite("Focused text context diagnostics host")
struct FocusedTextContextDiagnosticsHostTests {
    @Test("records only redacted focused-context metadata")
    func metadataIsRedactedAndKeepsFixtureHints() {
        let diagnostics = FocusedTextDiagnostics(
            bundleIdentifier: "com.example.editor",
            localizedAppName: "Editor",
            role: "AXTextArea",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(
                title: "secret typed text",
                windowTitle: "Monaco smoke fixture"
            ),
            isSecure: false,
            textBeforeCursorLength: 12,
            textAfterCursorLength: 3,
            selectedRangeDescription: "{12, 0}",
            caretRect: CGRect(x: 1, y: 2, width: 3, height: 4),
            elementRect: nil,
            windowRect: nil,
            windowIdentifier: 9,
            textLineRect: nil,
            capabilities: FocusedTextCapabilities(
                canReadValue: true,
                canReadSelectedTextRange: true,
                canReadBoundsForRange: false,
                canReadAttributedText: false,
                canSetSelectedText: true
            ),
            attributeDump: FocusedElementAttributeDump(
                attributes: [FocusedElementAttributeSummary(
                    name: "AXRole",
                    valueSummary: "AXTextArea",
                    isSettable: false
                )],
                parameterizedAttributes: []
            )
        )

        let metadata = FocusedTextContextDiagnosticsHost().metadata(
            for: diagnostics,
            appBundleIdentifier: "com.example.editor"
        )

        #expect(metadata["app"] == "com.example.editor")
        #expect(metadata["beforeChars"] == "12")
        #expect(metadata["afterChars"] == "3")
        #expect(metadata["monacoHint"] == "true")
        #expect(metadata.values.allSatisfy { !$0.contains("secret typed text") })
        #expect(metadata.values.allSatisfy { !$0.contains("Monaco smoke fixture") })
    }
}
