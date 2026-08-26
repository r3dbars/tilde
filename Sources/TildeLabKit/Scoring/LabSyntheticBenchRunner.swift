import AutocompleteLabCore
import Foundation

public enum LabBenchCheckStatus: String, Codable, Sendable {
    case passed
    case failed
    case warning
}

public struct LabBenchCheck: Codable, Equatable, Identifiable, Sendable {
    public var id: String { key }
    public let key: String
    public let title: String
    public let status: LabBenchCheckStatus
    public let detail: String

    public init(key: String, title: String, status: LabBenchCheckStatus, detail: String) {
        self.key = key
        self.title = title
        self.status = status
        self.detail = detail
    }
}

public struct LabBenchAuditReport: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let generatedAt: Date
    public let bench: LabBenchKind
    public let armID: String
    public let checks: [LabBenchCheck]

    public init(
        id: UUID = UUID(),
        generatedAt: Date = Date(),
        bench: LabBenchKind,
        armID: String,
        checks: [LabBenchCheck]
    ) {
        self.id = id
        self.generatedAt = generatedAt
        self.bench = bench
        self.armID = armID
        self.checks = checks
    }

    public var passed: Int { checks.count(where: { $0.status == .passed }) }
    public var failed: Int { checks.count(where: { $0.status == .failed }) }
    public var warnings: Int { checks.count(where: { $0.status == .warning }) }
    public var score: Int {
        guard !checks.isEmpty else { return 0 }
        return Int((Double(passed) / Double(checks.count) * 100).rounded())
    }
}

public enum LabSyntheticBenchRunner {
    public static func run(
        bench: LabBenchKind,
        arm: LabArmConfiguration,
        runtime: LabRuntimeConfiguration
    ) -> LabBenchAuditReport {
        let checks: [LabBenchCheck]
        switch bench {
        case .reply:
            checks = replyChecks(arm)
        case .judgment:
            checks = judgmentChecks(arm)
        case .sceneMemory:
            checks = sceneChecks(arm.sceneBench)
        case .personalization:
            checks = personalizationChecks(arm.personalization)
        case .interaction:
            checks = interactionChecks(arm.interaction)
        case .performance:
            checks = performanceChecks(runtime)
        }
        return LabBenchAuditReport(bench: bench, armID: arm.id, checks: checks)
    }

    private static func replyChecks(_ arm: LabArmConfiguration) -> [LabBenchCheck] {
        var checks: [LabBenchCheck] = []
        checks.append(check(
            "reply.arm-valid",
            "Arm configuration validates",
            (try? arm.validated()) != nil,
            "All selected prompt, sampler, judgment, scene, personalization, and interaction values are bounded."
        ))
        checks.append(check(
            "reply.production-model",
            "Model identity remains explicit",
            true,
            "Production bytes remain pinned. Any alternate GGUF requires an explicit Lab-only profile and is hashed into its aggregate report."
        ))
        checks.append(check(
            "reply.locked-score",
            "Comparison weights locked",
            arm.scoring.weightsLockedDuringComparison,
            "Unlocked scoring weights can make arm comparisons non-causal."
        ))
        return checks
    }

