import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Inline ghost placement decision")
struct InlineGhostPlacementDecisionTests {
    @Test("Debug summary is shape only and stable")
    func debugSummaryIsShapeOnlyAndStable() {
        let decision = InlineGhostPlacementDecision(
            frame: CGRect(x: 12.34, y: 56.78, width: 90.12, height: 18.91),
            profileID: "textedit",
            profileName: "TextEdit",
            strategy: .clippedCaretAnchored,
            lineRectStatus: .verticallyDetached,
            boundaryStatus: .caretOutside
        )

        #expect(decision.debugSummary == "profile=textedit strategy=clippedCaretAnchored line=verticallyDetached boundary=caretOutside frame=x:12.3 y:56.8 w:90.1 h:18.9")
        #expect(!decision.debugSummary.contains("TextEdit"))
    }

    @Test("Decision status enums expose every diagnostics value")
    func decisionStatusEnumsExposeEveryDiagnosticsValue() {
        #expect(InlineGhostPlacementStrategy.allDiagnosticsValues == [
            "caretAnchored",
            "lineAnchored",
            "clippedCaretAnchored",
            "clippedLineAnchored",
            "hiddenNoRoom"
        ])
        #expect(LineRectValidationStatus.allDiagnosticsValues == [
            "used",
            "missing",
            "ignoredByProfile",
            "invalidGeometry",
            "tooTall",
            "verticallyDetached",
            "horizontallyDetached"
        ])
        #expect(BoundaryValidationStatus.allDiagnosticsValues == [
            "used",
            "missing",
            "ignoredByProfile",
            "invalidGeometry",
            "outsideScreen",
            "caretOutside"
        ])
    }
}

private extension RawRepresentable where Self: CaseIterable, RawValue == String {
    static var allDiagnosticsValues: [String] {
        allCases.map(\.rawValue)
    }
}
