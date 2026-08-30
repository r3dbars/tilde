import Foundation
import Testing
@testable import InlineGhostIME
@testable import TildeCore

@Suite("Outcome ledger wipe generation", .serialized)
struct GhostOutcomeLedgerGenerationTests {
    @Test("An unchanged generation emits one text-free dismissal")
    func currentOpportunityStillEmits() throws {
        let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent("tilde-generation-\(UUID().uuidString)", isDirectory: true)
        let suite = "tilde.test.outcome-generation.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer {
            GhostOutcomeLedger.finishTesting()
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }
        GhostOutcomeLedger.resetForTesting(homeDirectory: root, defaults: defaults)
        GhostOutcomeLedger.noteShown(
            sessionIdentifier: "synthetic-session",
            bundleIdentifier: "com.example.Editor",
            candidateCharacters: 5,
            candidateWordCount: 1,
            opportunityCharacters: 12,
            precedingCharacter: " ",
            excluded: false,
            at: Date(timeIntervalSince1970: 1_000)
        )
        GhostOutcomeLedger.noteDismissed(at: Date(timeIntervalSince1970: 1_001))
        let queuedCounts = defaults.dictionary(
            forKey: PersonalHistorySettingsContract.outcomeLedgerWriteCountsKey(0)
        ) as? [String: Int]
        #expect(queuedCounts?["attempted"] == 1)
        GhostOutcomeLedger.flush()

