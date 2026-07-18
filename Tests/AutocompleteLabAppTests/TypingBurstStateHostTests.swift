@testable import AutocompleteLabApp
import AutocompleteLabCore
import Testing

@Suite("Typing burst state host")
@MainActor
struct TypingBurstStateHostTests {
    @Test("retains burst samples across observations")
    func retainsBurstSamplesAcrossObservations() {
        let host = TypingBurstStateHost(
            policy: TypingBurstPolicy(
                windowMilliseconds: 1_000,
                minimumInsertedCharacters: 4,
                minimumEvents: 2,
                maximumSingleChangeCharacters: 4
            )
        )

        #expect(host.observe(previousTextBeforeCursor: "a", currentTextBeforeCursor: "abc", nowMilliseconds: 1) == .idle)
        #expect(host.observe(previousTextBeforeCursor: "abc", currentTextBeforeCursor: "abcde", nowMilliseconds: 2) == .burst(insertedCharacterCount: 4, eventCount: 2))
    }

    @Test("reset clears the owned sample window")
    func resetClearsOwnedSampleWindow() {
        let host = TypingBurstStateHost(
            policy: TypingBurstPolicy(minimumInsertedCharacters: 2, minimumEvents: 2)
        )

        _ = host.observe(previousTextBeforeCursor: "a", currentTextBeforeCursor: "ab", nowMilliseconds: 1)
        host.reset()

        #expect(host.observe(previousTextBeforeCursor: "ab", currentTextBeforeCursor: "abc", nowMilliseconds: 2) == .idle)
    }
}
