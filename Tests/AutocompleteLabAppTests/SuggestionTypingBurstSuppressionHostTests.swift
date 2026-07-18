import AutocompleteLabCore
import CoreGraphics
import Foundation
import Testing
@testable import AutocompleteLabApp

@MainActor
@Suite("Suggestion typing burst suppression host")
struct SuggestionTypingBurstSuppressionHostTests {
    @Test("Keeps a fast phrase fallback visible while model continuation is suppressed")
    func keepsFastPhraseFallback() throws {
        let input = try makeInput()
        let events = TestEvents()
        let host = makeHost(input: input, events: events)

        host.handle(input: input, didPresentFastPhraseFallback: true)

        #expect(events.values == [
            "cancel-idle",
            "decision:Shown: instant phrase while typing fast",
            "status:shown",
            "event:suggestion-blocked",
            "reposition",
            "keyboard"
        ])
    }

    @Test("Records typing-burst suppression and hides the suggestion when no fallback is shown")
    func suppressesTypingBurst() throws {
        let input = try makeInput()
        var events: [String] = []
        var snapshot: FocusedTextSnapshot?
        let host = SuggestionTypingBurstSuppressionHost(
            dependencies: SuggestionTypingBurstSuppressionHostDependencies(
                cancelIdleRetry: {},
                setSuggestionDecision: { events.append("decision:\($0)") },
                showFieldStatusIndicator: { state, _ in events.append("status:\(state == .waiting ? "waiting" : "other")") },
                recordSuggestionEvent: { event, _, _, _ in events.append("event:\(event)") },
                recordBlockedSuggestionEvent: { event, _, _, _, _ in events.append("blocked:\(event)") },
                repositionVisibleSuggestion: { _, _ in events.append("reposition") },
                updateKeyboardEventTapSnapshot: { events.append("keyboard") },
                noteTypingBurstSuppression: { value, _, _ in snapshot = value },
                hideSuggestion: { reason, _ in events.append("hide:\(reason)") }
            )
        )

        host.handle(input: input, didPresentFastPhraseFallback: false)

        #expect(events == [
            "decision:Waiting: fast typing",
            "status:waiting",
            "blocked:suggestion-blocked",
            "hide:typing-burst"
        ])
        #expect(snapshot?.fieldIdentity == input.fieldIdentity)
        #expect(snapshot?.textBeforeCursor == input.context.textBeforeCursor)
    }

    @Test("AppDelegate delegates typing-burst suppression side effects to the host")
    func appDelegateUsesTypingBurstSuppressionHost() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )
        let schedulingHost = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/SuggestionSchedulingHost.swift"),
            encoding: .utf8
        )
        let source = appDelegate + schedulingHost

        #expect(source.contains("private lazy var suggestionTypingBurstSuppressionHost"))
        #expect(source.contains("suggestionTypingBurstSuppressionHost.handle("))
        #expect(!source.contains("let metadata = [\n                \"renderMode\": renderMode.rawValue,\n                \"reason\": \"typing-burst-model-continuation\""))
    }

    private func makeHost(
        input: SuggestionTypingBurstSuppressionInput,
        events: TestEvents
    ) -> SuggestionTypingBurstSuppressionHost {
        SuggestionTypingBurstSuppressionHost(
            dependencies: SuggestionTypingBurstSuppressionHostDependencies(
                cancelIdleRetry: { events.values.append("cancel-idle") },
                setSuggestionDecision: { events.values.append("decision:\($0)") },
                showFieldStatusIndicator: { state, _ in
                    events.values.append("status:\(state == .shown ? "shown" : "other")")
                },
                recordSuggestionEvent: { event, _, _, _ in events.values.append("event:\(event)") },
                recordBlockedSuggestionEvent: { event, _, _, _, _ in events.values.append("blocked:\(event)") },
                repositionVisibleSuggestion: { _, _ in events.values.append("reposition") },
                updateKeyboardEventTapSnapshot: { events.values.append("keyboard") },
                noteTypingBurstSuppression: { _, _, _ in },
                hideSuggestion: { reason, _ in events.values.append("hide:\(reason)") }
            )
        )
    }

    private func makeInput() throws -> SuggestionTypingBurstSuppressionInput {
        let fieldIdentity = FocusedFieldIdentity(
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 42,
            elementIdentifier: 7
        )
        return SuggestionTypingBurstSuppressionInput(
            suggestionID: "typing-burst",
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentity: fieldIdentity,
            requestMode: .phraseContinuation,
            requestTextBeforeCursor: "draft",
            requestTextAfterCursor: "",
            fieldIdentityDescription: fieldIdentity.traceDescription,
            context: FocusedTextContext(
                elementIdentifier: 7,
                role: "AXTextArea",
                subrole: nil,
                fingerprint: FocusedElementFingerprint(windowTitle: "Test"),
                textBeforeCursor: "draft",
                textAfterCursor: "",
                selectedTextLength: 0,
                caretRect: CGRect(x: 10, y: 10, width: 1, height: 18),
                elementRect: CGRect(x: 0, y: 0, width: 500, height: 300),
                windowRect: CGRect(x: 0, y: 0, width: 600, height: 400),
                windowIdentifier: 42,
                textLineRect: CGRect(x: 10, y: 10, width: 140, height: 18),
                textStyle: nil,
                isSecure: false,
                fieldClassification: AXFieldClassification(kind: .multilineCompose, reason: "test"),
                caretIsSynthetic: false,
                capabilities: FocusedTextCapabilities(
                    canReadValue: true,
                    canReadSelectedTextRange: true,
                    canReadBoundsForRange: true,
                    canReadAttributedText: false,
                    canSetSelectedText: true
                )
            ),
            profile: try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit")),
            fieldClassification: AXFieldClassification(kind: .multilineCompose, reason: "test"),
            renderMode: .inlineAdjacent,
            typingBurstMetadata: ["typingBurst": "true"],
            fastPhraseFallbackMetadata: ["fastPhraseFallback": "true"],
            requestMetadata: ["request": "test"],
            settleDelayMilliseconds: 220
        )
    }
}

@MainActor
private final class TestEvents {
    var values: [String] = []
}
