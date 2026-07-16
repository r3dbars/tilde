import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabResearch

@Suite("Personal capture journal writer")
struct PersonalCaptureJournalWriterTests {
    @Test("Writes only new local writing into daily Markdown")
    func writesOnlyNewLocalWritingIntoDailyMarkdown() throws {
        let fixture = try Fixture()
        let writer = fixture.writer
        let field = FocusedFieldIdentity(
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let first = FocusedTextSnapshot(
            fieldIdentity: field,
            textBeforeCursor: "Existing draft",
            textAfterCursor: ""
        )
        let second = FocusedTextSnapshot(
            fieldIdentity: field,
            textBeforeCursor: "Existing draft with my actual next sentence",
            textAfterCursor: ""
        )

        writer.recordSnapshotChange(previous: nil, current: first, context: fixture.context)
        writer.recordSnapshotChange(previous: first, current: second, context: fixture.context)
        writer.waitForPendingWrites()

        let markdown = try fixture.markdown()
        #expect(markdown.contains("# SteadyType Personal Capture - 2026-05-23"))
        #expect(markdown.contains("Local Justin dogfood journal"))
        #expect(markdown.contains("Field observed for personal capture"))
        #expect(markdown.contains("with my actual next sentence"))
        #expect(!markdown.contains("```text\nExisting draft\n```"))
    }

    @Test("Records accepted suggestions and five-star survival signals")
    func recordsAcceptedSuggestionsAndSurvivalSignals() throws {
        let fixture = try Fixture()
        let writer = fixture.writer

        writer.recordAcceptedSuggestion(
            acceptedText: "trust the tiny loop",
            context: fixture.context,
            suggestionID: "suggestion-1",
            acceptanceID: "acceptance-1",
            acceptMode: "acceptAll"
        )
        writer.recordAcceptanceSurvival(
            acceptedText: "trust the tiny loop",
            context: fixture.context,
            suggestionID: "suggestion-1",
            acceptanceID: "acceptance-1",
            acceptMode: "acceptAll",
            checkpoint: "30s",
            survivalClass: "exactKept",
            isStrongPositive: true
        )
        writer.waitForPendingWrites()

        let markdown = try fixture.markdown()
        #expect(markdown.contains("SteadyType accepted"))
        #expect(markdown.contains("SteadyType five-star signal"))
        #expect(markdown.contains("trust the tiny loop"))
        #expect(markdown.contains("Acceptance ID: `acceptance-1`"))
    }

    @Test("Delete all removes the personal capture folder")
    func deleteAllRemovesFolder() throws {
        let fixture = try Fixture()
        let field = FocusedFieldIdentity(
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 42,
            elementIdentifier: 7
        )

        fixture.writer.recordSnapshotChange(
            previous: FocusedTextSnapshot(fieldIdentity: field, textBeforeCursor: "A", textAfterCursor: ""),
            current: FocusedTextSnapshot(fieldIdentity: field, textBeforeCursor: "AB", textAfterCursor: ""),
            context: fixture.context
        )
        fixture.writer.waitForPendingWrites()
        #expect(FileManager.default.fileExists(atPath: fixture.folderURL.path))

        fixture.writer.deleteAll()
        #expect(!FileManager.default.fileExists(atPath: fixture.folderURL.path))
    }

    private struct Fixture {
        let folderURL: URL
        let writer: PersonalCaptureJournalWriter
        let context = PersonalCaptureJournalContext(
            appDisplayName: "TextEdit",
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentity: "com.apple.TextEdit|pid:42|element:7",
            fieldKind: .multilineCompose,
            fieldKindReason: "textAreaRole",
            source: "test"
        )

        init() throws {
            folderURL = FileManager.default
                .temporaryDirectory
                .appendingPathComponent("PersonalCaptureJournalWriterTests-\(UUID().uuidString)")
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            writer = PersonalCaptureJournalWriter(
                folderURL: folderURL,
                calendar: calendar,
                now: { Date(timeIntervalSince1970: 1_779_552_000) }
            )
        }

        func markdown() throws -> String {
            let fileURL = folderURL.appendingPathComponent("2026-05-23.md")
            return try String(contentsOf: fileURL, encoding: .utf8)
        }
    }
}
