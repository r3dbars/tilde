import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabResearch

@Suite("Personal capture episode store")
struct PersonalCaptureEpisodeStoreTests {
    @Test("Writes episode snapshots and dashboard locally")
    func writesEpisodeSnapshotsAndDashboardLocally() throws {
        let fixture = try Fixture()
        let store = fixture.store
        var record = fixture.record(id: "episode-one")

        store.recordPresented(record)
        store.recordAction(
            suggestionID: "episode-one",
            appBundleIdentifier: "com.apple.TextEdit",
            outcome: .accepted,
            reason: "insertion-verified",
            acceptedText: "over today"
        )
        store.recordSurvival(
            suggestionID: "episode-one",
            appBundleIdentifier: "com.apple.TextEdit",
            acceptedText: "over today",
            checkpoint: "30s",
            survivalClass: AcceptanceSurvivalClass.exactKept.rawValue,
            tokenRecall: 1,
            normalizedEditDistance: 0
        )
        store.waitForPendingWrites()

        let jsonl = try String(contentsOf: fixture.episodeFileURL, encoding: .utf8)
        let dashboard = try String(contentsOf: fixture.dashboardFileURL, encoding: .utf8)

        #expect(jsonl.contains("\"id\":\"episode-one\""))
        #expect(jsonl.contains("\"outcome\":\"kept\""))
        #expect(jsonl.contains("over today"))
        #expect(dashboard.contains("Suggestion Episode Scorecard"))
        #expect(dashboard.contains("Kept: 1"))

        record.appendAction(.ignored, timestamp: "2026-05-24T12:00:03Z", reason: "ignored")
        #expect(record.actions.count == 2)
    }

    @Test("Late actions without a captured presentation are ignored")
    func lateActionsWithoutCapturedPresentationAreIgnored() throws {
        let fixture = try Fixture()

        fixture.store.recordAction(
            suggestionID: "late-one",
            appBundleIdentifier: "com.example.App",
            outcome: .dismissed,
            reason: "escape",
            metadata: ["typedSuffix": "raw typed text"]
        )
        fixture.store.waitForPendingWrites()

        #expect(!FileManager.default.fileExists(atPath: fixture.episodeFileURL.path))
    }

    @Test("Late raw accepted text does not create a placeholder episode")
    func lateRawAcceptedTextDoesNotCreatePlaceholderEpisode() throws {
        let fixture = try Fixture()

        fixture.store.recordAction(
            suggestionID: "late-accepted",
            appBundleIdentifier: "com.example.App",
            outcome: .accepted,
            reason: "insertion-verified",
            acceptedText: "raw accepted text"
        )
        fixture.store.recordSurvival(
            suggestionID: "late-survival",
            appBundleIdentifier: "com.example.App",
            acceptedText: "raw survived text",
            checkpoint: "30s",
            survivalClass: AcceptanceSurvivalClass.exactKept.rawValue,
            tokenRecall: 1,
            normalizedEditDistance: 0
        )
        fixture.store.waitForPendingWrites()

        #expect(!FileManager.default.fileExists(atPath: fixture.episodeFileURL.path))
    }

    @Test("Dashboard rebuilds from the current day episode file")
    func dashboardRebuildsFromCurrentDayEpisodeFile() throws {
        let fixture = try Fixture()

        fixture.store.recordPresented(fixture.record(id: "before-restart"))
        fixture.store.waitForPendingWrites()

        let restartedStore = PersonalCaptureEpisodeStore(
            folderURL: fixture.folderURL,
            calendar: fixture.calendar,
            now: { fixture.date }
        )
        restartedStore.recordPresented(fixture.record(id: "after-restart"))
        restartedStore.waitForPendingWrites()

        let dashboard = try String(contentsOf: fixture.dashboardFileURL, encoding: .utf8)
        #expect(dashboard.contains("Episodes: 2"))
        #expect(dashboard.contains("Shown: 2"))
        #expect(restartedStore.currentScorecard().total == 2)
    }

    @Test("Delete all removes local episode files")
    func deleteAllRemovesLocalEpisodeFiles() throws {
        let fixture = try Fixture()

        fixture.store.recordPresented(fixture.record(id: "episode-one"))
        fixture.store.waitForPendingWrites()
        #expect(FileManager.default.fileExists(atPath: fixture.folderURL.path))

        fixture.store.deleteAll()
        #expect(!FileManager.default.fileExists(atPath: fixture.folderURL.path))
    }

    private struct Fixture {
        let folderURL: URL
        let calendar: Calendar
        let date: Date
        let store: PersonalCaptureEpisodeStore
        let episodeFileURL: URL
        let dashboardFileURL: URL

        init() throws {
            folderURL = FileManager.default
                .temporaryDirectory
                .appendingPathComponent("PersonalCaptureEpisodeStoreTests-\(UUID().uuidString)")
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            self.calendar = calendar
            let fixedDate = Date(timeIntervalSince1970: 1_779_638_400)
            date = fixedDate
            store = PersonalCaptureEpisodeStore(
                folderURL: folderURL,
                calendar: calendar,
                now: { fixedDate }
            )
            episodeFileURL = folderURL.appendingPathComponent("2026-05-24.episodes.jsonl")
            dashboardFileURL = folderURL.appendingPathComponent("2026-05-24-dashboard.md")
        }

        func record(id: String) -> SuggestionEpisodeRecord {
            SuggestionEpisodeRecord(
                id: id,
                createdAt: "2026-05-24T12:00:00Z",
                appDisplayName: "TextEdit",
                appBundleIdentifier: "com.apple.TextEdit",
                fieldIdentity: "com.apple.TextEdit|pid:42|element:7",
                fieldKind: AXFieldKind.multilineCompose.rawValue,
                fieldKindReason: "textAreaRole",
                requestMode: CompletionRequestMode.phraseContinuation.rawValue,
                userTypedContext: "I can send that",
                replyContext: SuggestionEpisodeReplyContext(
                    source: VisiblePageContextSource.screenOCR.rawValue,
                    captureScope: VisiblePageContextCaptureScope.focusedRegion.rawValue,
                    text: "Can you send the latest build?"
                ),
                suggestedText: "over today",
                model: SuggestionEpisodeModelContext(
                    modelName: CompletionModelPolicy.mvp.model.rawValue,
                    runtime: "mlx",
                    asset: "gemma-4-e4b-it-OptiQ-4bit",
                    promptVersion: CompletionPromptBuilder.promptStyleIdentifier,
                    experimentArm: AutocompleteExperimentArm.length3Word.rawValue,
                    triggerReason: "model-result",
                    candidateSource: "app-model-result",
                    latencyMilliseconds: 180,
                    firstTokenLatencyMilliseconds: 90
                ),
                placement: SuggestionEpisodePlacementContext(
                    renderMode: SuggestionRenderMode.inlineAdjacent.rawValue,
                    anchorRect: "x=1,y=2,w=3,h=4",
                    textLineRect: "x=1,y=2,w=30,h=14",
                    panelRect: "x=1,y=18,w=80,h=24",
                    confidenceBand: "green"
                )
            )
        }
    }
}
