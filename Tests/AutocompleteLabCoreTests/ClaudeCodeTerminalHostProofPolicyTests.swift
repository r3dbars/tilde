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
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == nil)
    }

    @Test("Terminal-host proof input rejects Claude Code shortcut hints")
    func terminalHostProofInputRejectsClaudeCodeShortcutHints() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF",
            focusedText: "Press ? for shortcuts",
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
        #expect(ClaudeCodeTerminalHostProofPolicy.sanitizedProofInputLine("for shortcuts") == nil)
        #expect(ClaudeCodeTerminalHostProofPolicy.sanitizedProofInputLine("Press ? for shortcuts") == nil)
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == nil)
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
        #expect(
            byID["ghostty"]?.manualProofCommand
                == "AUTOCOMPLETE_LAB_SCREENSHOT_TRACE=1 script/real_app_smoke.sh claude-code --host ghostty --manual-gate"
        )
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

    @Test("Terminal-host proof input strips Claude numbered prompt decoration")
    func terminalHostProofInputStripsClaudeNumberedPromptDecoration() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: "1. Can we make this red",
            rawTextBeforeCursor: "1. Can we make this red",
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == "Can we make this red")
    }

    @Test("Terminal-host proof input preserves trailing space after numbered prompt decoration")
    func terminalHostProofInputPreservesTrailingSpaceAfterNumberedPromptDecoration() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: "1. Can we make this red ",
            rawTextBeforeCursor: "1. Can we make this red ",
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == "Can we make this red ")
    }

    @Test("Terminal-host proof keeps numbered command-shaped prompt lines blocked")
    func terminalHostProofKeepsNumberedCommandShapedPromptLinesBlocked() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: "1. git status",
            rawTextBeforeCursor: "1. git status",
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .blocked(.shellCommandDetected))
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == nil)
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
        ) == "Can we make this dicta")
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

    @Test("Terminal-host proof ignores Claude chrome after a marked current line")
    func terminalHostProofIgnoresClaudeChromeAfterMarkedCurrentLine() {
        let textBeforeCursor = """
        Claude Code
        ❯ STEADYTYPECLAUDECODEPROOF Make this setting con
        """
        let textAfterCursor = """
        ╭────────────────────────────────────╮
        │ ? for shortcuts                    │
        ╰────────────────────────────────────╯
        """
        let focusedLine = ClaudeCodeTerminalHostProofPolicy.focusedInputLine(
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor
        )
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: focusedLine,
            rawTextBeforeCursor: textBeforeCursor,
            rawTextAfterCursor: textAfterCursor,
            proofModeEnabled: true
        )

        #expect(focusedLine == "❯ STEADYTYPECLAUDECODEPROOF Make this setting con")
        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == "Make this setting con")
    }

    @Test("Terminal-host proof recovers current marker when Terminal flattens launcher scrollback")
    func terminalHostProofRecoversCurrentMarkerFromFlattenedLauncherScrollback() {
        let textBeforeCursor = """
        redbars@Mac % cd /Users/redbars/.codex/worktrees/32b9/transcripted-autocomplete-lab; /opt/homebrew/bin/claude Claude Code ❯ STEADYTYPECLAUDECODEPROOF Make this setting con
        """
        let textAfterCursor = """
        ╭────────────────────────────────────╮
        │ ? for shortcuts                    │
        ╰────────────────────────────────────╯
        """
        let focusedLine = ClaudeCodeTerminalHostProofPolicy.focusedInputLine(
            textBeforeCursor: textBeforeCursor,
            textAfterCursor: textAfterCursor
        )
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: focusedLine,
            rawTextBeforeCursor: textBeforeCursor,
            rawTextAfterCursor: textAfterCursor,
            proofModeEnabled: true
        )

        #expect(focusedLine == "STEADYTYPECLAUDECODEPROOF Make this setting con")
        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == "Make this setting con")
    }

    @Test("Terminal-host proof recovers current marker when Terminal screen trails cursor")
    func terminalHostProofRecoversCurrentMarkerWhenTerminalScreenTrailsCursor() {
        let textBeforeCursor = """
        redbars@Mac % cd /Users/redbars/.codex/worktrees/32b9/transcripted-autocomplete-lab; /opt/homebrew/bin/claude Claude Code ❯ STEADYTYPECLAUDECODEPROOF Make this setting con
        """
        let textAfterCursor = """
        ╭────────────────────────────────────╮
        │ Try "fix lint errors"              │
        ╰────────────────────────────────────╯
        old terminal screen text
        """
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: textBeforeCursor + textAfterCursor,
            rawTextBeforeCursor: textBeforeCursor,
            rawTextAfterCursor: textAfterCursor,
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == "Make this setting con")

        let metadata = ClaudeCodeTerminalHostProofPolicy.diagnosticMetadata(for: context)
        #expect(metadata["terminalProofCanIgnoreAfterCursor"] == "true")
        #expect(metadata["terminalProofAfterFirstLineKind"] == "chrome")
        #expect(metadata["terminalProofRecoverableInput"] == "true")
        #expect(metadata["terminalProofRecoveryRejectionReason"] == "none")
        #expect(metadata["terminalProofRecoveredBeforeChars"] == "21")
        #expect(metadata["terminalProofRecoveredWordCount"] == "4")
        #expect(metadata["terminalProofRecoveredPartialWordCharacters"] == "3")
    }

    @Test("Terminal-host proof recovers make-this sample when marker starts the prompt row")
    func terminalHostProofRecoversMakeThisSampleWhenMarkerStartsPromptRow() {
        let textBeforeCursor = "STEADYTYPECLAUDECODEPROOF Make this setting con"
        let textAfterCursor = " \n╭────────────────────────────────────╮\n"
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: textBeforeCursor + textAfterCursor,
            rawTextBeforeCursor: textBeforeCursor,
            rawTextAfterCursor: textAfterCursor,
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == "Make this setting con")

        let metadata = ClaudeCodeTerminalHostProofPolicy.diagnosticMetadata(for: context)
        #expect(metadata["terminalProofRecoverableInput"] == "true")
        #expect(metadata["terminalProofRecoveryRejectionReason"] == "none")
        #expect(metadata["terminalProofRecoveredBeforeChars"] == "21")
    }

    @Test("Terminal-host proof recovers make-this sample after prompt residue")
    func terminalHostProofRecoversMakeThisSampleAfterPromptResidue() {
        let textBeforeCursor = "›STEADYTYPECLAUDECODEPROOF Make this setting con"
        let textAfterCursor = " \n╭────────────────────────────────────╮\n"
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: textBeforeCursor + textAfterCursor,
            rawTextBeforeCursor: textBeforeCursor,
            rawTextAfterCursor: textAfterCursor,
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == "Make this setting con")

        let metadata = ClaudeCodeTerminalHostProofPolicy.diagnosticMetadata(for: context)
        #expect(metadata["terminalProofRecoverableInput"] == "true")
        #expect(metadata["terminalProofRecoveryRejectionReason"] == "none")
        #expect(metadata["terminalProofRecoveredBeforeChars"] == "21")
    }

    @Test("Terminal-host proof recovers make-this sample when Terminal drops a typed space")
    func terminalHostProofRecoversMakeThisSampleWhenTerminalDropsTypedSpace() {
        let textBeforeCursor = "❯\u{00a0}STEADYTYPECLAUDECODEPROOF Make thissetting con"
        let textAfterCursor = " \n╭────────────────────────────────────╮\n"
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: textBeforeCursor + textAfterCursor,
            rawTextBeforeCursor: textBeforeCursor,
            rawTextAfterCursor: textAfterCursor,
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == "Make this setting con")

        let metadata = ClaudeCodeTerminalHostProofPolicy.diagnosticMetadata(for: context)
        #expect(metadata["terminalProofRecoverableInput"] == "true")
        #expect(metadata["terminalProofRecoveryRejectionReason"] == "none")
        #expect(metadata["terminalProofRecoveredBeforeChars"] == "21")
    }

    @Test("Terminal-host proof keeps marked shell command sample blocked")
    func terminalHostProofKeepsMarkedShellCommandSampleBlocked() {
        let textBeforeCursor = "STEADYTYPECLAUDECODEPROOF make test"
        let textAfterCursor = " \n╭────────────────────────────────────╮\n"
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: textBeforeCursor + textAfterCursor,
            rawTextBeforeCursor: textBeforeCursor,
            rawTextAfterCursor: textAfterCursor,
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .blocked(.shellCommandDetected))
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == nil)

        let metadata = ClaudeCodeTerminalHostProofPolicy.diagnosticMetadata(for: context)
        #expect(metadata["terminalProofRecoverableInput"] == "false")
        #expect(metadata["terminalProofRecoveryRejectionReason"] == "shellCommandInput")
    }

    @Test("Terminal-host proof keeps make all command sample blocked")
    func terminalHostProofKeepsMakeAllCommandSampleBlocked() {
        let textBeforeCursor = "STEADYTYPECLAUDECODEPROOF make all"
        let textAfterCursor = " \n╭────────────────────────────────────╮\n"
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: textBeforeCursor + textAfterCursor,
            rawTextBeforeCursor: textBeforeCursor,
            rawTextAfterCursor: textAfterCursor,
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .blocked(.shellCommandDetected))
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == nil)
    }

    @Test("Terminal-host proof does not recover current marker when same-line suffix remains")
    func terminalHostProofDoesNotRecoverCurrentMarkerWithSameLineSuffix() {
        let textBeforeCursor = """
        redbars@Mac % cd /Users/redbars/.codex/worktrees/32b9/transcripted-autocomplete-lab; /opt/homebrew/bin/claude Claude Code ❯ STEADYTYPECLAUDECODEPROOF Make this setting con
        """
        let textAfterCursor = """
        figu
        ╭────────────────────────────────────╮
        │ ? for shortcuts                    │
        ╰────────────────────────────────────╯
        """
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: textBeforeCursor + textAfterCursor,
            rawTextBeforeCursor: textBeforeCursor,
            rawTextAfterCursor: textAfterCursor,
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .blocked(.shellCommandDetected))
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == nil)

        let metadata = ClaudeCodeTerminalHostProofPolicy.diagnosticMetadata(for: context)
        #expect(metadata["terminalProofCanIgnoreAfterCursor"] == "false")
        #expect(metadata["terminalProofAfterFirstLineKind"] == "text")
        #expect(metadata["terminalProofRecoverableInput"] == "false")
        #expect(metadata["terminalProofRawBeforeLastLineKind"] == "marked")
    }

    @Test("Terminal-host proof does not recover command text from marked terminal screen")
    func terminalHostProofDoesNotRecoverCommandTextFromMarkedTerminalScreen() {
        let textBeforeCursor = """
        redbars@Mac % cd /Users/redbars/.codex/worktrees/32b9/transcripted-autocomplete-lab; /opt/homebrew/bin/claude Claude Code ❯ STEADYTYPECLAUDECODEPROOF git status
        """
        let textAfterCursor = """
        ╭────────────────────────────────────╮
        │ ? for shortcuts                    │
        ╰────────────────────────────────────╯
        """
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: textBeforeCursor + textAfterCursor,
            rawTextBeforeCursor: textBeforeCursor,
            rawTextAfterCursor: textAfterCursor,
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .blocked(.shellCommandDetected))
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == nil)
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

    @Test("Terminal-host proof keeps make command lines blocked")
    func terminalHostProofKeepsMakeCommandLinesBlocked() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: "make test",
            rawTextBeforeCursor: "make test",
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

    @Test("Eligible proof marker maps unsafe terminal field kind to proof compose")
    func eligibleProofMarkerMapsUnsafeTerminalFieldKindToProofCompose() {
        let raw = AXFieldClassification(
            kind: .unprovenSurface,
            reason: "unprovenSurface:zsh"
        )
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "Claude Code",
            focusedText: "AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF Make this setting con",
            rawTextBeforeCursor: "AUTOCOMPLETE_LAB_CLAUDE_CODE_PROOF Make this setting con",
            proofModeEnabled: true
        )

        let effective = ClaudeCodeTerminalHostProofPolicy.effectiveFieldClassification(
            raw: raw,
            for: context
        )

        #expect(effective.kind == .multilineCompose)
        #expect(effective.reason == "claude-code-terminal-host-proof")
    }

    @Test("iTerm proof can recover marked prompt from terminal screen text")
    func iTermProofCanRecoverMarkedPromptFromTerminalScreenText() {
        let raw = AXFieldClassification(
            kind: .unprovenSurface,
            reason: "unprovenSurface:zsh"
        )
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.googlecode.iterm2",
            windowTitle: "Claude Code",
            focusedText: "con",
            rawTextBeforeCursor: "con",
            terminalScreenText: """
            Claude Code
            ❯ Make this setting STEADYTYPECLAUDECODEPROOF con
            """,
            proofModeEnabled: true
        )

        let effective = ClaudeCodeTerminalHostProofPolicy.effectiveFieldClassification(
            raw: raw,
            for: context
        )
        let metadata = ClaudeCodeTerminalHostProofPolicy.diagnosticMetadata(for: context)

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == "Make this setting con")
        #expect(effective.kind == .multilineCompose)
        #expect(metadata["terminalProofScreenHasMarker"] == "true")
        #expect(metadata["terminalProofRecoverableInput"] == "true")
    }

    @Test("iTerm proof can recover wrapped prefix before terminal screen marker")
    func iTermProofCanRecoverWrappedPrefixBeforeTerminalScreenMarker() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.googlecode.iterm2",
            windowTitle: "Claude Code",
            focusedText: "con",
            rawTextBeforeCursor: "con",
            terminalScreenText: """
            Claude Code
            ❯ Make this setting
            STEADYTYPECLAUDECODEPROOF con
            ? for shortcuts
            """,
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == "Make this setting con")
    }

    @Test("Terminal screen marker recovery rejects marker-only tail text")
    func terminalScreenMarkerRecoveryRejectsMarkerOnlyTailText() {
        let raw = AXFieldClassification(
            kind: .unprovenSurface,
            reason: "unprovenSurface:zsh"
        )
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.googlecode.iterm2",
            windowTitle: "Claude Code",
            focusedText: "con",
            rawTextBeforeCursor: "con",
            terminalScreenText: """
            Claude Code
            STEADYTYPECLAUDECODEPROOF con
            """,
            proofModeEnabled: true
        )

        let effective = ClaudeCodeTerminalHostProofPolicy.effectiveFieldClassification(
            raw: raw,
            for: context
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == nil)
        #expect(effective == raw)
    }

    @Test("Terminal screen marker recovery must match current typed suffix")
    func terminalScreenMarkerRecoveryMustMatchCurrentTypedSuffix() {
        let raw = AXFieldClassification(
            kind: .unprovenSurface,
            reason: "unprovenSurface:zsh"
        )
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.googlecode.iterm2",
            windowTitle: "Claude Code",
            focusedText: "abc",
            rawTextBeforeCursor: "abc",
            terminalScreenText: """
            Claude Code
            ❯ Make this setting STEADYTYPECLAUDECODEPROOF con
            """,
            proofModeEnabled: true
        )

        let effective = ClaudeCodeTerminalHostProofPolicy.effectiveFieldClassification(
            raw: raw,
            for: context
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == nil)
        #expect(effective == raw)
    }

    @Test("Title-only terminal proof marker cannot validate focused tail text")
    func titleOnlyTerminalProofMarkerCannotValidateFocusedTailText() {
        let raw = AXFieldClassification(
            kind: .unprovenSurface,
            reason: "unprovenSurface:zsh"
        )
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.googlecode.iterm2",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: "con",
            rawTextBeforeCursor: "con",
            terminalScreenText: "",
            proofModeEnabled: true
        )

        let effective = ClaudeCodeTerminalHostProofPolicy.effectiveFieldClassification(
            raw: raw,
            for: context
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == nil)
        #expect(effective == raw)
    }

    @Test("Title-only terminal proof marker cannot validate half typed marker fragments")
    func titleOnlyTerminalProofMarkerCannotValidateHalfTypedMarkerFragments() {
        let raw = AXFieldClassification(
            kind: .unprovenSurface,
            reason: "unprovenSurface:zsh"
        )
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.googlecode.iterm2",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: "Make this setting STEADYTYPECLAUDECODE",
            rawTextBeforeCursor: "Make this setting STEADYTYPECLAUDECODE",
            terminalScreenText: "",
            proofModeEnabled: true
        )

        let effective = ClaudeCodeTerminalHostProofPolicy.effectiveFieldClassification(
            raw: raw,
            for: context
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == nil)
        #expect(effective == raw)
    }

    @Test("Ghostty proof can allow trusted sensitive activation bypass")
    func ghosttyProofCanAllowTrustedSensitiveActivationBypass() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.mitchellh.ghostty",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: "Make this setting the feature con",
            rawTextBeforeCursor: "Make this setting the feature con",
            terminalScreenText: "",
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == "Make this setting the feature con")
        #expect(ClaudeCodeTerminalHostProofPolicy.allowsSensitiveActivationBypass(
            for: context,
            proofInputText: "Make this setting the feature con"
        ))
    }

    @Test("Ghostty proof accepts title-scoped natural prompt text")
    func ghosttyProofAcceptsTitleScopedNaturalPromptText() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.mitchellh.ghostty",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: "Please make this",
            rawTextBeforeCursor: "Please make this",
            terminalScreenText: "",
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == "Please make this")
        #expect(ClaudeCodeTerminalHostProofPolicy.effectiveFieldClassification(
            raw: AXFieldClassification(kind: .unprovenSurface, reason: "unprovenSurface:terminal"),
            for: context
        ) == ClaudeCodeTerminalHostProofPolicy.proofFieldClassification)
    }

    @Test("Ghostty title-scoped proof rejects stale Claude header AX text")
    func ghosttyTitleScopedProofRejectsStaleClaudeHeaderAXText() {
        let raw = AXFieldClassification(
            kind: .unprovenSurface,
            reason: "unprovenSurface:terminal"
        )
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.mitchellh.ghostty",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: "Claude Code v2.1.150",
            rawTextBeforeCursor: "Claude Code v2.1.150",
            terminalScreenText: "",
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == nil)
        #expect(ClaudeCodeTerminalHostProofPolicy.effectiveFieldClassification(
            raw: raw,
            for: context
        ) == raw)
    }

    @Test("Ghostty title-scoped proof rejects stale date build AX text")
    func ghosttyTitleScopedProofRejectsStaleDateBuildAXText() {
        let raw = AXFieldClassification(
            kind: .unprovenSurface,
            reason: "unprovenSurface:terminal"
        )
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.mitchellh.ghostty",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: "build 2026-05-25 proof",
            rawTextBeforeCursor: "build 2026-05-25 proof",
            terminalScreenText: "",
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == nil)
        #expect(ClaudeCodeTerminalHostProofPolicy.effectiveFieldClassification(
            raw: raw,
            for: context
        ) == raw)
    }

    @Test("Ghostty proof prefers title-scoped screen prompt over stale AX text")
    func ghosttyProofPrefersTitleScopedScreenPromptOverStaleAXText() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.mitchellh.ghostty",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: "build 2026-05-25 proof",
            rawTextBeforeCursor: "build 2026-05-25 proof",
            terminalScreenText: """
            Claude Code STEADYTYPECLAUDECODEPROOF
            Some older output
            ❯ Make this setting the feature
            ╭────────────────────────────────────╮
            │ ? for shortcuts                    │
            ╰────────────────────────────────────╯
            """,
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == "Make this setting the feature")
        #expect(ClaudeCodeTerminalHostProofPolicy.effectiveFieldClassification(
            raw: AXFieldClassification(kind: .unprovenSurface, reason: "unprovenSurface:terminal"),
            for: context
        ) == ClaudeCodeTerminalHostProofPolicy.proofFieldClassification)

        let metadata = ClaudeCodeTerminalHostProofPolicy.diagnosticMetadata(for: context)
        #expect(metadata["terminalProofTitleScopedScreenRecoverable"] == "true")
        #expect(metadata["terminalProofTitleScopedScreenBeforeChars"] == "29")
    }

    @Test("Ghostty proof recovers marked screen prompt when AX exposes current input after cursor")
    func ghosttyProofRecoversMarkedScreenPromptWhenAXExposesCurrentInputAfterCursor() {
        let raw = AXFieldClassification(
            kind: .unprovenSurface,
            reason: "unprovenSurface:terminal"
        )
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.mitchellh.ghostty",
            windowTitle: "Claude Code",
            focusedText: "❯ Make this setting the feature con",
            rawTextBeforeCursor: "",
            rawTextAfterCursor: "❯ Make this setting the feature con\n? for shortcuts",
            terminalScreenText: """
            Claude Code
            ❯ Make this setting the feature STEADYTYPECLAUDECODEPROOF con
            ╭────────────────────────────────────╮
            │ ? for shortcuts                    │
            ╰────────────────────────────────────╯
            """,
            proofModeEnabled: true
        )

        let effective = ClaudeCodeTerminalHostProofPolicy.effectiveFieldClassification(
            raw: raw,
            for: context
        )
        let metadata = ClaudeCodeTerminalHostProofPolicy.diagnosticMetadata(for: context)

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == "Make this setting the feature con")
        #expect(effective == ClaudeCodeTerminalHostProofPolicy.proofFieldClassification)
        #expect(metadata["terminalProofRecoverableInput"] == "true")
        #expect(metadata["terminalProofRecoveryRejectionReason"] == "none")
        #expect(metadata["terminalProofScreenPromptSegmentPresent"] == "true")
        #expect(metadata["terminalProofScreenSegmentPresent"] == "true")
        #expect(metadata["terminalProofScreenRecoveryWouldRecover"] == "true")
        #expect(metadata["terminalProofScreenRecoveryMatchedCandidateIndex"] == "0")
        #expect(metadata["terminalProofScreenRecoveryMismatchCount"] == "0")
        #expect(metadata["terminalProofScreenCurrentSuffixMaxWords"] == "6")
    }

    @Test("Ghostty proof recovers header-scoped screen prompt from whole-screen AX after cursor")
    func ghosttyProofRecoversHeaderScopedScreenPromptFromWholeScreenAXAfterCursor() {
        let raw = AXFieldClassification(
            kind: .unprovenSurface,
            reason: "unprovenSurface:terminal"
        )
        let screenText = """
        Claude Code STEADYTYPECLAUDECODEPROOF
        Some older output
        ❯ Make this setting the feature con
        ╭────────────────────────────────────╮
        │ ? for shortcuts                    │
        ╰────────────────────────────────────╯
        """
        let rawAXText = """
        Claude Code
        Some older output
        ❯ Make this setting the feature con
        ╭────────────────────────────────────╮
        │ ? for shortcuts                    │
        ╰────────────────────────────────────╯
        """
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.mitchellh.ghostty",
            windowTitle: "Claude Code",
            focusedText: "Claude Code",
            rawTextBeforeCursor: "",
            rawTextAfterCursor: rawAXText,
            terminalScreenText: screenText,
            proofModeEnabled: true
        )

        let effective = ClaudeCodeTerminalHostProofPolicy.effectiveFieldClassification(
            raw: raw,
            for: context
        )
        let metadata = ClaudeCodeTerminalHostProofPolicy.diagnosticMetadata(for: context)

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == "Make this setting the feature con")
        #expect(effective == ClaudeCodeTerminalHostProofPolicy.proofFieldClassification)
        #expect(metadata["terminalProofTitleScopedScreenRecoverable"] == "true")
        #expect(metadata["terminalProofScreenHeaderScopedMarker"] == "true")
        #expect(metadata["terminalProofTitleScopedScreenCurrentContextMatched"] == "true")
        #expect(metadata["terminalProofHeaderScopedCurrentMatch"] == "true")
        #expect(metadata["terminalProofScreenRecoveryWouldRecover"] == "false")
    }

    @Test("Ghostty proof rejects header-scoped screen prompt without current AX match")
    func ghosttyProofRejectsHeaderScopedScreenPromptWithoutCurrentAXMatch() {
        let raw = AXFieldClassification(
            kind: .unprovenSurface,
            reason: "unprovenSurface:terminal"
        )
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.mitchellh.ghostty",
            windowTitle: "Claude Code",
            focusedText: "Claude Code",
            rawTextBeforeCursor: "",
            rawTextAfterCursor: """
            Claude Code
            Some older output
            """,
            terminalScreenText: """
            Claude Code STEADYTYPECLAUDECODEPROOF
            ❯ Make this setting the feature con
            ╭────────────────────────────────────╮
            │ ? for shortcuts                    │
            ╰────────────────────────────────────╯
            """,
            proofModeEnabled: true
        )

        let effective = ClaudeCodeTerminalHostProofPolicy.effectiveFieldClassification(
            raw: raw,
            for: context
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == nil)
        #expect(effective == raw)
    }

    @Test("Ghostty proof rejects marked screen prompt when after-cursor input mismatches")
    func ghosttyProofRejectsMarkedScreenPromptWhenAfterCursorInputMismatches() {
        let raw = AXFieldClassification(
            kind: .unprovenSurface,
            reason: "unprovenSurface:terminal"
        )
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.mitchellh.ghostty",
            windowTitle: "Claude Code",
            focusedText: "Please ignore this",
            rawTextBeforeCursor: "",
            rawTextAfterCursor: "Please ignore this\n? for shortcuts",
            terminalScreenText: """
            Claude Code
            ❯ Make this setting the feature STEADYTYPECLAUDECODEPROOF con
            ? for shortcuts
            """,
            proofModeEnabled: true
        )

        let effective = ClaudeCodeTerminalHostProofPolicy.effectiveFieldClassification(
            raw: raw,
            for: context
        )
        let metadata = ClaudeCodeTerminalHostProofPolicy.diagnosticMetadata(for: context)

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == nil)
        #expect(effective == raw)
        #expect(metadata["terminalProofRecoveryRejectionReason"]?.contains("screenCurrentInputMismatch") == true)
        #expect(metadata["terminalProofScreenRecoveryWouldRecover"] == "false")
        #expect(metadata["terminalProofScreenRecoveryMismatchCount"] == "1")
        #expect(metadata["terminalProofScreenRecoveryMatchedCandidateIndex"] == "-1")
    }

    @Test("Ghostty proof rejects header after-cursor text even when screen has marker")
    func ghosttyProofRejectsHeaderAfterCursorTextEvenWhenScreenHasMarker() {
        let raw = AXFieldClassification(
            kind: .unprovenSurface,
            reason: "unprovenSurface:terminal"
        )
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.mitchellh.ghostty",
            windowTitle: "Claude Code",
            focusedText: "Claude Code v2.1.150",
            rawTextBeforeCursor: "",
            rawTextAfterCursor: "Claude Code v2.1.150\n? for shortcuts",
            terminalScreenText: """
            Claude Code
            ❯ Make this setting the feature STEADYTYPECLAUDECODEPROOF con
            ? for shortcuts
            """,
            proofModeEnabled: true
        )

        let effective = ClaudeCodeTerminalHostProofPolicy.effectiveFieldClassification(
            raw: raw,
            for: context
        )
        let metadata = ClaudeCodeTerminalHostProofPolicy.diagnosticMetadata(for: context)

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .eligible)
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == nil)
        #expect(effective == raw)
        #expect(metadata["terminalProofScreenPromptSegmentPresent"] == "true")
        #expect(metadata["terminalProofScreenSegmentPresent"] == "true")
        #expect(metadata["terminalProofScreenCurrentSuffixCandidateCount"] == "0")
        #expect(metadata["terminalProofScreenRecoveryTriedCandidates"] == "0")
        #expect(metadata["terminalProofScreenRecoveryWouldRecover"] == "false")
    }

    @Test("Ghostty title-scoped screen recovery keeps shell commands blocked")
    func ghosttyTitleScopedScreenRecoveryKeepsShellCommandsBlocked() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.mitchellh.ghostty",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: "git status",
            rawTextBeforeCursor: "git status",
            terminalScreenText: """
            Claude Code STEADYTYPECLAUDECODEPROOF
            ❯ git status
            ╭────────────────────────────────────╮
            │ ? for shortcuts                    │
            ╰────────────────────────────────────╯
            """,
            proofModeEnabled: true
        )

        #expect(ClaudeCodeTerminalHostProofPolicy.evaluate(context) == .blocked(.shellCommandDetected))
        #expect(ClaudeCodeTerminalHostProofPolicy.proofInputText(for: context) == nil)
    }

    @Test("Ghostty proof sensitive activation bypass rejects mismatched or command input")
    func ghosttyProofSensitiveActivationBypassRejectsMismatchedOrCommandInput() {
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.mitchellh.ghostty",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: "Make this setting the feature con",
            rawTextBeforeCursor: "Make this setting the feature con",
            terminalScreenText: "",
            proofModeEnabled: true
        )
        let commandContext = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.mitchellh.ghostty",
            windowTitle: "Claude Code STEADYTYPECLAUDECODEPROOF",
            focusedText: "rm -rf local-fixture con",
            rawTextBeforeCursor: "rm -rf local-fixture con",
            terminalScreenText: "",
            proofModeEnabled: true
        )

        #expect(!ClaudeCodeTerminalHostProofPolicy.allowsSensitiveActivationBypass(
            for: context,
            proofInputText: "Make this setting the feature abc"
        ))
        #expect(!ClaudeCodeTerminalHostProofPolicy.allowsSensitiveActivationBypass(
            for: commandContext,
            proofInputText: "rm -rf local-fixture con"
        ))
    }

    @Test("Previously verified proof input can keep sensitive bypass after marker repair")
    func previouslyVerifiedProofInputCanKeepSensitiveBypassAfterMarkerRepair() {
        #expect(ClaudeCodeTerminalHostProofPolicy.allowsPreviouslyVerifiedSensitiveActivationBypass(
            proofInputText: "Make this setting the feature configurable"
        ))

        #expect(!ClaudeCodeTerminalHostProofPolicy.allowsPreviouslyVerifiedSensitiveActivationBypass(
            proofInputText: "rm -rf local-fixture con"
        ))
        #expect(!ClaudeCodeTerminalHostProofPolicy.allowsPreviouslyVerifiedSensitiveActivationBypass(
            proofInputText: "Make this setting STEADYTYPECLAUDECODE"
        ))
        #expect(!ClaudeCodeTerminalHostProofPolicy.allowsPreviouslyVerifiedSensitiveActivationBypass(
            proofInputText: "Make this"
        ))
    }

    @Test("Unsafe terminal proof keeps raw suppressed field kind")
    func unsafeTerminalProofKeepsRawSuppressedFieldKind() {
        let raw = AXFieldClassification(
            kind: .unprovenSurface,
            reason: "unprovenSurface:zsh"
        )
        let context = ClaudeCodeTerminalHostProofContext(
            hostBundleIdentifier: "com.apple.Terminal",
            windowTitle: "zsh",
            focusedText: "git status",
            rawTextBeforeCursor: "git status",
            proofModeEnabled: true
        )

        let effective = ClaudeCodeTerminalHostProofPolicy.effectiveFieldClassification(
            raw: raw,
            for: context
        )

        #expect(effective == raw)
    }
}
