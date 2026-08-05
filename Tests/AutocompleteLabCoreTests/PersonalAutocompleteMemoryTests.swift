import Testing
@testable import AutocompleteLabCore

@Suite("Personal autocomplete memory")
struct PersonalAutocompleteMemoryTests {
    @Test("Personal words require two uses and fifty percent dominance")
    func personalWordThresholds() {
        var builder = PersonalAutocompleteMemoryBuilder()
        builder.observeVocabulary("Transcripted makes Transcripted searchable")
        let memory = builder.snapshot()

        #expect(memory.wordCompletion(for: "Tra") == "Transcripted")
        #expect(memory.wordCompletion(for: "Tran") == "Transcripted")
        #expect(memory.wordCompletion(for: "Trans") == "Transcripted")
        #expect(memory.wordCompletion(for: "Tr") == nil)
    }

    @Test("Ambiguous personal prefixes stay silent")
    func ambiguousPrefixStaysSilent() {
        var builder = PersonalAutocompleteMemoryBuilder()
        builder.observeVocabulary("Transcripted traction translate")
        let memory = builder.snapshot(wordMinimumSupport: 1)

        #expect(memory.wordCompletion(for: "tra") == nil)
    }

    @Test("Phrase retrieval requires conservative support and returns two examples")
    func conservativePhraseRetrieval() {
        var builder = PersonalAutocompleteMemoryBuilder()
        builder.observeOutcome(context: "I think we should", continuation: "ship it today")
        builder.observeOutcome(context: "Honestly we should", continuation: "ship and learn")
        builder.observeOutcome(context: "Maybe we should", continuation: "ship this now")
        builder.observeOutcome(context: "Perhaps we should", continuation: "wait a week")
        let memory = builder.snapshot()
        let examples = memory.examples(after: "Given the results, we should")

        #expect(examples.count == 2)
        #expect(examples.allSatisfy { $0.continuation.lowercased().hasPrefix("ship") })
        #expect(memory.examples(after: "we could").isEmpty)
    }

    @Test("Higher-support history survives a small live overlay")
    func mergePrefersHigherSupport() {
        let seed = PersonalAutocompleteMemory(
            wordPrefixes: [
                "tra": PersonalWordCandidate(word: "Transcripted", support: 20, totalPrefixSupport: 25)
            ]
        )
        let live = PersonalAutocompleteMemory(
            wordPrefixes: [
                "tra": PersonalWordCandidate(word: "traction", support: 2, totalPrefixSupport: 2)
            ]
        )

        #expect(seed.merging(live).wordCompletion(for: "tra") == "Transcripted")
    }
}
