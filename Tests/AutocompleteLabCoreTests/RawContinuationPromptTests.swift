import Testing
@testable import AutocompleteLabCore

@Suite("Raw continuation prompt")
struct RawContinuationPromptTests {
    @Test("Scaffold wraps the context tail without trailing whitespace")
    func scaffoldWrapsContextTail() {
        let prompt = RawContinuationPrompt(textBeforeCursor: "My main concern is the timeline, since we ")

        #expect(prompt.prompt.hasPrefix("The following are real documents"))
        #expect(prompt.prompt.hasSuffix("Text: My main concern is the timeline, since we\nContinuation:"))
        #expect(prompt.contextEndedInWhitespace)
    }

    @Test("Long context is trimmed from the left")
    func longContextTrimsFromLeft() {
        let words = (1...600).map { "word\($0)" }.joined(separator: " ")
        let prompt = RawContinuationPrompt(textBeforeCursor: words, maxContextCharacters: 200)

        #expect(!prompt.prompt.contains("word1 "))
        #expect(prompt.prompt.contains("word600"))
    }

    @Test("Normalization strips the duplicate separating space and stops at newlines")
    func normalizationHandlesSpacesAndNewlines() {
        let afterSpace = RawContinuationPrompt(textBeforeCursor: "since we ")
        #expect(afterSpace.normalizedContinuation(" need to hit the Q3 targets.") == "need to hit the Q3 targets.")
        #expect(afterSpace.normalizedContinuation(" first line\nsecond line") == "first line")

        let noSpace = RawContinuationPrompt(textBeforeCursor: "since we")
        #expect(noSpace.normalizedContinuation(" need approval") == " need approval")
    }
}

@Suite("Continuation register")
struct ContinuationRegisterTests {
    @Test("Bundle identity maps to the right register")
    func bundleIdentityMapsToRegister() {
        #expect(ContinuationRegister.from(bundleIdentifier: "com.tinyspeck.slackmacgap") == .chat)
        #expect(ContinuationRegister.from(bundleIdentifier: "com.anthropic.claudefordesktop") == .chat)
        #expect(ContinuationRegister.from(bundleIdentifier: "com.apple.mail") == .email)
        #expect(ContinuationRegister.from(bundleIdentifier: "com.mimestream.Mimestream") == .email)
        #expect(ContinuationRegister.from(bundleIdentifier: "com.apple.TextEdit") == .prose)
        #expect(ContinuationRegister.from(bundleIdentifier: nil) == .prose)
    }

    @Test("Register selects its scaffold voice and token budget")
    func registerSelectsScaffoldAndBudget() {
        let chat = RawContinuationPrompt(textBeforeCursor: "yeah ok ", register: .chat)
        #expect(chat.prompt.contains("Real chat messages"))
        let email = RawContinuationPrompt(textBeforeCursor: "Hi Sarah, ", register: .email)
        #expect(email.prompt.contains("Real emails"))
        let prose = RawContinuationPrompt(textBeforeCursor: "The report ")
        #expect(prose.prompt.contains("real documents"))
        #expect(ContinuationRegister.chat.generatedTokenBudget < ContinuationRegister.prose.generatedTokenBudget)
    }
}

@Suite("Continuation cutoff repair")
struct ContinuationCutoffRepairTests {
    @Test("Trailing function-word fragments are trimmed")
    func trailingFragmentsAreTrimmed() {
        let recipe = RawContinuationPrompt(textBeforeCursor: "I wanted to ")

        #expect(recipe.normalizedContinuation(" see if you had any thoughts on the") == "see if you had any thoughts")
        #expect(recipe.normalizedContinuation(" still make the meeting if") == "still make the meeting")
    }

    @Test("Finished thoughts are left alone")
    func finishedThoughtsAreLeftAlone() {
        let recipe = RawContinuationPrompt(textBeforeCursor: "I wanted to ")

        #expect(recipe.normalizedContinuation(" discuss the Q3 strategy in more detail.") == "discuss the Q3 strategy in more detail.")
        #expect(recipe.normalizedContinuation(" much more realistic for Q3.") == "much more realistic for Q3.")
    }
}

@Test("Empty context stays silent")
func emptyContextStaysSilent() {
    let empty = RawContinuationPrompt(textBeforeCursor: "", register: .chat)
    #expect(empty.prompt.isEmpty)

    let whitespaceOnly = RawContinuationPrompt(textBeforeCursor: "   ", register: .chat)
    #expect(whitespaceOnly.prompt.isEmpty)
}
