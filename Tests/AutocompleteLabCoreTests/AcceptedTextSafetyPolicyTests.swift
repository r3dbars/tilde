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
        let codex = try #require(CompatibilityProfileStore.mvp.profile(for: "com.openai.codex"))

        #expect(
            policy.decision(acceptedText: " send\n", profile: codex)
                == .blocked(reason: "accepted-text-line-break")
        )
        #expect(
            policy.decision(acceptedText: " send\r", profile: codex)
                == .blocked(reason: "accepted-text-line-break")
        )
    }

    @Test("Blocks literal tabs before insertion")
    func blocksLiteralTabsBeforeInsertion() throws {
        let claudeCode = try #require(CompatibilityProfileStore.mvp.profile(for: "com.anthropic.claude-code"))

        #expect(
            policy.decision(acceptedText: "\tcomplete", profile: claudeCode)
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
        let codex = try #require(CompatibilityProfileStore.mvp.profile(for: "com.openai.codex"))
        let textEdit = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))

        #expect(policy.decision(acceptedText: " make", profile: codex) == .allowed)
        #expect(policy.decision(acceptedText: "ing", profile: codex) == .allowed)
        #expect(
            policy.decision(acceptedText: " make this", profile: codex)
                == .blocked(reason: "accepted-text-multiword-full-disabled")
        )
        #expect(policy.decision(acceptedText: " make this", profile: textEdit) == .allowed)
    }
}
