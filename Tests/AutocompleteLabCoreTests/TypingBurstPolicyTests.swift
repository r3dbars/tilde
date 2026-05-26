import Testing
@testable import AutocompleteLabCore

@Suite("Typing burst policy")
struct TypingBurstPolicyTests {
    @Test("Slow typing stays idle")
    func slowTypingStaysIdle() {
        let policy = TypingBurstPolicy(windowMilliseconds: 300, minimumInsertedCharacters: 4, minimumEvents: 3)
        var state = TypingBurstState()

        #expect(policy.observe(
            previousTextBeforeCursor: "Make",
            currentTextBeforeCursor: "Make ",
            nowMilliseconds: 0,
            state: &state
        ) == .idle)
        #expect(policy.observe(
            previousTextBeforeCursor: "Make ",
            currentTextBeforeCursor: "Make t",
            nowMilliseconds: 500,
            state: &state
        ) == .idle)
    }

    @Test("Fast repeated character inserts become a burst")
    func fastRepeatedCharacterInsertsBecomeBurst() {
        let policy = TypingBurstPolicy(windowMilliseconds: 500, minimumInsertedCharacters: 4, minimumEvents: 3)
        var state = TypingBurstState()

        _ = policy.observe(previousTextBeforeCursor: "Make", currentTextBeforeCursor: "Make ", nowMilliseconds: 0, state: &state)
        _ = policy.observe(previousTextBeforeCursor: "Make ", currentTextBeforeCursor: "Make t", nowMilliseconds: 80, state: &state)
        _ = policy.observe(
            previousTextBeforeCursor: "Make t",
            currentTextBeforeCursor: "Make th",
            nowMilliseconds: 160,
            state: &state
        )
        let decision = policy.observe(
            previousTextBeforeCursor: "Make th",
            currentTextBeforeCursor: "Make thi",
            nowMilliseconds: 240,
            state: &state
        )

        #expect(decision == .burst(insertedCharacterCount: 4, eventCount: 4))
        #expect(decision.shouldSuppressSuggestions)
        #expect(decision.shouldSuppressPhraseContinuation)
        #expect(decision.shouldSuppress(requestMode: .phraseContinuation))
        #expect(decision.shouldSuppress(requestMode: .sentenceContinuation))
        #expect(!decision.shouldSuppress(requestMode: .wordCompletion))
        #expect(!decision.shouldSuppress(requestMode: nil))
        #expect(decision.traceMetadata["typingBurst"] == "true")
        #expect(decision.traceMetadata["typingBurstInsertedCharacters"] == "4")
        #expect(decision.traceMetadata["typingBurstEvents"] == "4")
    }

    @Test("Deletion resets burst tracking")
    func deletionResetsBurstTracking() {
        let policy = TypingBurstPolicy(windowMilliseconds: 500, minimumInsertedCharacters: 3, minimumEvents: 2)
        var state = TypingBurstState()

        _ = policy.observe(previousTextBeforeCursor: "Make", currentTextBeforeCursor: "Make ", nowMilliseconds: 0, state: &state)
        _ = policy.observe(previousTextBeforeCursor: "Make ", currentTextBeforeCursor: "Make", nowMilliseconds: 80, state: &state)
        let decision = policy.observe(
            previousTextBeforeCursor: "Make",
            currentTextBeforeCursor: "Make t",
            nowMilliseconds: 120,
            state: &state
        )

        #expect(decision == .idle)
    }

    @Test("Paste-sized changes do not count as typing burst")
    func pasteSizedChangesDoNotCountAsTypingBurst() {
        let policy = TypingBurstPolicy(maximumSingleChangeCharacters: 4)
        var state = TypingBurstState()

        let decision = policy.observe(
            previousTextBeforeCursor: "Make ",
            currentTextBeforeCursor: "Make this whole sentence",
            nowMilliseconds: 0,
            state: &state
        )

        #expect(decision == .idle)
    }
}
