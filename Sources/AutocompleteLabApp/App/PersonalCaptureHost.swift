import AutocompleteLabCore
import CoreGraphics
import Foundation

/// Owns the opt-in, local-only writing journal and suggestion episode stores.
/// AppDelegate supplies runtime metadata and privacy-safe geometry formatting;
/// this host owns capture gating, record construction, and lifecycle.
@MainActor
struct PersonalCaptureHostDependencies {
    let isEnabled: () -> Bool
    let runtimeDiagnosticsMetadata: () -> [String: String]
    let fingerprintSecret: () -> Data?
    let compactRect: (CGRect?) -> String
}

@MainActor
final class PersonalCaptureHost {
    private let dependencies: PersonalCaptureHostDependencies
    private let policy = PersonalCapturePolicy()
    private let journal: PersonalCaptureJournalWriter
    private let episodes: PersonalCaptureEpisodeStore
    private var lastSnapshot: FocusedTextSnapshot?

    init(
        dependencies: PersonalCaptureHostDependencies,
        journal: PersonalCaptureJournalWriter = .shared,
        episodes: PersonalCaptureEpisodeStore = .shared
    ) {
        self.dependencies = dependencies
        self.journal = journal
        self.episodes = episodes
    }

    var folderPath: String {
        journal.folderPath
    }

    func resetSnapshot() {
        lastSnapshot = nil
    }

    func deleteAll() {
        resetSnapshot()
        journal.deleteAll()
        episodes.deleteAll()
    }

    func recordSnapshot(
        context: FocusedTextContext,
        app: RunningApplicationInfo,
        fieldIdentity: FocusedFieldIdentity,
        fieldClassification: AXFieldClassification,
        snapshot: FocusedTextSnapshot,
        source: String
    ) {
        guard dependencies.isEnabled() else {
            resetSnapshot()
            return
        }

        let decision = policy.decision(for: PersonalCaptureInput(
            bundleIdentifier: app.bundleIdentifier,
            role: context.role,
            subrole: context.subrole,
            fingerprint: context.fingerprint,
            isSecure: context.isSecure,
            fieldClassification: fieldClassification
        ))

        guard decision.canCapture else {
            resetSnapshot()
            DiagnosticsLog.shared.record(
                "personal-capture-blocked",
                metadata: decision.metadata.merging([
                    "app": app.bundleIdentifier,
                    "source": source,
                    "textBeforeCursorChars": String(context.textBeforeCursor.count),
                    "textAfterCursorChars": String(context.textAfterCursor.count)
                ]) { current, _ in current }
            )
            return
        }

        journal.recordSnapshotChange(
            previous: lastSnapshot,
            current: snapshot,
            context: personalCaptureContext(
                app: app,
                fieldIdentity: fieldIdentity,
                fieldClassification: fieldClassification,
                source: source
            )
        )
        lastSnapshot = snapshot
    }

