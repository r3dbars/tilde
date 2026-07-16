import Testing
@testable import AutocompleteLabCore
@testable import AutocompleteLabResearch

@Suite("Recent word memory")
struct RecentWordMemoryTests {
    @Test("Remembers words in insertion order")
    func remembersWordsInInsertionOrder() {
        var memory = RecentWordMemory(capacity: 4)

        memory.remember(["dictation", "autocomplete"])
        memory.remember(["latency"])

        #expect(memory.words == ["dictation", "autocomplete", "latency"])
    }

    @Test("Keeps newest words within capacity")
    func keepsNewestWordsWithinCapacity() {
        var memory = RecentWordMemory(capacity: 3, words: ["one", "two", "three"])

        memory.remember(["four", "five"])

        #expect(memory.words == ["three", "four", "five"])
    }

    @Test("Initial words are capped")
    func initialWordsAreCapped() {
        let memory = RecentWordMemory(capacity: 2, words: ["old", "new", "newest"])

        #expect(memory.words == ["new", "newest"])
    }

    @Test("Scoped memory keeps app vocabulary separate")
    func scopedMemoryKeepsAppVocabularySeparate() {
        var memory = ScopedRecentWordMemory(capacityPerScope: 3)

        memory.remember(["obsidian"], scope: "md.obsidian")
        memory.remember(["chrome"], scope: "com.google.Chrome")

        #expect(memory.words(for: "md.obsidian") == ["obsidian"])
        #expect(memory.words(for: "com.google.Chrome") == ["chrome"])
        #expect(memory.words(for: "com.openai.codex") == [])
    }

    @Test("Scoped memory trims scope names and ignores empty scopes")
    func scopedMemoryTrimsScopeNamesAndIgnoresEmptyScopes() {
        var memory = ScopedRecentWordMemory(capacityPerScope: 2)

        memory.remember(["draft"], scope: "  com.apple.TextEdit  ")
        memory.remember(["ignored"], scope: "  ")

        #expect(memory.words(for: "com.apple.TextEdit") == ["draft"])
        #expect(memory.words(for: "") == [])
    }

    @Test("Scoped memory caps each app independently")
    func scopedMemoryCapsEachAppIndependently() {
        var memory = ScopedRecentWordMemory(capacityPerScope: 2)

        memory.remember(["one", "two", "three"], scope: "com.apple.TextEdit")
        memory.remember(["alpha", "beta"], scope: "md.obsidian")

        #expect(memory.words(for: "com.apple.TextEdit") == ["two", "three"])
        #expect(memory.words(for: "md.obsidian") == ["alpha", "beta"])
    }
}
