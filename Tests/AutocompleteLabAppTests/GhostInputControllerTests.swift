import Testing
@testable import InlineGhostIME

@Suite("Dictionary suffix")
struct GhostInputControllerTests {
    @Test("Complete words do not grow into longer completions")
    func completeWordsStayComplete() {
        #expect(GhostInputController.dictionarySuffix(
            for: "the",
            candidates: ["the", "they", "there"]
        ).isEmpty)
        #expect(GhostInputController.dictionarySuffix(
            for: "AND",
            candidates: ["and", "android"]
        ).isEmpty)
    }

    @Test("Unfinished words keep a useful suffix")
    func unfinishedWordsComplete() {
        #expect(GhostInputController.dictionarySuffix(
            for: "inst",
            candidates: ["instant", "instead"]
        ) == "ant")
    }
}