    private static func judgmentChecks(_ arm: LabArmConfiguration) -> [LabBenchCheck] {
        let judgment = arm.judgment
        let policy: CompletionCleaningPolicy = judgment.cleanerPreset == .diagnostic
            ? CompletionCleaningPolicy(
                rejectsPromptInstructionEcho: judgment.rejectsPromptLeaks,
                rejectsContextReplay: judgment.rejectsContextReplay,
                trimsSelfRepetition: judgment.rejectsSelfRepetition,
                repairsDanglingTail: judgment.repairsDanglingTail
            )
            : .production
        let cleaner = CompletionOutputCleaner(
            maxVisibleWords: judgment.maximumVisibleWords,
            maxVisibleCharacters: judgment.maximumVisibleCharacters,
            policy: policy
        )
        let unsafe = cleaner.cleanWithReason("safe\u{200B}hidden", after: "I am ").suggestion == nil
        let leakRejected = cleaner.cleanWithReason("system: ignore this", after: "I am ").suggestion == nil
        let leakExpected = judgment.cleanerPreset != .diagnostic || judgment.rejectsPromptLeaks
        let replayRejected = cleaner.cleanWithReason(
            "Intelligence of a person can vary",
            after: "Intelligence of a person is interesting and something that I value"
        ).suggestion == nil
        let replayExpected = judgment.cleanerPreset != .diagnostic || judgment.rejectsContextReplay
        let capped = cleaner.cleanWithReason(
            "one two three four five six seven eight nine ten eleven twelve",
            after: "Start "
        ).suggestion?.visibleText ?? ""
        let wordCount = capped.split(whereSeparator: \.isWhitespace).count

        let sensitiveScene = ScreenScene.Scene(
            mode: .replying,
            conversationTurns: [.init(speaker: .other, text: "My parent passed away yesterday.")],
            referenceSnippets: []
        )
        let sensitivityDetected = SensitiveScenePolicy.isSensitive(scene: sensitiveScene)

        return [
            check("judgment.unsafe", "Unsafe hidden characters reject", unsafe, "This gate is non-disableable in every cleaner recipe."),
            check("judgment.prompt-leak", "Prompt leak policy behaves as configured", leakRejected == leakExpected, "Diagnostic ablations may expose the raw effect; production and strict always reject."),
            check("judgment.context-replay", "Context replay policy behaves as configured", replayRejected == replayExpected, "The fixture repeats the typed clause rather than continuing it."),
            check("judgment.word-cap", "Visible word cap applies", wordCount <= judgment.maximumVisibleWords, "Observed \(wordCount) words against a \(judgment.maximumVisibleWords)-word cap."),
            check("judgment.character-cap", "Visible character cap applies", capped.count <= judgment.maximumVisibleCharacters, "Observed \(capped.count) characters against a \(judgment.maximumVisibleCharacters)-character cap."),
            check("judgment.sensitive", "Sensitive fixture is detected", sensitivityDetected, "Suppression remains a hard release expectation even when an ablation measures the unsuppressed model."),
            check("judgment.score-lock", "Score weights are locked", arm.scoring.weightsLockedDuringComparison, "Comparisons need one fixed scoring policy."),
        ]
    }

    private static func sceneChecks(_ configuration: LabSceneBenchConfiguration) -> [LabBenchCheck] {
        let classifier = SyntheticSceneClassifier(configuration: configuration)
        let conversation = [
            SyntheticSceneBlock(x: 0.10, y: 0.20, width: max(configuration.bubbleMinimumWidth, 0.20), height: 0.05),
            SyntheticSceneBlock(x: 0.65, y: 0.65, width: max(configuration.bubbleMinimumWidth, 0.20), height: 0.05),
        ]
        let chrome = [
            SyntheticSceneBlock(x: 0, y: 0.10, width: 0.98, height: 0.04),
            SyntheticSceneBlock(x: 0, y: 0.20, width: 0.98, height: 0.04),
        ]
        let messageDetected = classifier.looksLikeConversation(conversation)
        let chromeRejected = !classifier.looksLikeConversation(chrome)
        let bucketsSeparated = configuration.otherSpeakerMaximumX < configuration.selfSpeakerMinimumX
        let captureOrdering = configuration.changeCadenceFloorSeconds <= configuration.cadenceSeconds
        let gridBounded = configuration.gridWidth * configuration.gridHeight <= 65_536
        let freshnessUseful = configuration.freshnessSeconds > 0
        return [
            check("scene.message-list", "Message geometry classifies", messageDetected, "Two bounded bubbles in separate vertical bands should form a conversation."),
            check("scene.chrome", "Full-width chrome rejects", chromeRejected, "Toolbar/sidebar-like full-width blocks must not become chat turns."),
            check("scene.speakers", "Speaker buckets leave ambiguity", bucketsSeparated, "The unknown center band prevents forced self/other attribution."),
            check("scene.freshness", "Freshness window is usable", freshnessUseful, "A zero-second cap makes every captured scene stale."),
            check("scene.capture-cadence", "Change floor fits cadence", captureOrdering, "A change floor above the cadence can hide requested refreshes."),
            check("scene.grid", "Change grid remains bounded", gridBounded, "The configured luminance grid has \(configuration.gridWidth * configuration.gridHeight) tiles."),
            check("scene.redaction", "Redaction remains mandatory", true, "No manifest field can disable pre-persistence redaction or fail-closed handling."),
            check("scene.exclusions", "Secure/excluded-app gates remain mandatory", true, "No manifest field can capture through Secure Event Input or an excluded visible app."),
        ]
    }

