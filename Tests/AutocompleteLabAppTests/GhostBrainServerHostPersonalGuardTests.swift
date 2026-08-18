import Foundation
import Testing
@testable import AutocompleteLabApp
@testable import AutocompleteLabCore

@Suite("Personal serving mid-word guard")
struct GhostBrainServerHostPersonalGuardTests {
    @Test("Word-boundary context yields tail words")
    func wordBoundaryYieldsTailWords() {
        let tailWords = GhostBrainServerHost.personalTailWords(fromContext: "see you tomorrow ")
        #expect(tailWords == ["you", "tomorrow"])
    }

    @Test("Mid-word context is refused, never handed to the personal model")
    func midWordContextIsRefused() {
        // Cursor sits right after "tomo" — the word isn't finished yet. If
        // this were tokenized as a tail word, a confident personal
        // prediction for "tomorrow" could be glued straight onto it
        // ("tomotomorrow").
        let tailWords = GhostBrainServerHost.personalTailWords(fromContext: "see you tomo")
        #expect(tailWords.isEmpty)
    }

    @Test("Empty context yields no tail words")
    func emptyContextYieldsNoTailWords() {
        #expect(GhostBrainServerHost.personalTailWords(fromContext: "").isEmpty)
    }
}

/// "P99 at every section" (2026-08-18): the personal-brain lookup's
/// duration/outcome instrumentation. `performCapture`-shaped socket code is
/// not unit-testable (see `ScreenCaptureServiceTests`'s doc comment for the
/// same reason), but `awaitPersonalPrediction` itself takes injectable
/// `now`/`diagnostics` closures precisely so this race's outcome vocabulary
/// can be proven without a live socket or a live `PersonalHistoryController`.
@Suite("Personal lookup timing")
struct GhostBrainServerHostPersonalLookupTimingTests {
    private func recordingDiagnostics() -> (
        sink: @Sendable (String, [String: String]) -> Void,
        events: EventBox
    ) {
        let box = EventBox()
        let sink: @Sendable (String, [String: String]) -> Void = { event, metadata in
            box.append((event, metadata))
        }
        return (sink, box)
    }

    @Test("A nil task (gate off, no provider, or no tail words) reports outcome=disabled and waited=0")
    func nilTaskReportsDisabled() async {
        let (sink, events) = recordingDiagnostics()
        let prediction = await GhostBrainServerHost.awaitPersonalPrediction(
            nil,
            now: { Date() },
            diagnostics: sink
        )
        #expect(prediction == nil)
        let logged = events.values.first { $0.0 == "personal-lookup-timing" }
        #expect(logged?.1["outcome"] == "disabled")
        #expect(logged?.1["waitedMilliseconds"] == "0")
    }

    @Test("A task that resolves before the deadline reports outcome=resolved with its own prediction")
    func fastTaskReportsResolved() async {
        let (sink, events) = recordingDiagnostics()
        let task = Task<PersonalNextWordPrediction?, Never> {
            PersonalNextWordPrediction(word: "tomorrow", support: 4, total: 4)
        }
        let prediction = await GhostBrainServerHost.awaitPersonalPrediction(
            task,
            now: { Date() },
            diagnostics: sink
        )
        #expect(prediction?.word == "tomorrow")
        let logged = events.values.first { $0.0 == "personal-lookup-timing" }
        #expect(logged?.1["outcome"] == "resolved")
        #expect(logged?.1["waitedMilliseconds"].flatMap { Int($0) }.map { $0 >= 0 } == true)
    }

    @Test("A task that resolves with nil still reports outcome=resolved, not timeout — value and outcome are independent")
    func resolvedNilIsStillResolved() async {
        let (sink, events) = recordingDiagnostics()
        let task = Task<PersonalNextWordPrediction?, Never> { nil }
        let prediction = await GhostBrainServerHost.awaitPersonalPrediction(
            task,
            now: { Date() },
            diagnostics: sink
        )
        #expect(prediction == nil)
        let logged = events.values.first { $0.0 == "personal-lookup-timing" }
        #expect(logged?.1["outcome"] == "resolved")
    }

    @Test("A task slower than the 250ms deadline reports outcome=timeout")
    func slowTaskReportsTimeout() async {
        let (sink, events) = recordingDiagnostics()
        let task = Task<PersonalNextWordPrediction?, Never> {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            return PersonalNextWordPrediction(word: "late", support: 4, total: 4)
        }
        let prediction = await GhostBrainServerHost.awaitPersonalPrediction(
            task,
            now: { Date() },
            diagnostics: sink
        )
        #expect(prediction == nil)
        let logged = events.values.first { $0.0 == "personal-lookup-timing" }
        #expect(logged?.1["outcome"] == "timeout")
        task.cancel()
    }

    @Test("milliseconds rounds to the nearest whole millisecond, matching ScreenCaptureService's rounding")
    func millisecondsRoundsToNearest() {
        let start = Date(timeIntervalSince1970: 0)
        #expect(GhostBrainServerHost.milliseconds(from: start, to: start.addingTimeInterval(0.1874)) == 187)
        #expect(GhostBrainServerHost.milliseconds(from: start, to: start.addingTimeInterval(0.1876)) == 188)
    }

    @Test("milliseconds floors at zero for a clock that does not advance")
    func millisecondsFloorsAtZero() {
        let instant = Date(timeIntervalSince1970: 1_000)
        #expect(GhostBrainServerHost.milliseconds(from: instant, to: instant) == 0)
        #expect(GhostBrainServerHost.milliseconds(from: instant, to: instant.addingTimeInterval(-1)) == 0)
    }
}
