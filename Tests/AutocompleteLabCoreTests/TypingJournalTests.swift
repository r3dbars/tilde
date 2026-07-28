import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Sensitive text scrubber")
struct SensitiveTextScrubberTests {
    @Test("Redacts card-shaped digit runs")
    func redactsCardNumbers() {
        #expect(SensitiveTextScrubber.scrub("my card is 4111 1111 1111 1111 thanks")
            == "my card is [redacted] thanks")
        #expect(SensitiveTextScrubber.scrub("4111-1111-1111-1111") == "[redacted]")
    }

    @Test("Redacts SSN shapes and long digit runs")
    func redactsSSNAndLongRuns() {
        #expect(SensitiveTextScrubber.scrub("ssn 123-45-6789 ok") == "ssn [redacted] ok")
        #expect(SensitiveTextScrubber.scrub("account 123456789012") == "account [redacted]")
    }

    @Test("Leaves ordinary text and short numbers alone")
    func leavesNormalTextAlone() {
        #expect(SensitiveTextScrubber.scrub("see you at 7:30, room 214")
            == "see you at 7:30, room 214")
        #expect(SensitiveTextScrubber.scrub("call me at noon") == "call me at noon")
        #expect(SensitiveTextScrubber.scrub("the year 2026 was wild") == "the year 2026 was wild")
    }
}

@Suite("Typing journal buffer")
struct TypingJournalBufferTests {
    @Test("Accumulates, backspaces, and flushes trimmed text")
    func accumulatesAndFlushes() {
        var buffer = TypingJournalBuffer()
        buffer.append("hey are we still on for dinner? ")
        buffer.append("x")
        buffer.backspace()
        #expect(buffer.flush() == "hey are we still on for dinner?")
        #expect(buffer.text.isEmpty)
    }

    @Test("Refuses to flush noise below the minimum")
    func refusesNoise() {
        var buffer = TypingJournalBuffer()
        buffer.append("ok thx")
        #expect(buffer.isFlushWorthy == false)
        #expect(buffer.flush() == nil)
    }

    @Test("Scrubs sensitive content on the way out")
    func scrubsOnFlush() {
        var buffer = TypingJournalBuffer()
        buffer.append("the card ends 4111 1111 1111 1111 use it once")
        #expect(buffer.flush() == "the card ends [redacted] use it once")
    }

    @Test("Signals size cap and idle correctly")
    func sizeCapAndIdle() {
        var buffer = TypingJournalBuffer()
        buffer.append(String(repeating: "a", count: TypingJournalBuffer.maximumBufferCharacters))
        #expect(buffer.isOverSizeCap)

        var idleBuffer = TypingJournalBuffer()
        let past = Date(timeIntervalSinceNow: -TypingJournalBuffer.idleFlushSeconds - 1)
        idleBuffer.append("some real writing here", at: past)
        #expect(idleBuffer.isIdle())
        #expect(TypingJournalBuffer().isIdle() == false)
    }
}
