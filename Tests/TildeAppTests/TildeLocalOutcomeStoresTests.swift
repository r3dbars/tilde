import Foundation
import Testing
@testable import TildeApp
@testable import TildeCore

@Suite("Local outcome stores")
struct TildeLocalOutcomeStoresTests {
    @Test("Event and diary paths stay in separate owner-only folders")
    func pathsAreProfileScopedAndSeparate() {
        let home = URL(fileURLWithPath: "/tmp/tilde-outcome-home", isDirectory: true)
        let events = TildeLocalOutcomeStores.eventURL(homeDirectory: home, profile: .production)
        let diary = TildeLocalOutcomeStores.diaryURL(homeDirectory: home, profile: .production)
        #expect(events.lastPathComponent == "events.jsonl")
        #expect(diary.lastPathComponent == "diary.v1.jsonl")
        #expect(events.path.contains("Outcome Ledger"))
        #expect(diary.path.contains("Word Diary"))
        #expect(events.path.contains("Tilde"))
        #expect(!events.path.contains("acceptedText"))
        #expect(
            TildeLocalOutcomeStores.approximateBytes(homeDirectory: home, profile: .production) == 0
        )
    }

    @Test("A wipe bump is what the IME uses to stop rewriting deleted files")
    func wipeBumpsGeneration() {
        let suite = "tilde.test.outcome-ledger.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(3, forKey: PersonalHistorySettingsContract.outcomeLedgerGenerationKey)
        TildeLocalOutcomeStores.bumpGeneration(suiteName: suite)
        #expect(defaults.integer(forKey: PersonalHistorySettingsContract.outcomeLedgerGenerationKey) == 4)
        defaults.removePersistentDomain(forName: suite)
    }

    @Test("A failed event wipe still attempts to delete the word diary")
    func wipeDoesNotShortCircuit() throws {
        let home = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent("tilde-outcome-wipe-\(UUID().uuidString)", isDirectory: true)
        let suite = "tilde.test.outcome-wipe.\(UUID().uuidString)"
        defer {
            try? FileManager.default.removeItem(at: home)
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        }
        let event = TildeLocalOutcomeStores.eventURL(homeDirectory: home, profile: .production)
        let diary = TildeLocalOutcomeStores.diaryURL(homeDirectory: home, profile: .production)
        try FileManager.default.createDirectory(at: event, withIntermediateDirectories: true)
        let diaryHandle = try #require(SecureLocalStorage.openFileForAppending(at: diary))
        try diaryHandle.write(contentsOf: Data("owner-only diary fixture".utf8))
        try diaryHandle.close()

        #expect(!TildeLocalOutcomeStores.deleteAll(
            homeDirectory: home,
            profile: .production,
            suiteName: suite
        ))
        #expect(FileManager.default.fileExists(atPath: event.path))
        #expect(!FileManager.default.fileExists(atPath: diary.path))
        #expect(
            UserDefaults(suiteName: suite)?.integer(
                forKey: PersonalHistorySettingsContract.outcomeLedgerGenerationKey
            ) == 1
        )
    }
}
