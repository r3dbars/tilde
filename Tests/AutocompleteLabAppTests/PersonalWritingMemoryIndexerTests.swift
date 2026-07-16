import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("Personal writing memory indexer")
struct PersonalWritingMemoryIndexerTests {
    @Test("Builds the derived index and delete all clears disk and snapshot")
    func rebuildAndDeleteAll() throws {
        let fixture = try Fixture()
        fixture.writer.recordSnapshotChange(
            previous: fixture.snapshot(text: "Existing draft"),
            current: fixture.snapshot(text: "Existing draft keep the private writing loop small"),
            context: fixture.context
        )
        fixture.writer.waitForPendingWrites()

        fixture.indexer.rebuildAndWait()

        let memory = try #require(fixture.indexer.currentMemory())
        #expect(memory.profile.sampleCount == 1)
        #expect(FileManager.default.fileExists(atPath: fixture.indexer.path))
        let permissions = try FileManager.default.attributesOfItem(atPath: fixture.indexer.path)[.posixPermissions] as? NSNumber
        #expect(permissions?.intValue == 0o600)

        fixture.indexer.deleteAll()
        #expect(fixture.indexer.currentMemory() == nil)
        #expect(!FileManager.default.fileExists(atPath: fixture.indexer.path))
    }

    @Test("Indexes all daily journal files and lets decay lower old weight")
    func indexesAllHistory() throws {
        let fixture = try Fixture()
        try FileManager.default.createDirectory(
            at: fixture.folderURL,
            withIntermediateDirectories: true
        )
        try fixture.writeJournal(
            dayString: "2026-05-10",
            text: "keep the recent private writing corpus useful"
        )
        try fixture.writeJournal(
            dayString: "2026-04-01",
            text: "keep the older private writing corpus useful"
        )
        fixture.indexer.rebuildAndWait()

        #expect(fixture.indexer.currentMemory()?.profile.sampleCount == 2)
        #expect(Set(fixture.indexer.currentMemory()?.snippets.map(\.dayString) ?? []) == ["2026-04-01", "2026-05-10"])
    }

    @Test("Ignores a cached index from an old schema")
    func ignoresStaleSchemaCache() throws {
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PersonalWritingMemoryIndexerStaleSchemaTests-\(UUID().uuidString)")
        let indexURL = folderURL.appendingPathComponent("Index/personal-writing-memory.json")
        try FileManager.default.createDirectory(
            at: indexURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let staleMemory = PersonalWritingMemory(
            builtAtDay: "2026-07-15",
            schemaVersion: PersonalWritingMemory.currentSchemaVersion - 1
        )
        try JSONEncoder().encode(staleMemory).write(to: indexURL)

        let indexer = PersonalWritingMemoryIndexer(personalCaptureFolderURL: folderURL)

        #expect(indexer.currentMemory() == nil)
    }

    private struct Fixture {
        let folderURL: URL
        let writer: PersonalCaptureJournalWriter
        let indexer: PersonalWritingMemoryIndexer
        let field = FocusedFieldIdentity(
            bundleIdentifier: "com.apple.TextEdit",
            processIdentifier: 42,
            elementIdentifier: 7
        )
        let context = PersonalCaptureJournalContext(
            appDisplayName: "TextEdit",
            appBundleIdentifier: "com.apple.TextEdit",
            fieldIdentity: "com.apple.TextEdit|pid:42|element:7",
            fieldKind: .multilineCompose,
            fieldKindReason: "textAreaRole",
            source: "test"
        )

        init() throws {
            folderURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("PersonalWritingMemoryIndexerTests-\(UUID().uuidString)")
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let date = Date(timeIntervalSince1970: 1_779_552_000)
            writer = PersonalCaptureJournalWriter(
                folderURL: folderURL,
                calendar: calendar,
                now: { date }
            )
            indexer = PersonalWritingMemoryIndexer(
                personalCaptureFolderURL: folderURL,
                calendar: calendar,
                now: { date }
            )
        }

        func snapshot(text: String) -> FocusedTextSnapshot {
            FocusedTextSnapshot(fieldIdentity: field, textBeforeCursor: text, textAfterCursor: "")
        }

        func writeJournal(dayString: String, text: String) throws {
            let fileURL = folderURL.appendingPathComponent("\(dayString).md")
            try """
            # SteadyType Personal Capture

            ## 12:00:00 - TextEdit
            typed:
            ```text
            \(text)
            ```
            - App: `com.apple.TextEdit`
            - Kind: `multilineCompose`
            - Deleted chars: 0
            """.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
}
