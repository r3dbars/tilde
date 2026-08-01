import Testing
@testable import AutocompleteLabCore

@Suite("Mid-word grammar")
struct MidwordGrammarTests {
    let vocab = WordVocabulary(words: [
        "tomorrow", "tomorrows", "tomato", "the", "there", "Naomi", "gonna",
    ])

    @Test("Prefix is the trailing word fragment")
    func prefixExtraction() {
        #expect(MidwordGrammar.prefix(of: "see you tomo") == "tomo")
        #expect(MidwordGrammar.prefix(of: "that's") == "that's")
    }

    @Test("No prefix at a word boundary or after punctuation")
    func noPrefixAtBoundary() {
        #expect(MidwordGrammar.prefix(of: "see you ") == nil)
        #expect(MidwordGrammar.prefix(of: "see you!") == nil)
        #expect(MidwordGrammar.prefix(of: "") == nil)
    }

    @Test("Non-ASCII fragments get no grammar — never forbid the word being typed")
    func nonASCIISkipped() {
        #expect(MidwordGrammar.prefix(of: "café") == nil)
    }

    @Test("Trie grammar lists exactly the legal completions, shortest first")
    func trieGrammar() {
        let g = MidwordGrammar.grammar(textBeforeCursor: "see you tomo",
                                       vocabulary: vocab)
        #expect(g == "root ::= (\"rrow\" | \"rrows\") tail?\ntail ::= [ .,!?] [ -~]*\n")
    }

    @Test("Vocabulary matches case-insensitively — typing 'nao' finds Naomi")
    func caseInsensitive() {
        #expect(vocab.completions(of: "Nao", limit: 10) == ["mi"])
        #expect(vocab.completions(of: "nao", limit: 10) == ["mi"])
    }

    @Test("Unknown prefix falls back to the letters grammar, never silence")
    func unknownPrefixFallsBack() {
        let g = MidwordGrammar.grammar(textBeforeCursor: "ping zzq",
                                       vocabulary: vocab)
        #expect(g == MidwordGrammar.letters)
    }

    @Test("Missing vocabulary still constrains to word characters")
    func noVocabularyUsesLetters() {
        let g = MidwordGrammar.grammar(textBeforeCursor: "see you tomo",
                                       vocabulary: nil)
        #expect(g == MidwordGrammar.letters)
    }

    @Test("A word already complete in the vocabulary still offers longer words")
    func completeWordStillExtends() {
        #expect(vocab.completions(of: "the", limit: 10) == ["re"])
    }

    @Test("Completion cap bounds the grammar size")
    func capRespected() {
        let big = WordVocabulary(words: (0..<500).map { "prefix\(String(repeating: "a", count: $0 + 1))" })
        #expect(big.completions(of: "prefix", limit: 300).count == 300)
    }
}