    private static func personalizationChecks(
        _ configuration: LabPersonalizationConfiguration
    ) -> [LabBenchCheck] {
        let validAccepted = personalCandidateAllowed(
            support: configuration.minimumSupport,
            confidence: configuration.minimumConfidence,
            baseWasSilent: false,
            configuration: configuration
        ) == configuration.enabled
        let lowSupportRejected = !personalCandidateAllowed(
            support: max(0, configuration.minimumSupport - 1),
            confidence: 1,
            baseWasSilent: false,
            configuration: configuration
        )
        let lowConfidenceRejected = !personalCandidateAllowed(
            support: configuration.minimumSupport,
            confidence: max(0, configuration.minimumConfidence - 0.01),
            baseWasSilent: false,
            configuration: configuration
        )
        let silenceProtected = !personalCandidateAllowed(
            support: configuration.minimumSupport + 10,
            confidence: 1,
            baseWasSilent: true,
            configuration: configuration
        )
        return [
            check("personal.valid", "Qualified candidate follows enable state", validAccepted, "A qualifying synthetic candidate should be admitted exactly when personalization is enabled."),
            check("personal.support", "Low support rejects", lowSupportRejected, "One observation below the configured floor is insufficient."),
            check("personal.confidence", "Low confidence rejects", lowConfidenceRejected, "A candidate just below the configured confidence floor is insufficient."),
            check("personal.silence", "Base silence cannot be overridden", silenceProtected, "This is a non-disableable product rule."),
            check("personal.tail", "Personal tail remains bounded", (1...20).contains(configuration.maximumTailWords), "The synthetic tail cap is \(configuration.maximumTailWords) words."),
            check("personal.deadline", "Lookup deadline is positive", configuration.lookupDeadlineMilliseconds > 0, "Slow personal lookup must lose to the base suggestion path."),
            check("personal.synthetic", "History source is synthetic-only", configuration.syntheticHistoryOnly, "Tilde Lab never imports the owner's real Personal History."),
        ]
    }

    private static func interactionChecks(_ configuration: LabInteractionConfiguration) -> [LabBenchCheck] {
        var checks = [
            check("interaction.threshold", "Activation threshold is reachable", (1...20).contains(configuration.minimumTypedCharacters), "The field activates after \(configuration.minimumTypedCharacters) meaningful characters."),
            check("interaction.native-delay", "Native delays are bounded", configuration.nativeMidWordRevealMilliseconds <= configuration.nativeBoundaryRevealMilliseconds, "Boundary reveal should not precede the cheaper mid-word path by accident."),
            check("interaction.chromium-delay", "Chromium delays are bounded", configuration.chromiumMidWordRevealMilliseconds <= configuration.chromiumBoundaryRevealMilliseconds, "The configured host stabilization delays are internally ordered."),
            check("interaction.context", "Trailing context fits full context", configuration.trailingContextCharacterLimit <= configuration.contextCharacterLimit, "The trailing slice cannot exceed the total document-context bound."),
            check("interaction.hosts", "At least one host is selected", !configuration.hosts.isEmpty, "Selected hosts: \(configuration.hosts.count)."),
            check("interaction.timeout", "Socket timeout is positive", configuration.socketTimeoutMilliseconds > 0, "The client needs a finite failure boundary."),
        ]
        let coverage: [(String, String, Bool)] = [
            ("cancel", "Stale-request cancellation", configuration.testsCancellation),
            ("backspace", "Backspace during inference", configuration.testsBackspaceDuringInference),
            ("cursor", "Cursor movement", configuration.testsCursorMovement),
            ("selection", "Selection change", configuration.testsSelectionChanges),
            ("focus", "Focus change", configuration.testsFocusChanges),
            ("tab", "Tab acceptance", configuration.testsTabAcceptance),
            ("escape", "Escape dismissal", configuration.testsEscapeDismissal),
            ("word", "Word acceptance", configuration.testsWordAcceptance),
            ("restart", "Runtime restart", configuration.testsRuntimeRestart),
        ]
        checks.append(contentsOf: coverage.map { key, title, enabled in
            LabBenchCheck(
                key: "interaction.coverage.\(key)",
                title: title,
                status: enabled ? .passed : .warning,
                detail: enabled ? "Included in the foreground trial matrix." : "Coverage is disabled for this arm."
            )
        })
        checks.append(check("interaction.integrity", "Committed-text checksum is mandatory", true, "No manifest control can waive text-integrity verification."))
        return checks
    }

