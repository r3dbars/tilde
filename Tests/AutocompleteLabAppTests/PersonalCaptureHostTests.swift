import Foundation
import CoreGraphics
import AutocompleteLabCore
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

    @Test("Disabled capture host does not write local data")
    func disabledHostHasNoCapturedEpisodes() {
        let host = makeHost(enabled: false)

        host.recordSnapshot(
            context: makeContext(isSecure: false),
            app: makeApp(),
            fieldIdentity: makeField(),
            fieldClassification: AXFieldClassification(kind: .singlelineCompose, reason: "test"),
            snapshot: FocusedTextSnapshot(
                fieldIdentity: makeField(),
                textBeforeCursor: "private",
                textAfterCursor: ""
            ),
            source: "test"
        )
        #expect(!FileManager.default.fileExists(atPath: host.folderPath))
        host.resetSnapshot()
        host.deleteAll()
    }

    @Test("Blocked secure contexts never write a personal capture journal")
    func blockedContextDoesNotWrite() {
        let host = makeHost()

        host.recordSnapshot(
            context: makeContext(isSecure: true),
            app: makeApp(),
            fieldIdentity: makeField(),
            fieldClassification: AXFieldClassification(kind: .secure, reason: "secure"),
            snapshot: FocusedTextSnapshot(
                fieldIdentity: makeField(),
                textBeforeCursor: "secret",
                textAfterCursor: ""
            ),
            source: "test"
        )

        #expect(!FileManager.default.fileExists(atPath: host.folderPath))
        host.deleteAll()
    }

    @Test("Missing fingerprint secret omits replay context")
    func missingFingerprintSecretOmitsReplayContext() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("steadytype-personal-capture-missing-secret-\(UUID().uuidString)", isDirectory: true)
        let episodes = PersonalCaptureEpisodeStore(folderURL: root.appendingPathComponent("episodes"))
        let host = PersonalCaptureHost(
            dependencies: PersonalCaptureHostDependencies(
                isEnabled: { true },
                runtimeDiagnosticsMetadata: { [:] },
                fingerprintSecret: { nil },
                compactRect: { _ in "none" }
            ),
            journal: PersonalCaptureJournalWriter(folderURL: root.appendingPathComponent("journal")),
            episodes: episodes
        )
        let visiblePageContext = try #require(VisiblePageContext(text: "visible context"))
        let profile = try #require(CompatibilityProfileStore.mvp.profile(for: "com.apple.TextEdit"))

        host.recordSuggestionEpisodePresented(
            suggestionID: "missing-secret-episode",
            request: CompletionRequest(
                textBeforeCursor: "draft",
                appBundleIdentifier: "com.apple.TextEdit",
                fieldKind: .singlelineCompose,
                visiblePageContext: visiblePageContext,
                suggestionID: "missing-secret-episode"
            ),
            context: makeContext(isSecure: false),
            profile: profile,
            fieldIdentity: makeField(),
            fieldClassification: AXFieldClassification(kind: .singlelineCompose, reason: "test"),
            suggestion: CompletionSuggestion(text: "continuation"),
            latencyMilliseconds: 100,
            triggerReason: "test",
            placement: PlacementHealthPresentation(
                requestedRenderMode: .inlineAdjacent,
                renderMode: .inlineAdjacent,
                anchorRect: CGRect(x: 10, y: 10, width: 1, height: 18),
                anchorSource: .caret,
                textLineRect: nil,
                clippingRect: nil,
                reason: .healthy
            ),
            panelRect: CGRect(x: 10, y: 10, width: 120, height: 24),
            screenshotPath: "",
            metadata: [:]
        )
        episodes.waitForPendingWrites()

        let day = PersonalCaptureEpisodeStore.dayString(from: Date(), calendar: .current)
        let fileURL = URL(fileURLWithPath: episodes.folderPath)
            .appendingPathComponent("\(day).episodes.jsonl")
        let line = try #require(
            String(contentsOf: fileURL, encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: true)
                .first
        )
        let record = try JSONDecoder().decode(
            SuggestionEpisodeRecord.self,
            from: Data(line.utf8)
        )

        #expect(record.replayContext == nil)
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

private func makeApp() -> RunningApplicationInfo {
    RunningApplicationInfo(
        bundleIdentifier: "com.apple.TextEdit",
        localizedName: "TextEdit",
        processIdentifier: 42
    )
}

private func makeField() -> FocusedFieldIdentity {
    FocusedFieldIdentity(
        bundleIdentifier: "com.apple.TextEdit",
        processIdentifier: 42,
        elementIdentifier: 7
    )
}

private func makeContext(isSecure: Bool) -> FocusedTextContext {
    FocusedTextContext(
        elementIdentifier: 7,
        role: "AXTextArea",
        subrole: nil,
        fingerprint: FocusedElementFingerprint(windowTitle: "Test"),
        textBeforeCursor: "test",
        textAfterCursor: "",
        selectedTextLength: 0,
        caretRect: CGRect(x: 10, y: 10, width: 1, height: 18),
        elementRect: CGRect(x: 0, y: 0, width: 500, height: 300),
        windowRect: CGRect(x: 0, y: 0, width: 600, height: 400),
        windowIdentifier: 42,
        textLineRect: CGRect(x: 10, y: 10, width: 140, height: 18),
        textStyle: nil,
        isSecure: isSecure,
        caretIsSynthetic: false,
        capabilities: FocusedTextCapabilities(
            canReadValue: true,
            canReadSelectedTextRange: true,
            canReadBoundsForRange: true,
            canReadAttributedText: false,
            canSetSelectedText: true
        )
    )
}
