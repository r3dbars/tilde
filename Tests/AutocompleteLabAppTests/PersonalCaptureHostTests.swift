import Foundation
import Testing
@testable import AutocompleteLabApp

@MainActor
@Suite("Personal capture host")
struct PersonalCaptureHostTests {
    @Test("Keeps episode outcome mapping stable behind the host")
    func mapsEpisodeOutcomes() {
        let host = makeHost()

        #expect(host.episodeOutcome(hiddenOutcome: "", reason: "escape") == .dismissed)
        #expect(host.episodeOutcome(hiddenOutcome: "accepted", reason: "") == .unknown)
        #expect(host.episodeOutcome(hiddenOutcome: "typed-over", reason: "") == .typedPast)
        #expect(host.episodeOutcome(hiddenOutcome: "", reason: "insertion-failed") == .insertionFailed)
        #expect(host.episodeOutcome(hiddenOutcome: "ignored", reason: "") == .ignored)
    }

    @Test("Disabled capture host exposes an empty local scorecard")
    func disabledHostHasNoCapturedEpisodes() {
        let host = makeHost(enabled: false)

        #expect(host.currentScorecard().total == 0)
        host.resetSnapshot()
        host.deleteAll()
    }

    @Test("AppDelegate delegates personal capture record construction")
    func appDelegateUsesPersonalCaptureHost() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appDelegate = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/AppDelegate.swift"),
            encoding: .utf8
        )
        let host = try String(
            contentsOf: root.appendingPathComponent("Sources/AutocompleteLabApp/App/PersonalCaptureHost.swift"),
            encoding: .utf8
        )

        #expect(appDelegate.contains("private lazy var personalCaptureHost = PersonalCaptureHost"))
        #expect(appDelegate.contains("personalCaptureHost.recordSuggestionEpisodePresented"))
        #expect(!appDelegate.contains("let record = SuggestionEpisodeRecord("))
        #expect(host.contains("includeText: true"))
        #expect(host.contains("personal-capture-blocked"))
    }
}

@MainActor
private func makeHost(enabled: Bool = true) -> PersonalCaptureHost {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("steadytype-personal-capture-host-\(UUID().uuidString)", isDirectory: true)
    let journal = PersonalCaptureJournalWriter(folderURL: root.appendingPathComponent("journal"))
    let episodes = PersonalCaptureEpisodeStore(folderURL: root.appendingPathComponent("episodes"))
    return PersonalCaptureHost(
        dependencies: PersonalCaptureHostDependencies(
            isEnabled: { enabled },
            runtimeDiagnosticsMetadata: { [:] },
            fingerprintSecret: { Data("test-secret".utf8) },
            compactRect: { _ in "none" }
        ),
        journal: journal,
        episodes: episodes
    )
}
