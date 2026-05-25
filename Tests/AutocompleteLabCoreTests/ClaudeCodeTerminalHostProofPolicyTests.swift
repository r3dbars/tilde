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

    @Test("Terminal-host proof accepts compact typeable marker")
    func terminalHostProofAcceptsCompactTypeableMarker() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code",
            focusedText: "❯ STEADYTYPECLAUDECODEPROOF Can we make this",
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
        #expect(ClaudeCodeTerminalHostProofPolicy.sanitizedProofInputLine(
            "❯ STEADYTYPECLAUDECODEPROOF Can we make this"
        ) == "Can we make this")
    }

    @Test("Terminal-host proof keeps shell-like prompt glyph blocked without marker")
    func terminalHostProofKeepsUnmarkedPromptGlyphBlocked() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code",
            focusedText: "❯ git status",
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .blocked(.missingProofMarker))
    }

    @Test("Terminal-host proof accepts Claude Code title marker when AX exposes placeholder line")
    func terminalHostProofAcceptsClaudeCodeTitleMarkerForPromptGlyph() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF",
            focusedText: "❯ Try \"fix lint errors\"",
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
    }

    @Test("Terminal-host proof rejects prompt glyph when title marker is not Claude Code scoped")
    func terminalHostProofRejectsPromptGlyphWithUnscopedTitleMarker() {
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

    @Test("Terminal-host proof rejects command-shaped Claude prompt text")
    func terminalHostProofRejectsCommandShapedClaudePromptText() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code",
            focusedText: "❯ AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF git status",
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .blocked(.shellCommandDetected))
    }

    @Test("Terminal-host proof rejects active Claude output lines")
    func terminalHostProofRejectsActiveClaudeOutputLines() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF",
            focusedText: "● Running Bash(git status)",
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .blocked(.activeAgentOutputDetected))
    }

    @Test("Terminal-host proof rejects active Claude output even when output echoes marker")
    func terminalHostProofRejectsActiveClaudeOutputEvenWhenOutputEchoesMarker() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code",
            focusedText: "● AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF Running Bash(git status)",
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .blocked(.activeAgentOutputDetected))
    }

    @Test("Terminal-host proof rejects stale marked multiline buffers from scrollback")
    func terminalHostProofRejectsStaleMarkedMultilineBuffersFromScrollback() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code",
            focusedText: "Can we make this",
            rawTextBeforeCursor: "❯ AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF old prompt\nCan we make",
            rawTextAfterCursor: " this",
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .blocked(.multilineCommandDetected))
    }

    @Test("Terminal-host proof rejects marked multiline buffers after the cursor")
    func terminalHostProofRejectsMarkedMultilineBuffersAfterCursor() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code",
            focusedText: "Can we make this",
            rawTextBeforeCursor: "❯ AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF Can we make",
            rawTextAfterCursor: " this\nnext terminal row",
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .blocked(.multilineCommandDetected))
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
        #expect(profile.insertionMode == .clipboardFallbackOptIn)
        #expect(profile.anchorLadder == [.caret])
        #expect(!profile.allowsDetachedSuggestions)
        #expect(profile.promptAppSafetyMode == .wordOnly)
    }

    @Test("Terminal-host proof exposes named host variants")
    func terminalHostProofExposesNamedHostVariants() {
        let variants = ClaudeCodeTerminalHostProofPolicy.supportedHostVariants
        let byID = Dictionary(uniqueKeysWithValues: variants.map { ($0.id, $0) })

        #expect(byID["terminal"]?.bundleIdentifier == "com.apple.Terminal")
        #expect(byID["iterm2"]?.bundleIdentifier == "com.googlecode.iterm2")
        #expect(byID["warp"]?.bundleIdentifier == "dev.warp.Warp")
        #expect(byID["ghostty"]?.bundleIdentifier == "com.mitchellh.ghostty")
        #expect(byID["kitty"]?.bundleIdentifier == "net.kovidgoyal.kitty")
        #expect(byID["alacritty"]?.bundleIdentifier == "org.alacritty")
        #expect(byID["wezterm"]?.bundleIdentifier == "com.github.wez.wezterm")
        #expect(ClaudeCodeTerminalHostProofPolicy.hostVariant(for: "com.googlecode.iterm2")?.proofLabel == "claude-code-iterm2")
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

    @Test("Terminal-host proof accepts the marked current prompt line when scrollback has prior shell commands")
    func terminalHostProofAcceptsMarkedCurrentPromptLineWithShellScrollback() {
        let textBeforeCursor = """
        redbars@Mac % cd /tmp/autocomplete-claude-code-proof; printf '\\033]0;Claude Code AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF\\007'; claude
        Claude Code
        ❯ AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF Can we make this dicta
        """
        let focusedLine = ClaudeCodeTerminalHostProofPolicy.focusedInputLine(
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: " \n  ? for shortcuts"
        )

        #expect(focusedLine == "❯ AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF Can we make this dicta ")
        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(
            ClaudeCodeTerminalHostProofContext(
                hostBundleIdentifier: "com.apple.Terminal",
                windowTitle: "redbars — ✳ Claude Code — node ◂ claude — 120×30",
                focusedText: focusedLine,
                rawTextBeforeCursor: textBeforeCursor,
                rawTextAfterCursor: " \n  ? for shortcuts",
                proofModeEnabled: true
            )
        ) == .eligible)
    }

    @Test("Terminal-host proof extracts current prompt line from carriage-return terminal buffers")
    func terminalHostProofExtractsCurrentPromptLineFromCarriageReturnTerminalBuffers() {
        let textBeforeCursor = "redbars@Mac % claude\rClaude Code\r❯ AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF Can we make this dicta"
        let focusedLine = ClaudeCodeTerminalHostProofPolicy.focusedInputLine(
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: " \r  ? for shortcuts"
        )

        #expect(focusedLine == "❯ AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF Can we make this dicta ")
        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(
            ClaudeCodeTerminalHostProofContext(
                hostBundleIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code",
                focusedText: focusedLine,
                rawTextBeforeCursor: textBeforeCursor,
                rawTextAfterCursor: " \r  ? for shortcuts",
                proofModeEnabled: true
            )
        ) == .eligible)
    }

    @Test("Terminal-host proof reconstructs wrapped marked prompt rows")
    func terminalHostProofReconstructsWrappedMarkedPromptRows() {
        let textBeforeCursor = """
        Claude Code
        ❯ AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF 123 sample-two The fastest terminal prompt should
        predic
        """
        let focusedLine = ClaudeCodeTerminalHostProofPolicy.focusedInputLine(
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: " \n  ? for shortcuts"
        )

        #expect(focusedLine == "❯ AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF 123 sample-two The fastest terminal prompt should predic ")
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: " \n  ? for shortcuts"
        ) == "123 sample-two The fastest terminal prompt should predic ")
        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(
            ClaudeCodeTerminalHostProofContext(
                hostBundleIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code",
                focusedText: focusedLine,
                rawTextBeforeCursor: textBeforeCursor,
                rawTextAfterCursor: " \n  ? for shortcuts",
                proofModeEnabled: true
            )
        ) == .eligible)
    }

    @Test("Terminal-host proof reconstructs wrapped prompt rows with late compact marker")
    func terminalHostProofReconstructsWrappedPromptRowsWithLateCompactMarker() {
        let textBeforeCursor = """
        Claude Code
        ❯ Can we make this STEADYTYPECLAUDECODEPROOF
        dicta
        """
        let focusedLine = ClaudeCodeTerminalHostProofPolicy.focusedInputLine(
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: " \n  shortcuts"
        )

        #expect(focusedLine == "❯ Can we make this STEADYTYPECLAUDECODEPROOF dicta ")
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: " \n  shortcuts"
        ) == "Can we make this dicta ")
        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(
            ClaudeCodeTerminalHostProofContext(
                hostBundleIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code",
                focusedText: focusedLine,
                rawTextBeforeCursor: textBeforeCursor,
                rawTextAfterCursor: " \n  shortcuts",
                proofModeEnabled: true
            )
        ) == .eligible)
    }

    @Test("Terminal-host proof rejects shell launcher markers as stale scrollback")
    func terminalHostProofRejectsShellLauncherMarkersAsStaleScrollback() {
        let textBeforeCursor = """
        redbars@Mac % printf 'STEADYTYPECLAUDECODEPROOF'; claude
        Claude Code
        pred
        """
        let focusedLine = ClaudeCodeTerminalHostProofPolicy.focusedInputLine(
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: " \n  shortcuts"
        )

        #expect(focusedLine == "pred ")
        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(
            ClaudeCodeTerminalHostProofContext(
                hostBundleIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code",
                focusedText: focusedLine,
                rawTextBeforeCursor: textBeforeCursor,
                rawTextAfterCursor: " \n  shortcuts",
                proofModeEnabled: true
            )
        ) == .blocked(.multilineCommandDetected))
    }

    @Test("Terminal-host proof accepts scoped title marker with safe current prompt")
    func terminalHostProofAcceptsScopedTitleMarkerWithSafeCurrentPrompt() {
        let textBeforeCursor = """
        redbars@Mac % printf 'STEADYTYPECLAUDECODEPROOF'; claude
        Claude Code
        Can we make this dicta
        """
        let focusedLine = ClaudeCodeTerminalHostProofPolicy.focusedInputLine(
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: " \n  shortcuts"
        )

        #expect(focusedLine == "Can we make this dicta ")
        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(
            ClaudeCodeTerminalHostProofContext(
                hostBundleIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
                focusedText: focusedLine,
                rawTextBeforeCursor: textBeforeCursor,
                rawTextAfterCursor: " \n  shortcuts",
                proofModeEnabled: true
            )
        ) == .eligible)
    }

    @Test("Terminal-host proof input can rely on scoped title marker only")
    func terminalHostProofInputCanRelyOnScopedTitleMarkerOnly() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: "Can we make this red",
            rawTextBeforeCursor: "Can we make this red",
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == "Can we make this red")
    }

    @Test("Terminal-host proof input uses vetted prompt line when Claude chrome trails cursor")
    func terminalHostProofInputUsesVettedPromptLineWhenClaudeChromeTrailsCursor() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: "Can we make this dicta",
            rawTextBeforeCursor: """
            redbars@Mac % printf 'STEADYTYPECLAUDECODEPROOF'; claude
            Claude Code
            Can we make this dicta
            """,
            rawTextAfterCursor: """
            ╭────────────────────────────────────╮
            │ ? for shortcuts                    │
            ╰────────────────────────────────────╯
            """,
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == "Can we make this dicta")
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(
            textBeforeCursor: context.rawTextBeforeCursor,
            textAfterCursor: context.rawTextAfterCursor
        ) == nil)
    }

    @Test("Terminal-host proof input prefers before-cursor text over full AX line")
    func terminalHostProofInputPrefersBeforeCursorTextOverFullAXLine() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: "Can we make this dicta",
            rawTextBeforeCursor: """
            redbars@Mac % printf 'STEADYTYPECLAUDECODEPROOF'; claude
            Claude Code
            Can we make this STEADYTYPECLAUDECODEPROOF d
            """,
            rawTextAfterCursor: """
            icta
            ? for shortcuts
            """,
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == "Can we make this d")
    }

    @Test("Terminal-host proof input does not bypass command-shaped prompt lines")
    func terminalHostProofInputDoesNotBypassCommandShapedPromptLines() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: "git status",
            rawTextBeforeCursor: "git status",
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .blocked(.shellCommandDetected))
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == nil)
    }

    @Test("Terminal-host proof keeps title-marker shell commands blocked")
    func terminalHostProofKeepsTitleMarkerShellCommandsBlocked() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: "git status",
            rawTextBeforeCursor: "git status",
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .blocked(.shellCommandDetected))
    }

    @Test("Terminal-host proof keeps wrapped prompt blocked when text remains after cursor")
    func terminalHostProofKeepsWrappedPromptBlockedWhenTextRemainsAfterCursor() {
        let textBeforeCursor = """
        Claude Code
        ❯ AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF 123 sample-two The fastest terminal prompt should
        pred
        """

        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: "ict this"
        ) == nil)
        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(
            ClaudeCodeTerminalHostProofContext(
                hostBundleIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code",
                focusedText: ClaudeCodeTerminalHostProofPolicy.focusedInputLine(
                    textBeforeCursor: textBeforeCursor,
                    textAfterCursor: "ict this"
                ),
                rawTextBeforeCursor: textBeforeCursor,
                rawTextAfterCursor: "ict this",
                proofModeEnabled: true
            )
        ) == .blocked(.multilineCommandDetected))
    }

    @Test("Terminal-host proof accepts marked current prompt line when AX exposes full buffer")
    func terminalHostProofAcceptsMarkedCurrentPromptLineWhenAXExposesFullBuffer() {
        let focusedText = """
        redbars@Mac % cd /tmp/autocomplete-claude-code-proof; printf '\\033]0;Claude Code AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF\\007'; claude
        Claude Code
        ❯ AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF Can we make this dicta
          ? for shortcuts
        """

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(
            ClaudeCodeTerminalHostProofContext(
                hostBundleIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code",
                focusedText: focusedText,
                proofModeEnabled: true
            )
        ) == .eligible)
    }

    @Test("Terminal-host proof rejects stale marked line when AX exposes later text")
    func terminalHostProofRejectsStaleMarkedLineWhenAXExposesLaterText() {
        let focusedText = """
        ❯ AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF old prompt
        Claude output from an earlier prompt
        Can we make this
        """

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(
            ClaudeCodeTerminalHostProofContext(
                hostBundleIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code",
                focusedText: focusedText,
                proofModeEnabled: true
            )
        ) == .blocked(.multilineCommandDetected))
    }

    @Test("Terminal-host proof input strips prompt glyph and marker")
    func terminalHostProofInputStripsPromptGlyphAndMarker() {
        let input = ClaudeCodeTerminalHostProofPolicy.proofInputText(
            textBeforeCursor: "Welcome\n❯ AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF Can we make",
            textAfterCursor: ""
        )

        #expect(input == "Can we make")
    }

    @Test("Terminal-host proof input refuses middle-of-line text")
    func terminalHostProofInputRefusesMiddleOfLineText() {
        let input = ClaudeCodeTerminalHostProofPolicy.proofInputText(
            textBeforeCursor: "Welcome\n❯ AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF Can we make",
            textAfterCursor: " this\nOld output"
        )

        #expect(input == nil)
    }

    @Test("Terminal-host proof input accepts title-marker typed line")
    func terminalHostProofInputAcceptsTitleMarkerTypedLine() {
        let input = ClaudeCodeTerminalHostProofPolicy.sanitizedProofInputLine(
            "❯ Can we make this"
        )

        #expect(input == "Can we make this")
    }

    @Test("Terminal-host proof input preserves one typed trailing space")
    func terminalHostProofInputPreservesOneTypedTrailingSpace() {
        let input = ClaudeCodeTerminalHostProofPolicy.proofInputText(
            textBeforeCursor: "Welcome\n❯ AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF Can we make this ",
            textAfterCursor: ""
        )

        #expect(input == "Can we make this ")
    }

    @Test("Terminal-host proof input ignores Claude placeholder line")
    func terminalHostProofInputIgnoresClaudePlaceholderLine() {
        let input = ClaudeCodeTerminalHostProofPolicy.sanitizedProofInputLine(
            "❯ Try \"fix lint errors\""
        )

        #expect(input == nil)
    }
}