        let event = TextFreeOnlineEventFile.url(
            homeDirectory: root,
            supportDirectoryName: TildeProductProfile.current.supportDirectoryName
        )
        let lines = try Data(contentsOf: event).split(separator: 0x0A)
        #expect(lines.count == 1)
        #expect(!String(decoding: lines[0], as: UTF8.self).contains("synthetic-session"))
        #expect(defaults.dictionary(
            forKey: PersonalHistorySettingsContract.outcomeLedgerWriteCountsKey(0)
        ) as? [String: Int] == ["attempted": 1, "written": 1])
    }

    @Test("A failed event append is counted without touching the redirected target")
    func failedAppendIsCounted() throws {
        let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent("tilde-write-drop-\(UUID().uuidString)", isDirectory: true)
        let suite = "tilde.test.outcome-drop.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let event = TextFreeOnlineEventFile.url(
            homeDirectory: root,
            supportDirectoryName: TildeProductProfile.current.supportDirectoryName
        )
        let target = root.appendingPathComponent("sentinel.jsonl")
        defer {
            GhostOutcomeLedger.finishTesting()
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }
        try FileManager.default.createDirectory(
            at: event.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("sentinel\n".utf8).write(to: target)
        try FileManager.default.linkItem(at: target, to: event)
        GhostOutcomeLedger.resetForTesting(homeDirectory: root, defaults: defaults)
        GhostOutcomeLedger.noteShown(
            sessionIdentifier: "synthetic-session",
            bundleIdentifier: "com.example.Editor",
            candidateCharacters: 5,
            candidateWordCount: 1,
            opportunityCharacters: 12,
            precedingCharacter: " ",
            excluded: false,
            at: Date(timeIntervalSince1970: 1_000)
        )
        GhostOutcomeLedger.noteDismissed(at: Date(timeIntervalSince1970: 1_001))
        GhostOutcomeLedger.flush()

        #expect(try String(contentsOf: target, encoding: .utf8) == "sentinel\n")
        #expect(defaults.dictionary(
            forKey: PersonalHistorySettingsContract.outcomeLedgerWriteCountsKey(0)
        ) as? [String: Int] == ["attempted": 1, "dropped": 1])
    }

    @Test("Typing reschedules idle close and a watch cannot close on the stale deadline")
    func typingReschedulesIdleClose() throws {
        let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent("tilde-idle-close-\(UUID().uuidString)", isDirectory: true)
        let suite = "tilde.test.outcome-idle.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer {
            GhostOutcomeLedger.finishTesting()
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }
        GhostOutcomeLedger.resetForTesting(homeDirectory: root, defaults: defaults)
        GhostOutcomeLedger.configure {
            RetainedContextSnapshot(
                text: "word",
                utf16StartLocation: 0,
                caretLocation: 4,
                sourceDigestSHA256: TextFreeOnlineEvent.sessionDigest(
                    sessionIdentifier: "synthetic-session"
                )
            )
        }
        let shownAt = Date(timeIntervalSince1970: 1_000)
        let acceptedAt = shownAt.addingTimeInterval(40)
        GhostOutcomeLedger.noteShown(
            sessionIdentifier: "synthetic-session",
            bundleIdentifier: "com.example.Editor",
            candidateCharacters: 4,
            candidateWordCount: 1,
            opportunityCharacters: 12,
            precedingCharacter: " ",
            excluded: false,
            at: shownAt
        )
        GhostOutcomeLedger.noteAccepted(
            "word",
            kind: .all,
            insertionLocationUTF16: 0,
            remainderVisible: false,
            at: acceptedAt
        )
        GhostOutcomeLedger.noteTyped(at: shownAt.addingTimeInterval(50))

        let event = TextFreeOnlineEventFile.url(
            homeDirectory: root,
            supportDirectoryName: TildeProductProfile.current.supportDirectoryName
        )
        GhostOutcomeLedger.observeDueHorizons(now: shownAt.addingTimeInterval(100))
        GhostOutcomeLedger.flush()
        #expect(!FileManager.default.fileExists(atPath: event.path))

        GhostOutcomeLedger.observeDueHorizons(now: shownAt.addingTimeInterval(110))
        GhostOutcomeLedger.flush()
        #expect(FileManager.default.fileExists(atPath: event.path))
    }

    @Test("A wipe drops stale dismiss, typed-close, and privacy-exclusion opportunities")
    func staleOpportunitiesCannotRecreateDeletedFiles() throws {
        enum ClosingAction: CaseIterable {
            case dismiss
            case typedClose
            case privacyExclude
        }

        for action in ClosingAction.allCases {
            let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
                .appendingPathComponent("tilde-generation-\(UUID().uuidString)", isDirectory: true)
            let suite = "tilde.test.outcome-generation.\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suite))
            defaults.removePersistentDomain(forName: suite)
            defer {
                GhostOutcomeLedger.finishTesting()
                defaults.removePersistentDomain(forName: suite)
                try? FileManager.default.removeItem(at: root)
            }
            GhostOutcomeLedger.resetForTesting(homeDirectory: root, defaults: defaults)
            GhostOutcomeLedger.noteShown(
                sessionIdentifier: "synthetic-session",
                bundleIdentifier: "com.example.Editor",
                candidateCharacters: 5,
                candidateWordCount: 1,
                opportunityCharacters: 12,
                precedingCharacter: " ",
                excluded: false,
                at: Date(timeIntervalSince1970: 1_000)
            )
            defaults.set(
                1,
                forKey: PersonalHistorySettingsContract.outcomeLedgerGenerationKey
            )

            switch action {
            case .dismiss:
                GhostOutcomeLedger.noteDismissed(at: Date(timeIntervalSince1970: 1_001))
            case .typedClose:
                GhostOutcomeLedger.noteTyped(at: Date(timeIntervalSince1970: 1_001))
                GhostOutcomeLedger.closeIfGhostGone(
                    stillVisible: false,
                    at: Date(timeIntervalSince1970: 1_001)
                )
            case .privacyExclude:
                GhostOutcomeLedger.markPrivacyExcluded()
            }
            GhostOutcomeLedger.flush()

            let event = TextFreeOnlineEventFile.url(
                homeDirectory: root,
                supportDirectoryName: TildeProductProfile.current.supportDirectoryName
            )
            let diary = LocalOutcomeDiaryFile.url(
                homeDirectory: root,
                supportDirectoryName: TildeProductProfile.current.supportDirectoryName
            )
            #expect(!FileManager.default.fileExists(atPath: event.path))
            #expect(!FileManager.default.fileExists(atPath: diary.path))
            GhostOutcomeLedger.finishTesting()
        }
    }
}
