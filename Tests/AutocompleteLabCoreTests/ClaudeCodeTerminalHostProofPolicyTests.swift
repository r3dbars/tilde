import Testing
@testable import AutocompleteLabCore

@Suite("Claude Code terminal-host proof policy")
struct ClaudeCodeTerminalHostProofPolicyTests {
    @Test("Terminal-host proof requires an explicit proof marker")
    func terminalHostProofRequiresExplicitProofMarker() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code",
            focusedText: "Can we make this",
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .blocked(.missingProofMarker))
    }

    @Test("Terminal-host proof is blocked outside proof mode")
    func terminalHostProofIsBlockedOutsideProofMode() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.mitchellh.ghostty",
            windowTitle: "AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF",
            focusedText: "Can we make this",
            proofModeEnabled: false
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .blocked(.proofModeRequired))
    }

    @Test("Terminal-host proof rejects shell prompts with commands")
    func terminalHostProofRejectsShellPromptsWithCommands() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF",
            focusedText: "$ git status",
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .blocked(.shellPromptDetected))
    }

    @Test("Terminal-host proof rejects multiline command buffers")
    func terminalHostProofRejectsMultilineCommandBuffers() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF",
            focusedText: "Can we make this\nand also run this",
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .blocked(.multilineCommandDetected))
    }

    @Test("Terminal-host proof accepts a one-line marked Claude Code proof buffer")
    func terminalHostProofAcceptsOneLineMarkedClaudeCodeProofBuffer() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "dev.warp.Warp",
            windowTitle: "AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF",
            focusedText: "Can we make this",
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
    }

    @Test("Terminal-host proof accepts Claude Code prompt glyph when marker is on the input line")
    func terminalHostProofAcceptsMarkedClaudeCodePromptGlyph() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code",
            focusedText: "❯ AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF Can we make this",
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
    }

    @Test("Terminal-host proof keeps shell-like prompt glyph blocked without marker")
    func terminalHostProofKeepsUnmarkedPromptGlyphBlocked() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF",
            focusedText: "❯ git status",
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .blocked(.shellPromptDetected))
    }

    @Test("Terminal-host proof still rejects dollar shell prompts even with marker")
    func terminalHostProofStillRejectsDollarShellPromptWithMarker() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF",
            focusedText: "$ AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF git status",
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .blocked(.shellPromptDetected))
    }

    @Test("Unsupported terminal hosts remain blocked")
    func unsupportedTerminalHostsRemainBlocked() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.example.Terminal",
            windowTitle: "AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF",
            focusedText: "Can we make this",
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .blocked(.unsupportedTerminalHost))
    }

    @Test("Terminal-host proof profile is one-word proof only")
    func terminalHostProofProfileIsOneWordProofOnly() {
        let profile = ClaudeCodeTerminalHostProofPolicy.proofProfile

        #expect(profile.bundleIdentifier == ClaudeCodeTerminalHostProofPolicy.virtualBundleIdentifier)
        #expect(profile.supportLevel == .yellow)
        #expect(profile.canPresentSuggestions)
        #expect(profile.supportsOneWordAcceptance)
        #expect(!profile.supportsFullAcceptance)
        #expect(profile.requiresNoSubmitAcceptanceProof)
        #expect(profile.insertionMode == .keyEvents)
        #expect(profile.anchorLadder == [.caret])
        #expect(!profile.allowsDetachedSuggestions)
    }

    @Test("Terminal-host proof extracts the current input line from scrollback")
    func terminalHostProofExtractsCurrentInputLineFromScrollback() {
        let focusedLine = ClaudeCodeTerminalHostProofPolicy.focusedInputLine(
            textBeforeCursor: "Welcome\nAUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF\nCan we make",
            textAfterCursor: " this\nOld output"
        )

        #expect(focusedLine == "Can we make this")
        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(
            ClaudeCodeTerminalHostProofContext(
                hostBundleIdentifier: "com.apple.Terminal",
                windowTitle: "AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF",
                focusedText: focusedLine,
                proofModeEnabled: true
            )
        ) == .eligible)
    }
}
