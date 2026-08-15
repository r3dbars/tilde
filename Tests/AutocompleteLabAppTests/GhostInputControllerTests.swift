import Testing
@testable import InlineGhostIME

@Suite("Ghost input controller")
struct GhostInputControllerTests {
    @Test("Slow-key timing separates queue delay from handler work")
    func slowKeyTiming() throws {
        let timing = try #require(GhostInputController.slowKeyTiming(
            eventTimestamp: 10,
            handlerStartedAt: 10.060,
            handlerFinishedAt: 10.080
        ))
        #expect(timing.totalMilliseconds == 80)
        #expect(timing.queuedMilliseconds == 60)
        #expect(timing.handlerMilliseconds == 20)
        #expect(GhostInputController.slowKeyTiming(
            eventTimestamp: 10,
            handlerStartedAt: 10.020,
            handlerFinishedAt: 10.049
        ) == nil)
    }

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