    func recordSuggestionEpisodePresented(
        suggestionID: String,
        request: CompletionRequest,
        context: FocusedTextContext,
        profile: CompatibilityProfile,
        fieldIdentity: FocusedFieldIdentity,
        fieldClassification: AXFieldClassification,
        suggestion: CompletionSuggestion,
        latencyMilliseconds: Int,
        triggerReason: String,
        placement: PlacementHealthPresentation,
        panelRect: CGRect,
        screenshotPath: String,
        metadata: [String: String]
    ) {
        guard dependencies.isEnabled(), !suggestionID.isEmpty else {
            return
        }

        let appBundleIdentifier = request.appBundleIdentifier ?? profile.bundleIdentifier
        let decision = policy.decision(for: PersonalCaptureInput(
            bundleIdentifier: appBundleIdentifier,
            role: context.role,
            subrole: context.subrole,
            fingerprint: context.fingerprint,
            isSecure: context.isSecure,
            fieldClassification: fieldClassification
        ))
        guard decision.canCapture else {
            DiagnosticsLog.shared.record(
                "personal-capture-episode-blocked",
                metadata: decision.metadata.merging([
                    "app": appBundleIdentifier,
                    "source": "suggestion-presented"
                ]) { current, _ in current }
            )
            return
        }

        let runtimeMetadata = dependencies.runtimeDiagnosticsMetadata()
        let candidateSource = metadata["candidateSelectionSource"] ?? triggerReason
        let replyContext = request.visiblePageContext.flatMap(SuggestionEpisodeReplyContext.init(visiblePageContext:))
        let record = SuggestionEpisodeRecord(
            id: suggestionID,
            createdAt: PersonalCaptureEpisodeStore.timestampString(from: Date()),
            appDisplayName: profile.displayName,
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentity: fieldIdentity.traceDescription,
            fieldKind: fieldClassification.kind.rawValue,
            fieldKindReason: fieldClassification.reason,
            requestMode: request.mode.rawValue,
            userTypedContext: request.textBeforeCursor,
            textAfterCursor: request.textAfterCursor,
            replyContext: replyContext,
            replayContext: request.visiblePageContext.flatMap { visiblePageContext in
                guard let fingerprintSecret = dependencies.fingerprintSecret() else {
                    return nil
                }
                return SuggestionEpisodeReplayContext(
                    visiblePageContext: visiblePageContext,
                    fingerprintSecret: fingerprintSecret,
                    includeText: true
                )
            },
            suggestedText: suggestion.visibleText,
            model: SuggestionEpisodeModelContext(
                modelName: runtimeMetadata["model"] ?? CompletionModelPolicy.mvp.model.rawValue,
                runtime: runtimeMetadata["activeCandidate"] ?? "unknown",
                asset: runtimeMetadata["asset"] ?? "unknown",
                promptVersion: runtimeMetadata["promptStyle"] ?? CompletionPromptBuilder.promptStyleIdentifier,
                experimentArm: runtimeMetadata["experimentArm"] ?? "",
                triggerReason: triggerReason,
                candidateSource: candidateSource,
                latencyMilliseconds: latencyMilliseconds,
                firstTokenLatencyMilliseconds: Int(metadata["firstTokenLatencyMilliseconds"] ?? "")
            ),
            placement: SuggestionEpisodePlacementContext(
                renderMode: placement.renderMode.rawValue,
                anchorRect: dependencies.compactRect(placement.anchorRect),
                textLineRect: placement.textLineRect.map(dependencies.compactRect) ?? "none",
                panelRect: dependencies.compactRect(panelRect),
                confidenceBand: metadata["placementConfidenceBand"] ?? "",
                screenshotCaptured: !screenshotPath.isEmpty
            ),
            metadata: [
                "candidateSource": candidateSource,
                "triggerReason": triggerReason,
                "visibleChars": String(suggestion.visibleText.count),
                "visibleWords": String(suggestion.visibleWordCount)
            ]
            .merging(metadata) { current, _ in current }
        )

        episodes.recordPresented(record)
    }

    func recordEpisodeAction(
        suggestionID: String,
        appBundleIdentifier: String,
        outcome: SuggestionEpisodeOutcome,
        reason: String,
        acceptedText: String = "",
        metadata: [String: String] = [:]
    ) {
        guard dependencies.isEnabled(), !suggestionID.isEmpty else {
            return
        }

        episodes.recordAction(
            suggestionID: suggestionID,
            appBundleIdentifier: appBundleIdentifier,
            outcome: outcome,
            reason: reason,
            acceptedText: acceptedText,
            metadata: metadata
        )
    }

    func recordEpisodeInsertionFailed(
        baseline: InsertionVerificationBaseline,
        outcome: String,
        reason: String
    ) {
        recordEpisodeAction(
            suggestionID: baseline.suggestionID ?? "",
            appBundleIdentifier: baseline.profile.bundleIdentifier,
            outcome: .insertionFailed,
            reason: reason,
            metadata: [
                "acceptanceID": baseline.acceptanceID,
                "acceptMode": baseline.acceptMode,
                "fieldKind": baseline.fieldKind.rawValue,
                "fieldKindReason": baseline.fieldKindReason,
                "behaviorProfile": baseline.behaviorProfileID.rawValue,
                "insertionResult": outcome
            ]
        )
    }

