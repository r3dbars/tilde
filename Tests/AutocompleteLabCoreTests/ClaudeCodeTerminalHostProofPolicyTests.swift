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
}
