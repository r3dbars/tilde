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
}
