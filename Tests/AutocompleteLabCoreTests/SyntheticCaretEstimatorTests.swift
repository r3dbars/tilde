import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Synthetic caret estimator")
struct SyntheticCaretEstimatorTests {
    @Test("Estimates caret position on the current wrapped line")
    func estimatesCaretOnWrappedLine() throws {
        let input = SyntheticCaretEstimateInput(
            textBeforeCursor: "abcdefghijklmnop",
            elementRect: CGRect(x: 100, y: 500, width: 120, height: 120),
            windowRect: CGRect(x: 0, y: 0, width: 600, height: 900),
            lineHeight: 20,
            horizontalPadding: 10,
            verticalPadding: 4,
            inlineGap: 6
        )

        let caret = try #require(SyntheticCaretEstimator.estimate(input: input) { text in
            CGFloat(text.count * 10)
        })

        #expect(caret.minX == 176)
        #expect(caret.minY == 524)
        #expect(caret.height == 20)
    }

    @Test("Keeps synthetic caret inside cramped window bounds")
    func clampsSyntheticCaretToWindow() throws {
        let input = SyntheticCaretEstimateInput(
            textBeforeCursor: String(repeating: "x", count: 200),
            elementRect: CGRect(x: 20, y: 20, width: 110, height: 70),
            windowRect: CGRect(x: 0, y: 0, width: 160, height: 120),
            lineHeight: 22
        )

        let caret = try #require(SyntheticCaretEstimator.estimate(input: input) { text in
            CGFloat(text.count * 9)
        })

        #expect(caret.minY >= 8)
        #expect(caret.maxY <= 112)
        #expect(caret.maxX <= 112)
    }

    @Test("Shares one safe eligibility gate across app families")
    func selectsSyntheticCaretSources() {
        let rect = CGRect(x: 0, y: 0, width: 240, height: 80)

        #expect(SyntheticCaretEligibility.source(
            bundleIdentifier: "com.openai.codex",
            role: "AXTextArea",
            subrole: nil,
            elementRect: rect,
            canReadValue: true,
            canReadSelectedTextRange: true
        ) == .electronTextAreaEstimate)
        #expect(SyntheticCaretEligibility.source(
            bundleIdentifier: "com.google.Chrome",
            role: "AXWebArea",
            subrole: nil,
            elementRect: rect,
            canReadValue: true,
            canReadSelectedTextRange: true
        ) == .webAreaEstimate)
        #expect(SyntheticCaretEligibility.source(
            bundleIdentifier: "md.obsidian",
            role: "AXGroup",
            subrole: nil,
            elementRect: rect,
            canReadValue: true,
            canReadSelectedTextRange: true
        ) == .codeMirrorEstimate)
        #expect(SyntheticCaretEligibility.source(
            bundleIdentifier: "com.example.Editor",
            role: "AXTextArea",
            subrole: nil,
            elementRect: rect,
            canReadValue: true,
            canReadSelectedTextRange: true
        ) == .axTextAreaEstimate)
        #expect(SyntheticCaretEligibility.source(
            bundleIdentifier: "com.example.Editor",
            role: "AXTextArea",
            subrole: nil,
            elementRect: rect,
            canReadValue: false,
            canReadSelectedTextRange: true
        ) == nil)
    }
}
