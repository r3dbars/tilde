import Testing
@testable import AutocompleteLabCore

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
}
