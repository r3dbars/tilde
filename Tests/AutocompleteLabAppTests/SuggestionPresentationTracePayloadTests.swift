import CoreGraphics
import Testing
@testable import AutocompleteLabApp

@Suite("Suggestion presentation trace payload")
struct SuggestionPresentationTracePayloadTests {
    @Test("Presented payload keeps the existing raw trace metadata shape")
    func presentedPayloadKeepsRawTraceMetadataShape() {
        let payload = SuggestionPresentationTracePayloadBuilder().presented(
            suggestionID: "1234567890abcdef",
            requestMode: "phraseContinuation",
            renderMode: "inlineAdjacent",
            visibleText: " finish this",
            visibleWordCount: 2,
            latencyMilliseconds: 42,
            anchorRect: CGRect(x: 10.4, y: 20.5, width: 30.6, height: 40.1),
            textLineRect: CGRect(x: 9, y: 19, width: 200, height: 22),
            panelRect: CGRect(x: 41, y: 20, width: 120, height: 24),
            clippingRect: CGRect(x: 0, y: 0, width: 500, height: 300),
            screenshotCaptureRect: "x=0,y=0,w=500,h=300",
            requestMetadata: ["behaviorProfile": "docsProse", "shared": "request"],
            geometryMetadata: ["caretIsSynthetic": "false", "shared": "geometry"],
            learningMetadata: ["learning": "trusted", "shared": "learning"],
            placementMetadata: ["placement": "presented"],
            candidateSelectionMetadata: ["candidateSelectionSource": "app-model-result"],
            displayScoreMetadata: ["displayScoreDecision": "display"],
            replacementMetadata: ["replacementDecision": "replace"]
        )

        #expect(payload.rawTraceMetadata["effectiveRenderMode"] == "inlineAdjacent")
        #expect(payload.rawTraceMetadata["visibleChars"] == "12")
        #expect(payload.rawTraceMetadata["visibleWords"] == "2")
        #expect(payload.rawTraceMetadata["anchorRect"] == "x=10,y=21,w=31,h=40")
        #expect(payload.rawTraceMetadata["textLineRect"] == "x=9,y=19,w=200,h=22")
        #expect(payload.rawTraceMetadata["suggestionPanelRect"] == "x=41,y=20,w=120,h=24")
        #expect(payload.rawTraceMetadata["clippingRect"] == "x=0,y=0,w=500,h=300")
        #expect(payload.rawTraceMetadata["screenshotCaptureRect"] == "x=0,y=0,w=500,h=300")
        #expect(payload.rawTraceMetadata["behaviorProfile"] == "docsProse")
        #expect(payload.rawTraceMetadata["caretIsSynthetic"] == "false")
        #expect(payload.rawTraceMetadata["learning"] == "trusted")
        #expect(payload.rawTraceMetadata["placement"] == "presented")
        #expect(payload.rawTraceMetadata["candidateSelectionSource"] == "app-model-result")
        #expect(payload.rawTraceMetadata["displayScoreDecision"] == "display")
        #expect(payload.rawTraceMetadata["replacementDecision"] == "replace")
        #expect(payload.rawTraceMetadata["shared"] == "request")
    }

    @Test("Diagnostics payload keeps diagnostics-only fields out of raw trace metadata")
    func diagnosticsPayloadKeepsDiagnosticsOnlyFieldsOutOfRawTraceMetadata() {
        let payload = SuggestionPresentationTracePayloadBuilder().presented(
            suggestionID: "abcdef1234567890",
            requestMode: "wordCompletion",
            renderMode: "floatingMirror",
            visibleText: "world",
            visibleWordCount: 1,
            latencyMilliseconds: 150,
            anchorRect: CGRect(x: 1, y: 2, width: 3, height: 4),
            textLineRect: nil,
            panelRect: CGRect(x: 5, y: 6, width: 7, height: 8),
            clippingRect: nil,
            screenshotCaptureRect: "none",
            requestMetadata: [:],
            geometryMetadata: ["geometry": "raw-only"],
            learningMetadata: [:],
            placementMetadata: [:],
            candidateSelectionMetadata: [:],
            displayScoreMetadata: [:],
            replacementMetadata: [:]
        )

        #expect(payload.diagnosticsMetadata["requestMode"] == "wordCompletion")
        #expect(payload.diagnosticsMetadata["traceID"] == "abcdef12")
        #expect(payload.diagnosticsMetadata["suggestionID"] == "abcdef1234567890")
        #expect(payload.diagnosticsMetadata["latencyMilliseconds"] == "150")
        #expect(payload.diagnosticsMetadata["textLineRect"] == "none")
        #expect(payload.diagnosticsMetadata["clippingRect"] == "none")
        #expect(payload.diagnosticsMetadata["geometry"] == nil)
        #expect(payload.rawTraceMetadata["requestMode"] == nil)
        #expect(payload.rawTraceMetadata["traceID"] == nil)
        #expect(payload.rawTraceMetadata["suggestionID"] == nil)
        #expect(payload.rawTraceMetadata["latencyMilliseconds"] == nil)
        #expect(payload.rawTraceMetadata["geometry"] == "raw-only")
    }
}
