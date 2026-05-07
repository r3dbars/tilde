import AutocompleteLabCore
import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Suggestion diagnostics recorder")
struct SuggestionDiagnosticsRecorderTests {
    @Test("Trace geometry metadata records source, geometry, and AX health counts")
    func traceGeometryMetadataRecordsSourceGeometryAndAXHealthCounts() {
        let recorder = SuggestionDiagnosticsRecorder()
        let context = focusedTextContext(
            textBeforeCursor: "hello",
            textAfterCursor: " world",
            caretRect: CGRect(x: 10, y: 20, width: 1, height: 16),
            visibleCharacterRange: AccessibilityCharacterRange(location: 4, length: 20),
            insertionPointLineNumber: 2,
            axReadErrors: [
                AXAttributeReadError(attribute: "AXBoundsForRange", code: "cannotComplete", isTimeoutOrCannotComplete: true),
                AXAttributeReadError(attribute: "AXVisibleCharacterRange", code: "failure", isTimeoutOrCannotComplete: false)
            ]
        )

        let metadata = recorder.traceGeometryMetadata(
            context: context,
            renderMode: .inlineAdjacent,
            updateSource: .observer
        )

        #expect(metadata["effectiveRenderMode"] == "inlineAdjacent")
        #expect(metadata["updateSource"] == "observer")
        #expect(metadata["hasCaretRect"] == "true")
        #expect(metadata["visibleCharacterRange"] == "4:20")
        #expect(metadata["insertionPointLineNumber"] == "2")
        #expect(metadata["axReadErrorCount"] == "2")
        #expect(metadata["axCannotCompleteCount"] == "1")
    }

    @Test("Suggestion events record counts and capabilities without raw text")
    func suggestionEventsRecordCountsAndCapabilitiesWithoutRawText() {
        var events: [(String, [String: String])] = []
        let recorder = SuggestionDiagnosticsRecorder { event, metadata in
            events.append((event, metadata))
        }

        recorder.recordSuggestionEvent(
            "suggestion-presented",
            context: focusedTextContext(textBeforeCursor: "secret words", textAfterCursor: "after"),
            profile: compatibilityProfile(),
            metadata: ["reason": "test"]
        )

        #expect(events.count == 1)
        #expect(events[0].0 == "suggestion-presented")
        #expect(events[0].1["app"] == "com.example.Editor")
        #expect(events[0].1["beforeChars"] == "12")
        #expect(events[0].1["afterChars"] == "5")
        #expect(events[0].1["reason"] == "test")
        #expect(events[0].1.values.contains("secret words") == false)
    }

    @Test("Blocked suggestion events are deduplicated until reset")
    func blockedSuggestionEventsAreDeduplicatedUntilReset() {
        var events: [(String, [String: String])] = []
        var recorder = SuggestionDiagnosticsRecorder { event, metadata in
            events.append((event, metadata))
        }
        let context = focusedTextContext(textBeforeCursor: "hello")
        let profile = compatibilityProfile()
        let identity = FocusedFieldIdentity(
            bundleIdentifier: profile.bundleIdentifier,
            processIdentifier: 42,
            elementIdentifier: 7
        )

        recorder.recordBlockedSuggestionEvent(
            "suggestion-blocked",
            context: context,
            profile: profile,
            fieldIdentity: identity,
            metadata: ["reason": "runtime-not-ready"]
        )
        recorder.recordBlockedSuggestionEvent(
            "suggestion-blocked",
            context: context,
            profile: profile,
            fieldIdentity: identity,
            metadata: ["reason": "runtime-not-ready"]
        )
        recorder.resetBlockedSuggestionGate()
        recorder.recordBlockedSuggestionEvent(
            "suggestion-blocked",
            context: context,
            profile: profile,
            fieldIdentity: identity,
            metadata: ["reason": "runtime-not-ready"]
        )

        #expect(events.count == 2)
    }

    private func compatibilityProfile() -> CompatibilityProfile {
        CompatibilityProfile(
            bundleIdentifier: "com.example.Editor",
            displayName: "Example Editor",
            supportLevel: .green,
            supportReason: "test",
            renderMode: .inlineAdjacent,
            insertionMode: .axSelectedText,
            notes: "test"
        )
    }

    private func focusedTextContext(
        textBeforeCursor: String,
        textAfterCursor: String = "",
        caretRect: CGRect? = nil,
        visibleCharacterRange: AccessibilityCharacterRange? = nil,
        insertionPointLineNumber: Int? = nil,
        axReadErrors: [AXAttributeReadError] = []
    ) -> FocusedTextContext {
        FocusedTextContext(
            elementIdentifier: 7,
            role: "AXTextArea",
            subrole: nil,
            fingerprint: .init(identifier: "editor"),
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor,
            selectedTextLength: 0,
            caretRect: caretRect,
            elementRect: CGRect(x: 0, y: 0, width: 300, height: 120),
            windowRect: CGRect(x: 0, y: 0, width: 600, height: 400),
            textLineRect: nil,
            visibleCharacterRange: visibleCharacterRange,
            insertionPointLineNumber: insertionPointLineNumber,
            textStyle: nil,
            isSecure: false,
            caretIsSynthetic: false,
            capabilities: FocusedTextCapabilities(
                canReadValue: true,
                canReadSelectedTextRange: true,
                canReadBoundsForRange: caretRect != nil,
                canReadAttributedText: false,
                canSetSelectedText: true,
                canReadVisibleCharacterRange: visibleCharacterRange != nil,
                canReadInsertionPointLineNumber: insertionPointLineNumber != nil
            ),
            axReadErrors: axReadErrors
        )
    }
}
