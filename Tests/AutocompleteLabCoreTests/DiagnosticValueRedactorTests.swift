import Testing
@testable import AutocompleteLabCore

@Suite("Diagnostic value redactor")
struct DiagnosticValueRedactorTests {
    @Test("String summaries expose length without raw text")
    func stringSummaryRedactsRawText() {
        let summary = DiagnosticValueRedactor.stringSummary(length: "secret draft text".count)

        #expect(summary == "String(17 chars)")
        #expect(!summary.contains("secret"))
    }

    @Test("Collection summaries expose shape only")
    func collectionSummaryExposesShapeOnly() {
        #expect(DiagnosticValueRedactor.arraySummary(count: 3) == "Array(3 items)")
        #expect(DiagnosticValueRedactor.attributedStringSummary(length: 12) == "AttributedString(12 chars)")
    }

    @Test("Diagnostics metadata redacts likely raw text keys")
    func diagnosticsMetadataRedactsLikelyRawTextKeys() {
        #expect(
            DiagnosticsMetadataRedactor.logSafeValue(
                forKey: "selectedText",
                value: "private draft"
            ) == "String(13 chars)"
        )
        #expect(
            DiagnosticsMetadataRedactor.logSafeValue(
                forKey: "rawOutput",
                value: "model leaked this"
            ) == "String(17 chars)"
        )
        #expect(
            DiagnosticsMetadataRedactor.logSafeValue(
                forKey: "selectedText",
                value: "String(13 chars)"
            ) == "String(13 chars)"
        )
    }

    @Test("Diagnostics metadata keeps shape keys and flattens whitespace")
    func diagnosticsMetadataKeepsShapeKeys() {
        #expect(
            DiagnosticsMetadataRedactor.logSafeValue(
                forKey: "visibleChars",
                value: "12\n"
            ) == "12 "
        )
        #expect(
            DiagnosticsMetadataRedactor.logSafeValue(
                forKey: "hasCaretRect",
                value: "true"
            ) == "true"
        )
        #expect(
            DiagnosticsMetadataRedactor.logSafeValue(
                forKey: "promptMilliseconds",
                value: "1"
            ) == "1"
        )
        #expect(
            DiagnosticsMetadataRedactor.logSafeValue(
                forKey: "suggestionPanelRect",
                value: "x=100,y=200,w=120,h=22"
            ) == "x=100,y=200,w=120,h=22"
        )
        #expect(
            DiagnosticsMetadataRedactor.logSafeValue(
                forKey: "suggestionPanelFrame",
                value: "x=100,y=200,w=120,h=22"
            ) == "x=100,y=200,w=120,h=22"
        )
        #expect(
            DiagnosticsMetadataRedactor.logSafeValue(
                forKey: "acceptedTextHMACToken",
                value: "abc123"
            ) == "abc123"
        )
        #expect(
            DiagnosticsMetadataRedactor.logSafeValue(
                forKey: "fingerprintText",
                value: "private window title"
            ) == "String(20 chars)"
        )
    }
}