    func recordEpisodeSurvival(
        _ result: AcceptanceSurvivalCheckResult,
        metadata: [String: String]
    ) {
        guard dependencies.isEnabled(), !result.tracker.suggestionID.isEmpty else {
            return
        }

        episodes.recordSurvival(
            suggestionID: result.tracker.suggestionID,
            appBundleIdentifier: result.tracker.appBundleIdentifier,
            acceptedText: result.tracker.acceptedText,
            checkpoint: result.measurement.checkpoint.rawValue,
            survivalClass: result.measurement.survivalClass.rawValue,
            tokenRecall: result.measurement.tokenRecall,
            normalizedEditDistance: result.measurement.normalizedEditDistance,
            metadata: metadata
        )
    }

    func episodeOutcome(hiddenOutcome outcome: String, reason: String) -> SuggestionEpisodeOutcome {
        if reason == "escape" {
            return .dismissed
        }
        if outcome == "accepted" {
            return .unknown
        }
        if outcome == "typed-over" || reason == "typed-over" || outcome == "typed-through" {
            return .typedPast
        }
        if reason.contains("failed") || reason.contains("unsafe") {
            return .insertionFailed
        }
        if outcome == "ignored" {
            return .ignored
        }
        return .unknown
    }

    func recordAcceptedSuggestion(
        acceptedText: String,
        baseline: InsertionVerificationBaseline
    ) {
        guard dependencies.isEnabled(),
              !acceptedText.isEmpty,
              !baseline.fieldKind.suppressesSuggestionsByDefault else {
            return
        }

        journal.recordAcceptedSuggestion(
            acceptedText: acceptedText,
            context: PersonalCaptureJournalContext(
                appDisplayName: baseline.profile.displayName,
                appBundleIdentifier: baseline.profile.bundleIdentifier,
                fieldIdentity: baseline.fieldIdentity.traceDescription,
                fieldKind: baseline.fieldKind,
                fieldKindReason: baseline.fieldKindReason,
                source: "insertion-verified"
            ),
            suggestionID: baseline.suggestionID ?? "",
            acceptanceID: baseline.acceptanceID,
            acceptMode: baseline.acceptMode
        )
    }

    func recordAcceptanceSurvival(_ result: AcceptanceSurvivalCheckResult) {
        guard dependencies.isEnabled(),
              result.shouldRecordAcceptedAndKept || result.shouldRecordAcceptedThenDeleted,
              !result.tracker.acceptedText.isEmpty,
              !result.tracker.fieldKind.suppressesSuggestionsByDefault else {
            return
        }

        journal.recordAcceptanceSurvival(
            acceptedText: result.tracker.acceptedText,
            context: PersonalCaptureJournalContext(
                appDisplayName: result.tracker.profile.displayName,
                appBundleIdentifier: result.tracker.appBundleIdentifier,
                fieldIdentity: result.tracker.fieldIdentity.traceDescription,
                fieldKind: result.tracker.fieldKind,
                fieldKindReason: result.tracker.fieldKindReason,
                source: "acceptance-survival"
            ),
            suggestionID: result.tracker.suggestionID,
            acceptanceID: result.tracker.acceptanceID,
            acceptMode: result.tracker.acceptMode,
            checkpoint: result.measurement.checkpoint.rawValue,
            survivalClass: result.measurement.survivalClass.rawValue,
            isStrongPositive: result.measurement.isStrongAcceptedAndKept
                || result.measurement.isFinalAcceptedAndKept
        )
    }

    private func personalCaptureContext(
        app: RunningApplicationInfo,
        fieldIdentity: FocusedFieldIdentity,
        fieldClassification: AXFieldClassification,
        source: String
    ) -> PersonalCaptureJournalContext {
        PersonalCaptureJournalContext(
            appDisplayName: app.localizedName,
            appBundleIdentifier: app.bundleIdentifier,
            fieldIdentity: fieldIdentity.traceDescription,
            fieldKind: fieldClassification.kind,
            fieldKindReason: fieldClassification.reason,
            source: source
        )
    }
}
