import Foundation
import Testing
@testable import AutocompleteLabCore

@Suite("Personal writing memory builder")
struct PersonalWritingMemoryBuilderTests {
    @Test("Builds bounded decayed n-grams snippets and profile")
    func buildsBoundedMemory() throws {
        let now = try #require(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 7, day: 15)))
        let entries = [
            entry("The launch note should keep the proof focused today.", day: "2026-07-15"),
            entry("The launch note should keep the proof focused tomorrow.", day: "2026-07-01")
        ]
        let memory = PersonalWritingMemoryBuilder(maximumNGramKeys: 3, maximumSnippets: 1).build(entries: entries, now: now)

        #expect(memory.ngramContinuations.count == 3)
        #expect(memory.snippets.count == 1)
        #expect(memory.profile.sampleCount == 2)
        #expect(memory.profile.promptGuidance?.count ?? 0 <= 300)
        let recentWeight = memory.ngramContinuations.values.flatMap { $0 }.map(\.weight).max() ?? 0
        #expect(recentWeight > 0.9)
    }

    @Test("Drops short and secret-shaped corpus text")
    func dropsUnsafeText() {
        let entries = [
            entry("only two"),
            entry("contact private@example.com about the launch"),
            entry("use recovery code 123456 before continuing"),
            entry("token A9f2K7m4Q8z1X6p3V0n5 should stay private"),
            entry("ordinary project writing stays available locally")
        ]
        let memory = PersonalWritingMemoryBuilder().build(entries: entries)
        let allText = memory.snippets.map(\.text).joined(separator: " ")

        #expect(memory.profile.sampleCount == 1)
        #expect(allText.contains("ordinary project writing"))
        #expect(!allText.contains("private@example.com"))
        #expect(!allText.contains("123456"))
        #expect(!allText.contains("A9f2K7"))
    }

    @Test("Snippet cap prefers newest entries regardless of input order")
    func snippetCapPrefersNewest() {
        let entries = [
            entry("Newest writing should survive the bounded memory", day: "2026-07-15"),
            entry("Old writing should leave the bounded memory", day: "2026-06-01")
        ]
        let memory = PersonalWritingMemoryBuilder(maximumSnippets: 1).build(entries: entries)
        #expect(memory.snippets.map(\.text) == ["Newest writing should survive the bounded memory"])
    }

    private func entry(_ text: String, day: String = "2026-07-15") -> PersonalCaptureJournalEntry {
        PersonalCaptureJournalEntry(
            kind: .typed,
            timeString: "12:00:00",
            appBundleIdentifier: "com.apple.Notes",
            fieldKind: .multilineCompose,
            text: text,
            dayString: day
        )
    }
}
