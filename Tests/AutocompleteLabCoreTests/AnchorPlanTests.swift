import CoreGraphics
import Testing
@testable import AutocompleteLabCore

@Suite("Suggestion anchor plans")
struct AnchorPlanTests {
    @Test("Anchor ladder prefers trusted caret geometry")
    func anchorLadderPrefersCaretGeometry() {
        let caret = CGRect(x: 10, y: 20, width: 0, height: 18)
        let line = CGRect(x: 8, y: 20, width: 180, height: 18)
        let field = CGRect(x: 4, y: 12, width: 260, height: 44)
        let window = CGRect(x: 0, y: 0, width: 600, height: 420)

        let decision = RenderModePlan.anchorDecision(
            for: .inlineAdjacent,
            caretRect: caret,
            lineRect: line,
            elementRect: field,
            windowRect: window
        )

        #expect(decision.source == .caret)
        #expect(decision.quality == .trusted)
        #expect(decision.reason == .caretBoundsTrusted)
        #expect(decision.rect == caret)
        #expect(decision.canPresent)
    }

    @Test("Anchor ladder uses line geometry before detached field geometry")
    func anchorLadderUsesLineGeometryBeforeFieldGeometry() {
        let line = CGRect(x: 8, y: 20, width: 180, height: 18)
        let field = CGRect(x: 4, y: 12, width: 260, height: 44)

        let decision = RenderModePlan.anchorDecision(
            for: .inlineAdjacent,
            caretRect: nil,
            lineRect: line,
            elementRect: field,
            windowRect: nil
        )

        #expect(decision.source == .line)
        #expect(decision.quality == .usableFallback)
        #expect(decision.reason == .lineBoundsFallback)
        #expect(decision.rect == line)
        #expect(decision.canPresent)
    }

    @Test("Anchor ladder can use field geometry as a fallback")
    func anchorLadderUsesFieldGeometryFallback() {
        let field = CGRect(x: 4, y: 12, width: 260, height: 44)

        let decision = RenderModePlan.anchorDecision(
            for: .floatingMirror,
            caretRect: nil,
            elementRect: field,
            windowRect: nil
        )

        #expect(decision.source == .field)
        #expect(decision.quality == .usableFallback)
        #expect(decision.reason == .fieldBoundsFallback)
        #expect(decision.rect == field)
        #expect(decision.canPresent)
    }

    @Test("Anchor ladder keeps window geometry diagnostics-only")
    func anchorLadderKeepsWindowGeometryDiagnosticsOnly() {
        let window = CGRect(x: 0, y: 0, width: 600, height: 420)

        let blockedDecision = RenderModePlan.anchorDecision(
            for: .floatingMirror,
            caretRect: nil,
            elementRect: nil,
            windowRect: window
        )
        let diagnosticsDecision = RenderModePlan.anchorDecision(
            for: .floatingMirror,
            caretRect: nil,
            elementRect: nil,
            windowRect: window,
            allowsWindowAnchor: true
        )

        #expect(blockedDecision.source == .none)
        #expect(blockedDecision.quality == .invalid)
        #expect(blockedDecision.reason == .windowAnchorDisallowed)
        #expect(blockedDecision.rect == nil)
        #expect(!blockedDecision.canPresent)

        #expect(diagnosticsDecision.source == .window)
        #expect(diagnosticsDecision.quality == .diagnosticsOnly)
        #expect(diagnosticsDecision.reason == .windowBoundsDiagnostics)
        #expect(diagnosticsDecision.rect == window)
        #expect(!diagnosticsDecision.canPresent)
    }

    @Test("Anchor ladder explains off decisions")
    func anchorLadderExplainsOffDecisions() {
        let disabledDecision = RenderModePlan.anchorDecision(
            for: .disabled,
            caretRect: CGRect(x: 10, y: 20, width: 0, height: 18),
            elementRect: nil,
            windowRect: nil
        )
        let missingDecision = RenderModePlan.anchorDecision(
            for: .inlineAdjacent,
            caretRect: nil,
            elementRect: nil,
            windowRect: nil
        )

        #expect(disabledDecision.source == .none)
        #expect(disabledDecision.quality == .invalid)
        #expect(disabledDecision.reason == .renderModeDisabled)
        #expect(disabledDecision.rect == nil)
        #expect(!disabledDecision.canPresent)

        #expect(missingDecision.source == .none)
        #expect(missingDecision.quality == .invalid)
        #expect(missingDecision.reason == .missingAnchor)
        #expect(missingDecision.rect == nil)
        #expect(!missingDecision.canPresent)
    }

    @Test("Profiles can disallow detached field anchors")
    func profilesCanDisallowDetachedFieldAnchors() throws {
        let codex = try #require(CompatibilityProfileStore.mvp.profile(for: "com.openai.codex"))
        let field = CGRect(x: 4, y: 12, width: 260, height: 44)
        let window = CGRect(x: 0, y: 0, width: 600, height: 420)

        let decision = RenderModePlan.anchorDecision(
            for: .floatingMirror,
            profile: codex,
            caretRect: nil,
            elementRect: field,
            windowRect: nil
        )
        let windowDecision = RenderModePlan.anchorDecision(
            for: .floatingMirror,
            profile: codex,
            caretRect: nil,
            elementRect: nil,
            windowRect: window
        )

        #expect(decision.source == .none)
        #expect(decision.quality == .invalid)
        #expect(decision.reason == .detachedAnchorDisallowed)
        #expect(decision.rect == nil)
        #expect(!decision.canPresent)
        #expect(windowDecision.source == .none)
        #expect(windowDecision.quality == .invalid)
        #expect(windowDecision.reason == .windowAnchorDisallowed)
        #expect(windowDecision.rect == nil)
        #expect(!windowDecision.canPresent)
    }

    @Test("Bare anchor rect API preserves existing render behavior")
    func bareAnchorRectPreservesExistingRenderBehavior() {
        let caret = CGRect(x: 10, y: 20, width: 0, height: 18)
        let field = CGRect(x: 4, y: 12, width: 260, height: 44)
        let window = CGRect(x: 0, y: 0, width: 600, height: 420)

        #expect(RenderModePlan.anchorRect(
            for: .inlineAdjacent,
            caretRect: nil,
            elementRect: field,
            windowRect: window
        ) == nil)
        #expect(RenderModePlan.anchorRect(
            for: .floatingMirror,
            caretRect: caret,
            elementRect: field,
            windowRect: window
        ) == field)
        #expect(RenderModePlan.anchorRect(
            for: .floatingMirror,
            caretRect: caret,
            elementRect: nil,
            windowRect: window
        ) == window)
    }
}
