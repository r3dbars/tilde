import AppKit
import AutocompleteLabCore
import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Suggestion trigger timing host")
@MainActor
struct SuggestionTriggerTimingHostTests {
    @Test("AppDelegate delegates trigger timing outcomes and scheduling")
    func appDelegateUsesTriggerTimingHost() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let source = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )

        #expect(source.contains("private lazy var suggestionTriggerTimingHost"))
        #expect(source.contains("suggestionTriggerTimingHost.handle(\n"))
    }

    @Test("active type-through keeps the visible suggestion as the only owner")
    func activeTypeThroughSkipsNewRequests() throws {
        let profile = try #require(
            CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit")
        )
        let context = FocusedTextContext(
            elementIdentifier: 7,
            role: "AXTextArea",
            subrole: nil,
            fingerprint: FocusedElementFingerprint(windowTitle: "TextEdit"),
            textBeforeCursor: "I want to pred",
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
        )
        let identity = FocusedFieldIdentity(
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 42,
            elementIdentifier: 7
        )
        var scheduled = false
        var eventReason: String?
        let host = SuggestionTriggerTimingHost(
            dependencies: SuggestionTriggerTimingHostDependencies(
                triggerPolicy: { _ in
                    Issue.record("trigger policy must not run during active type-through")
                    return SuggestionTriggerPolicy()
                },
                rawEvaluationModeEnabled: { true },
                consumeManualSuggestionRequest: {
                    Issue.record("manual request must not be consumed during active type-through")
                    return false
                },
                hasVisibleSuggestion: { true },
                isActivelyTypingThrough: { true },
                setSuggestionDecision: { _ in },
                showFieldStatusIndicator: { _, _ in },
                repositionVisibleSuggestion: { _, _ in
                    Issue.record("AX geometry must not reposition during active type-through")
                },
                recordSuggestionEvent: { _, _, _, metadata in
                    eventReason = metadata["reason"]
                },
                hideSuggestion: {
                    Issue.record("visible suggestion must not be hidden during active type-through")
                },
                scheduleSuggestion: { _ in scheduled = true }
            )
        )

        host.handle(input: SuggestionTriggerTimingHostInput(
            context: context,
            profile: profile,
            suggestionAppBundleIdentifier: "com.apple.TextEdit",
            fieldIdentity: identity,
            fieldClassification: context.fieldClassification,
            renderMode: .inlineAdjacent,
            requestMode: .phraseContinuation,
            previousTextBeforeCursor: "I want to pre",
            idleRetryReason: nil,
            visiblePageContext: nil
        ))

        #expect(!scheduled)
        #expect(eventReason == "active-type-through")
    }
}
