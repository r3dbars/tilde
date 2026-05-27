import AutocompleteLabCore
import Foundation
import Testing
@testable import AutocompleteLabApp

@Suite("Claude Code terminal screen prompt anchor cache")
struct ClaudeCodeTerminalScreenPromptAnchorCacheTests {
    @Test("Reuses matching prompt-row anchor briefly after proof input repair")
    func reusesMatchingPromptRowAnchorBrieflyAfterProofInputRepair() {
        let anchor = ClaudeCodeTerminalScreenPromptAnchor(
            inputText: "Make this setting the feature configurable",
            promptLineInputText: "Make this setting the feature configurable",
            lineIndex: 18,
            lineCount: 20
        )
        let now = Date(timeIntervalSince1970: 100)
        var cache = ClaudeCodeTerminalScreenPromptAnchorCache(maxAgeSeconds: 8.0)

        cache.remember(
            anchor,
            hostBundleIdentifier: "com.mitchellh.ghostty",
            now: now
        )

        #expect(cache.anchor(
            hostBundleIdentifier: "com.mitchellh.ghostty",
            inputText: "Make this setting the feature configurable",
            now: now.addingTimeInterval(6)
        ) == anchor)
    }

    @Test("Reuses matching sanitized prompt-line anchor briefly after proof input repair")
    func reusesMatchingSanitizedPromptLineAnchorBrieflyAfterProofInputRepair() {
        let anchor = ClaudeCodeTerminalScreenPromptAnchor(
            inputText: "[[steadytype-proof:run-123]] Make this setting the feature configurable",
            promptLineInputText: "Make this setting the feature configurable",
            lineIndex: 18,
            lineCount: 20
        )
        let now = Date(timeIntervalSince1970: 100)
        var cache = ClaudeCodeTerminalScreenPromptAnchorCache(maxAgeSeconds: 8.0)

        cache.remember(
            anchor,
            hostBundleIdentifier: "com.mitchellh.ghostty",
            now: now
        )

        #expect(cache.anchor(
            hostBundleIdentifier: "com.mitchellh.ghostty",
            inputText: "Make this setting the feature configurable",
            now: now.addingTimeInterval(6)
        ) == anchor)

        let metadata = cache.diagnosticMetadata(
            hostBundleIdentifier: "com.mitchellh.ghostty",
            inputText: "Make this setting the feature configurable",
            now: now.addingTimeInterval(6)
        )
        #expect(metadata["promptAnchorCacheInputMatches"] == "true")
        #expect(metadata["promptAnchorCacheRecoveredInputMatches"] == "false")
        #expect(metadata["promptAnchorCachePromptLineInputMatches"] == "true")
        #expect(metadata["promptAnchorCachePromptLineInputChars"] == "42")
    }

    @Test("Reuses matching suffix of recovered prompt-row anchor after AX line repair")
    func reusesMatchingSuffixOfRecoveredPromptRowAnchorAfterAXLineRepair() {
        let anchor = ClaudeCodeTerminalScreenPromptAnchor(
            inputText: "Please make this setting the feature configurable when users are typing",
            promptLineInputText: "are typing",
            lineIndex: 18,
            lineCount: 20
        )
        let now = Date(timeIntervalSince1970: 100)
        var cache = ClaudeCodeTerminalScreenPromptAnchorCache(maxAgeSeconds: 8.0)

        cache.remember(
            anchor,
            hostBundleIdentifier: "com.mitchellh.ghostty",
            now: now
        )

        #expect(cache.anchor(
            hostBundleIdentifier: "com.mitchellh.ghostty",
            inputText: "the feature configurable when users are typing",
            now: now.addingTimeInterval(1)
        ) == anchor)

        let metadata = cache.diagnosticMetadata(
            hostBundleIdentifier: "com.mitchellh.ghostty",
            inputText: "the feature configurable when users are typing",
            now: now.addingTimeInterval(1)
        )
        #expect(metadata["promptAnchorCacheInputMatches"] == "true")
        #expect(metadata["promptAnchorCacheRecoveredInputMatches"] == "false")
        #expect(metadata["promptAnchorCacheRecoveredInputSuffixMatches"] == "true")
        #expect(metadata["promptAnchorCachePromptLineInputMatches"] == "false")
    }

    @Test("Reuses matching contained recovered prompt-row anchor after stale proof cleanup leaves extra prompt text")
    func reusesMatchingContainedRecoveredPromptRowAnchorAfterStaleProofCleanupLeavesExtraPromptText() {
        let anchor = ClaudeCodeTerminalScreenPromptAnchor(
            inputText: "Make this setting the feature configurable Make this setting the feature configurable",
            promptLineInputText: "configurable",
            lineIndex: 18,
            lineCount: 20
        )
        let now = Date(timeIntervalSince1970: 100)
        var cache = ClaudeCodeTerminalScreenPromptAnchorCache(maxAgeSeconds: 8.0)

        cache.remember(
            anchor,
            hostBundleIdentifier: "com.mitchellh.ghostty",
            now: now
        )

        #expect(cache.anchor(
            hostBundleIdentifier: "com.mitchellh.ghostty",
            inputText: "Make this setting the feature configurable",
            now: now.addingTimeInterval(1)
        ) == anchor)

        let metadata = cache.diagnosticMetadata(
            hostBundleIdentifier: "com.mitchellh.ghostty",
            inputText: "Make this setting the feature configurable",
            now: now.addingTimeInterval(1)
        )
        #expect(metadata["promptAnchorCacheInputMatches"] == "true")
        #expect(metadata["promptAnchorCacheRecoveredInputContainsRequest"] == "true")
    }

    @Test("Reuses fresh host-matched prompt-row anchor for plausible repaired AX input")
    func reusesFreshHostMatchedPromptRowAnchorForPlausibleRepairedAXInput() {
        let anchor = ClaudeCodeTerminalScreenPromptAnchor(
            inputText: "A recovered prompt row with wrapped terminal text",
            promptLineInputText: "terminal text",
            lineIndex: 18,
            lineCount: 20
        )
        let now = Date(timeIntervalSince1970: 100)
        var cache = ClaudeCodeTerminalScreenPromptAnchorCache(maxAgeSeconds: 8.0)

        cache.remember(
            anchor,
            hostBundleIdentifier: "com.mitchellh.ghostty",
            now: now
        )

        #expect(cache.anchor(
            hostBundleIdentifier: "com.mitchellh.ghostty",
            inputText: "Make this setting the feature configurable",
            now: now.addingTimeInterval(1)
        ) == nil)
        #expect(cache.anchorForRepairedInput(
            hostBundleIdentifier: "com.mitchellh.ghostty",
            inputText: "Make this setting the feature configurable",
            now: now.addingTimeInterval(1)
        ) == anchor)
        #expect(cache.anchorForRepairedInput(
            hostBundleIdentifier: "com.apple.Terminal",
            inputText: "Make this setting the feature configurable",
            now: now.addingTimeInterval(1)
        ) == nil)
        #expect(cache.anchorForRepairedInput(
            hostBundleIdentifier: "com.mitchellh.ghostty",
            inputText: "Too short",
            now: now.addingTimeInterval(1)
        ) == nil)

        let metadata = cache.diagnosticMetadata(
            hostBundleIdentifier: "com.mitchellh.ghostty",
            inputText: "Make this setting the feature configurable",
            now: now.addingTimeInterval(1)
        )
        #expect(metadata["promptAnchorCachePlausibleRepairedInput"] == "true")
    }

    @Test("Rejects stale or mismatched prompt-row anchor")
    func rejectsStaleOrMismatchedPromptRowAnchor() {
        let anchor = ClaudeCodeTerminalScreenPromptAnchor(
            inputText: "Make this setting the feature configurable",
            promptLineInputText: "Make this setting the feature configurable",
            lineIndex: 18,
            lineCount: 20
        )
        let now = Date(timeIntervalSince1970: 100)
        var cache = ClaudeCodeTerminalScreenPromptAnchorCache(maxAgeSeconds: 8.0)

        cache.remember(
            anchor,
            hostBundleIdentifier: "com.mitchellh.ghostty",
            now: now
        )

        #expect(cache.anchor(
            hostBundleIdentifier: "com.apple.Terminal",
            inputText: "Make this setting the feature configurable",
            now: now.addingTimeInterval(1)
        ) == nil)
        #expect(cache.anchor(
            hostBundleIdentifier: "com.mitchellh.ghostty",
            inputText: "Make this setting the feature different",
            now: now.addingTimeInterval(1)
        ) == nil)
        #expect(cache.anchor(
            hostBundleIdentifier: "com.mitchellh.ghostty",
            inputText: "Make this setting the feature configurable",
            now: now.addingTimeInterval(9)
        ) == nil)
        #expect(cache.anchor(
            hostBundleIdentifier: "com.mitchellh.ghostty",
            inputText: "Make this setting the feature configurable",
            now: now.addingTimeInterval(1)
        ) == nil)
    }
}
