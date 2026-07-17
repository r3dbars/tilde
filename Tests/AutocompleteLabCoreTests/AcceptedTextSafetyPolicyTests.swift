import Testing
@testable import AutocompleteLabCore

@Suite("Accepted text safety policy")
struct AcceptedTextSafetyPolicyTests {
    private let policy = AcceptedTextSafetyPolicy()

    @Test("Allows ordinary autocomplete text")
    func allowsOrdinaryAutocompleteText() throws {
        let textEdit = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))

        #expect(policy.decision(acceptedText: " make this easier", profile: textEdit) == .allowed)
    }

    @Test("Blocks line breaks before insertion")
    func blocksLineBreaksBeforeInsertion() throws {
        let textEdit = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))

        #expect(
            policy.decision(acceptedText: " send\n", profile: textEdit)
                == .blocked(reason: "accepted-text-line-break")
        )
        #expect(
            policy.decision(acceptedText: " send\r", profile: textEdit)
                == .blocked(reason: "accepted-text-line-break")
        )
    }

    @Test("Blocks literal tabs before insertion")
    func blocksLiteralTabsBeforeInsertion() throws {
        let textEdit = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))

        #expect(
            policy.decision(acceptedText: "\tcomplete", profile: textEdit)
                == .blocked(reason: "accepted-text-tab")
        )
    }

    @Test("Blocks other control characters before insertion")
    func blocksOtherControlCharactersBeforeInsertion() throws {
        let chrome = try #require(CompatibilityProfileStore.mvp.profile(for: "com.google.Chrome"))

        #expect(
            policy.decision(acceptedText: "safe\u{001B}", profile: chrome)
                == .blocked(reason: "accepted-text-control-character")
        )
    }

    @Test("Blocks empty accepted text")
    func blocksEmptyAcceptedText() throws {
        let notes = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.Notes"))

        #expect(
            policy.decision(acceptedText: "", profile: notes)
                == .blocked(reason: "accepted-text-empty")
        )
    }

    @Test("Prompt-safe profiles allow only one word")
    func promptSafeProfilesAllowOnlyOneWord() throws {
        let promptSafe = CompatibilityProfile(
            bundleIdentifier: "com.example.PromptSafe",
            displayName: "Prompt Safe",
            supportLevel: .yellow,
            supportReason: "Synthetic prompt-safe profile.",
            renderMode: .floatingMirror,
            insertionMode: .axValueReplacement,
            supportsFullAcceptance: false,
            promptAppSafetyMode: .wordOnly,
            notes: "Test profile."
        )
        let textEdit = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))

        #expect(policy.decision(acceptedText: " make", profile: promptSafe) == .allowed)
        #expect(policy.decision(acceptedText: "ing", profile: promptSafe) == .allowed)
        #expect(
            policy.decision(acceptedText: " make this", profile: promptSafe)
                == .blocked(reason: "accepted-text-multiword-full-disabled")
        )
        #expect(policy.decision(acceptedText: " make this", profile: textEdit) == .allowed)
    }

    @Test("Prompt full-accept proof profiles allow safe phrases")
    func promptFullAcceptProofProfilesAllowSafePhrases() {
        let promptFullAcceptProof = CompatibilityProfile(
            bundleIdentifier: "com.example.PromptSafe",
            displayName: "Prompt Safe",
            supportLevel: .yellow,
            supportReason: "Synthetic prompt-safe profile.",
            renderMode: .floatingMirror,
            insertionMode: .axValueReplacement,
            supportsFullAcceptance: true,
            requiresNoSubmitAcceptanceProof: false,
            promptAppSafetyMode: .wordOnly,
            notes: "Test profile."
        )

        #expect(
            policy.decision(acceptedText: " validate this next", profile: promptFullAcceptProof)
                == .allowed
        )
        #expect(
            policy.decision(acceptedText: " validate && submit", profile: promptFullAcceptProof)
                == .blocked(reason: "accepted-text-prompt-shell-metacharacter")
        )
        #expect(
            policy.decision(acceptedText: " /review this", profile: promptFullAcceptProof)
                == .blocked(reason: "accepted-text-prompt-command-prefix")
        )
    }

    @Test("Disabled profiles block insertion")
    func disabledProfilesBlockInsertion() {
        let disabled = CompatibilityProfile(
            bundleIdentifier: "com.example.Disabled",
            displayName: "Disabled",
            supportLevel: .unsupported,
            supportReason: "Test-only disabled profile.",
            renderMode: .disabled,
            insertionMode: .disabled,
            notes: "Test-only disabled profile."
        )

        #expect(
            policy.decision(acceptedText: " make", profile: disabled)
                == .blocked(reason: "profile-insertion-disabled")
        )
    }

    @Test("Prompt-safe profiles block command-like one-word accepts")
    func promptSafeProfilesBlockCommandLikeOneWordAccepts() throws {
        let promptSafe = CompatibilityProfile(
            bundleIdentifier: "com.example.PromptSafe",
            displayName: "Prompt Safe",
            supportLevel: .yellow,
            supportReason: "Synthetic prompt-safe profile.",
            renderMode: .floatingMirror,
            insertionMode: .axValueReplacement,
            supportsFullAcceptance: false,
            promptAppSafetyMode: .wordOnly,
            notes: "Test profile."
        )
        let textEdit = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))

        #expect(
            policy.decision(acceptedText: " /review", profile: promptSafe)
                == .blocked(reason: "accepted-text-prompt-command-prefix")
        )
        #expect(
            policy.decision(acceptedText: " @file", profile: promptSafe)
                == .blocked(reason: "accepted-text-prompt-command-prefix")
        )
        #expect(
            policy.decision(acceptedText: " --force", profile: promptSafe)
                == .blocked(reason: "accepted-text-prompt-command-prefix")
        )
        #expect(
            policy.decision(acceptedText: " curl", profile: promptSafe)
                == .blocked(reason: "accepted-text-prompt-action-word")
        )
        #expect(
            policy.decision(acceptedText: " deploy", profile: promptSafe)
                == .blocked(reason: "accepted-text-prompt-action-word")
        )
        #expect(
            policy.decision(
                acceptedText: " deploy",
                profile: promptSafe,
                allowsPromptActionWords: true
            ) == .allowed
        )
        #expect(
            policy.decision(
                acceptedText: " /review",
                profile: promptSafe,
                allowsPromptActionWords: true
            ) == .blocked(reason: "accepted-text-prompt-command-prefix")
        )
        #expect(
            policy.decision(
                acceptedText: " keep|send",
                profile: promptSafe,
                allowsPromptActionWords: true
            ) == .blocked(reason: "accepted-text-prompt-shell-metacharacter")
        )
        #expect(
            policy.decision(acceptedText: " keep|send", profile: promptSafe)
                == .blocked(reason: "accepted-text-prompt-shell-metacharacter")
        )
        #expect(
            policy.decision(acceptedText: " word\u{200B}", profile: promptSafe)
                == .blocked(reason: "accepted-text-hidden-control-character")
        )
        #expect(policy.decision(acceptedText: " /review", profile: textEdit) == .allowed)
    }
}