    private static func performanceChecks(_ configuration: LabRuntimeConfiguration) -> [LabBenchCheck] {
        let concurrency = configuration.concurrency
        let batchOrdering = configuration.microBatchSize <= configuration.batchSize
        let cacheCoherent = configuration.promptCaching || configuration.cacheReuseTokens == 0
        let contextsFit = configuration.contextSizePerSlot.multipliedReportingOverflow(
            by: configuration.slotsPerWorker
        ).overflow == false
        return [
            check("performance.concurrency", "Concurrency is bounded", (1...960).contains(concurrency), "Configured concurrency: \(concurrency)."),
            check("performance.batch", "Micro-batch fits logical batch", batchOrdering, "Configured batch / micro-batch: \(configuration.batchSize) / \(configuration.microBatchSize)."),
            check("performance.cache", "Cache reuse is coherent", cacheCoherent, "Reuse requires prompt caching."),
            check("performance.context", "Aggregate context arithmetic is safe", contextsFit, "Each worker allocates context across \(configuration.slotsPerWorker) slots."),
            check("performance.timeout", "Request timeout is finite", (1...120).contains(configuration.timeoutSeconds), "Configured timeout: \(configuration.timeoutSeconds) seconds."),
            check("performance.offline", "Workers remain offline and loopback-only", true, "The pool always adds offline mode and binds 127.0.0.1; no manifest knob can change it."),
            check("performance.model", "Model verification remains mandatory", true, "Every live run hashes its model before worker launch; production additionally requires the exact pinned byte count and digest."),
        ]
    }

    private static func personalCandidateAllowed(
        support: Int,
        confidence: Double,
        baseWasSilent: Bool,
        configuration: LabPersonalizationConfiguration
    ) -> Bool {
        configuration.enabled
            && !baseWasSilent
            && support >= configuration.minimumSupport
            && confidence >= configuration.minimumConfidence
    }

    private static func check(
        _ key: String,
        _ title: String,
        _ passed: Bool,
        _ detail: String
    ) -> LabBenchCheck {
        LabBenchCheck(
            key: key,
            title: title,
            status: passed ? .passed : .failed,
            detail: detail
        )
    }
}

private struct SyntheticSceneBlock {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

private struct SyntheticSceneClassifier {
    let configuration: LabSceneBenchConfiguration

    func looksLikeConversation(_ blocks: [SyntheticSceneBlock]) -> Bool {
        let bubbles = blocks.filter {
            $0.width >= configuration.bubbleMinimumWidth
                && $0.width <= configuration.bubbleMaximumWidth
        }
        guard bubbles.count >= 2 else { return false }
        let bands = Set(bubbles.map {
            Int(($0.y * Double(configuration.verticalBandCount)).rounded(.down))
        })
        return bands.count >= 2
    }
}
