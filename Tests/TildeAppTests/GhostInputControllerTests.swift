import AppKit
import Testing
@testable import InlineGhostIME

@Suite("Ghost input controller")
struct GhostInputControllerTests {
    @Test("The backtick/tilde key accepts all while modified chords remain printable")
    func tildeFullAcceptShortcut() {
        #expect(GhostInputController.shouldAcceptWholeSuggestion(
            keyCode: 50,
            modifiers: [.shift]
        ))
        #expect(GhostInputController.shouldAcceptWholeSuggestion(
            keyCode: 50,
            modifiers: []
        ))
        #expect(GhostInputController.shouldAcceptWholeSuggestion(
            keyCode: 50,
            modifiers: [.capsLock]
        ))
        #expect(!GhostInputController.shouldAcceptWholeSuggestion(
            keyCode: 50,
            modifiers: [.shift, .command]
        ))
        #expect(!GhostInputController.shouldAcceptWholeSuggestion(
            keyCode: 48,
            modifiers: [.shift]
        ))
    }

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

    @Test("Trailing context reads are bounded and require a caret")
    func trailingContextRangeIsSafe() {
        #expect(GhostInputController.trailingContextRange(
            selection: NSRange(location: 20, length: 0),
            markedRange: NSRange(location: NSNotFound, length: 0),
            documentLength: 150
        ) == NSRange(location: 20, length: 80))
        #expect(GhostInputController.trailingContextRange(
            selection: NSRange(location: 20, length: 0),
            markedRange: NSRange(location: NSNotFound, length: 0),
            documentLength: 25
        ) == NSRange(location: 20, length: 5))
        #expect(GhostInputController.trailingContextRange(
            selection: NSRange(location: 20, length: 0),
            markedRange: NSRange(location: 20, length: 8),
            documentLength: 35
        ) == NSRange(location: 28, length: 7))
        #expect(GhostInputController.trailingContextRange(
            selection: NSRange(location: 25, length: 0),
            markedRange: NSRange(location: NSNotFound, length: 0),
            documentLength: 25
        ) == nil)
        #expect(GhostInputController.trailingContextRange(
            selection: NSRange(location: 20, length: 3),
            markedRange: NSRange(location: NSNotFound, length: 0),
            documentLength: 25
        ) == nil)
    }

    @Test("Password managers stay excluded from the outcome watch")
    func passwordManagersAreExcluded() {
        #expect(
            GhostInputController.isOutcomeExcluded(
                bundleIdentifier: "com.1password.1password",
                secureInput: false
            )
        )
        #expect(
            !GhostInputController.isOutcomeExcluded(
                bundleIdentifier: "com.apple.mail",
                secureInput: false
            )
        )
        #expect(
            GhostInputController.isOutcomeExcluded(
                bundleIdentifier: "com.apple.mail",
                secureInput: true
            )
        )
    }
}
