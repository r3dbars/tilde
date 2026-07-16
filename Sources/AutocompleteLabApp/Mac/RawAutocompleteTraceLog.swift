import Foundation
import AutocompleteLabCore

final class RawAutocompleteTraceLog: @unchecked Sendable {
    static let shared = RawAutocompleteTraceLog(
        logURL: FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/SteadyType/traces.jsonl"),
        screenshotsURL: FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/SteadyType/screenshots")
    )

    private let queue = DispatchQueue(label: "app.transcripted.autocomplete.raw-trace-log")
    private let logURL: URL
    private let screenshotsURL: URL
    private let userDefaults: UserDefaults
    private let environment: [String: String]
    private let debugCaptureDuration: TimeInterval
    private let now: () -> Date
    private let sessionID = UUID().uuidString
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let pauseDefaultsKey = "AutocompleteLabTracePaused"
    private let screenshotDefaultsKey = "AutocompleteLabScreenshotTraceEnabled"
    private let screenshotExpiryDefaultsKey = "AutocompleteLabScreenshotTraceExpiresAt"
    private let rawContentDefaultsKey = "AutocompleteLabRawTraceContentEnabled"
    private let rawContentExpiryDefaultsKey = "AutocompleteLabRawTraceContentExpiresAt"

    init(
        logURL: URL,
        screenshotsURL: URL,
        userDefaults: UserDefaults = .standard,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        debugCaptureDuration: TimeInterval = 60 * 60,
        now: @escaping () -> Date = Date.init
    ) {
        self.logURL = logURL
        self.screenshotsURL = screenshotsURL
        self.userDefaults = userDefaults
        self.environment = environment
        self.debugCaptureDuration = debugCaptureDuration
        self.now = now
    }

    var currentSessionID: String {
        sessionID
    }

    var folderURL: URL {
        logURL.deletingLastPathComponent()
    }

    var screenshotFolderURL: URL {
        screenshotsURL
    }

    var path: String {
        logURL.path
    }

    var isEnabled: Bool {
        if isPaused {
            return false
        }

        let value = ProcessInfo.processInfo.environment["AUTOCOMPLETE_LAB_TRACE"] ?? ""
        if ["0", "false", "no", "off"].contains(value.lowercased()) {
            return false
        }

        return true
    }

    var rawContentTracingEnabled: Bool {
        if let override = environmentFlag("AUTOCOMPLETE_LAB_RAW_TRACE") {
            return override
        }

        return activeDefaultFlag(
            flagKey: rawContentDefaultsKey,
            expiryKey: rawContentExpiryDefaultsKey
        )
    }

    func setRawContentTracingEnabled(_ enabled: Bool) {
        setExpiringDefaultFlag(
            enabled,
            flagKey: rawContentDefaultsKey,
            expiryKey: rawContentExpiryDefaultsKey
        )
    }

    var rawContentTracingExpiresAt: Date? {
        activeDefaultExpirationDate(
            flagKey: rawContentDefaultsKey,
            expiryKey: rawContentExpiryDefaultsKey
        )
    }

    var isPaused: Bool {
        userDefaults.bool(forKey: pauseDefaultsKey)
    }

    func setPaused(_ paused: Bool) {
        userDefaults.set(paused, forKey: pauseDefaultsKey)
    }

    func deleteAll() {
        setRawContentTracingEnabled(false)
        setScreenshotTracingEnabled(false)
        queue.sync { [logURL, screenshotsURL] in
            let folderURL = logURL.deletingLastPathComponent()
            try? FileManager.default.removeItem(at: logURL)
            try? FileManager.default.removeItem(at: folderURL.appendingPathComponent("raw-traces.jsonl"))
            try? FileManager.default.removeItem(at: folderURL.appendingPathComponent("trace-report.html"))
            try? FileManager.default.removeItem(at: folderURL.appendingPathComponent("survival-report.json"))
            try? FileManager.default.removeItem(at: folderURL.appendingPathComponent("survival-inspector-debug.json"))
            try? FileManager.default.removeItem(at: folderURL.appendingPathComponent("privacy-export"))
            try? FileManager.default.removeItem(at: screenshotsURL)
        }
    }

    var screenshotTracingEnabled: Bool {
        if activeDefaultFlag(
            flagKey: screenshotDefaultsKey,
            expiryKey: screenshotExpiryDefaultsKey
        ) {
            return true
        }

        return environmentFlag("AUTOCOMPLETE_LAB_SCREENSHOT_TRACE") == true
    }

    func setScreenshotTracingEnabled(_ enabled: Bool) {
        setExpiringDefaultFlag(
            enabled,
            flagKey: screenshotDefaultsKey,
            expiryKey: screenshotExpiryDefaultsKey
        )
    }

    var screenshotTracingExpiresAt: Date? {
        activeDefaultExpirationDate(
            flagKey: screenshotDefaultsKey,
            expiryKey: screenshotExpiryDefaultsKey
        )
    }

    private func environmentFlag(_ key: String) -> Bool? {
        guard let value = environment[key]?.lowercased() else {
            return nil
        }

        if ["1", "true", "yes", "on"].contains(value) {
            return true
        }

        if ["0", "false", "no", "off"].contains(value) {
            return false
        }

        return nil
    }

    private func activeDefaultFlag(flagKey: String, expiryKey: String) -> Bool {
        activeDefaultExpirationDate(flagKey: flagKey, expiryKey: expiryKey) != nil
    }

    private func activeDefaultExpirationDate(flagKey: String, expiryKey: String) -> Date? {
        guard userDefaults.bool(forKey: flagKey) else {
            return nil
        }

        guard let expiresAt = expirationDate(forKey: expiryKey),
              expiresAt > now() else {
            clearExpiringDefaultFlag(flagKey: flagKey, expiryKey: expiryKey)
            expireArtifacts(for: flagKey)
            return nil
        }

        return expiresAt
    }

    private func setExpiringDefaultFlag(_ enabled: Bool, flagKey: String, expiryKey: String) {
        guard enabled else {
            clearExpiringDefaultFlag(flagKey: flagKey, expiryKey: expiryKey)
            return
        }

        userDefaults.set(true, forKey: flagKey)
        userDefaults.set(
            now().addingTimeInterval(debugCaptureDuration).timeIntervalSince1970,
            forKey: expiryKey
        )
    }

    private func clearExpiringDefaultFlag(flagKey: String, expiryKey: String) {
        userDefaults.set(false, forKey: flagKey)
        userDefaults.removeObject(forKey: expiryKey)
    }

    private func expireArtifacts(for flagKey: String) {
        if flagKey == rawContentDefaultsKey {
            redactStoredTraceFile()
            removeSurvivalInspectorDebugFile()
        }
        if flagKey == screenshotDefaultsKey {
            queue.sync { [screenshotsURL] in
                try? FileManager.default.removeItem(at: screenshotsURL)
            }
        }
    }

    private func removeSurvivalInspectorDebugFile() {
        queue.sync { [logURL] in
            let folderURL = logURL.deletingLastPathComponent()
            try? FileManager.default.removeItem(
                at: folderURL.appendingPathComponent("survival-inspector-debug.json")
            )
        }
    }

    private func redactStoredTraceFile() {
        queue.sync { [logURL, decoder, encoder] in
            guard let contents = try? String(contentsOf: logURL, encoding: .utf8) else {
                return
            }

            let redactedLines = contents
                .split(separator: "\n", omittingEmptySubsequences: true)
                .compactMap { line -> String? in
                    guard let event = try? decoder.decode(
                        AutocompleteTraceEvent.self,
                        from: Data(line.utf8)
                    ) else {
                        return nil
                    }
                    guard let data = try? encoder.encode(RedactionLayer.redactedDefaultTrace(event)) else {
                        return nil
                    }
                    return String(data: data, encoding: .utf8)
                }

            guard !redactedLines.isEmpty else {
                try? FileManager.default.removeItem(at: logURL)
                return
            }

            try? (redactedLines.joined(separator: "\n") + "\n").write(
                to: logURL,
                atomically: true,
                encoding: .utf8
            )
            // Atomic write replaces the file with a fresh inode at the process umask, so
            // re-tighten to owner-only after rewriting.
            SecureLocalStorage.restrictFile(at: logURL)
        }
    }

    private func expirationDate(forKey key: String) -> Date? {
        let value = userDefaults.double(forKey: key)
        guard value > 0 else {
            return nil
        }

        return Date(timeIntervalSince1970: value)
    }

    func recordModelResult(
        request: CompletionRequest,
        prompt: CompletionPrompt,
        rawOutput: String,
        cleanedSuggestion: CompletionSuggestion?,
        cleanedCandidateCount: Int = 0,
        candidateTopScore: Double? = nil,
        candidateScoreMargin: Double? = nil,
        candidateSuppressionReason: String? = nil,
        suggestionID: String = "",
        latencyMilliseconds: Int? = nil,
        firstTokenLatencyMilliseconds: Int? = nil,
        extraMetadata: [String: String] = [:]
    ) {
        guard isEnabled else {
            return
        }

        var metadata = [
            "cleanedWordCount": String(cleanedSuggestion?.visibleWordCount ?? 0),
            "cleanedCandidateCount": String(cleanedCandidateCount),
            "candidateTopScore": Self.formattedCandidateScore(candidateTopScore),
            "candidateScoreMargin": Self.formattedCandidateScore(candidateScoreMargin),
            "candidateSuppressionReason": candidateSuppressionReason ?? "none",
            "emptyResult": String(cleanedSuggestion == nil)
        ]
        metadata.merge(request.behaviorProfileTraceMetadata) { current, _ in current }
        if let latencyMilliseconds {
            metadata["totalGenerationLatencyMilliseconds"] = String(latencyMilliseconds)
        }
        if let firstTokenLatencyMilliseconds {
            metadata["firstTokenLatencyMilliseconds"] = String(firstTokenLatencyMilliseconds)
        }
        metadata.merge(extraMetadata) { current, _ in current }

        record(
            type: .modelResult,
            suggestionID: suggestionID,
            appBundleIdentifier: request.appBundleIdentifier ?? "",
            requestMode: request.mode.rawValue,
            textBeforeCursor: request.textBeforeCursor,
            textAfterCursor: request.textAfterCursor,
            systemPrompt: prompt.system,
            userPrompt: prompt.user,
            rawOutput: rawOutput,
            cleanedVisibleText: cleanedSuggestion?.visibleText ?? "",
            displayedText: cleanedSuggestion?.visibleText ?? "",
            latencyMilliseconds: latencyMilliseconds,
            metadata: metadata
        )
    }

    func recordAcceptance(
        action: String,
        appBundleIdentifier: String,
        acceptedText: String,
        remainingVisibleText: String?,
        suggestionID: String = "",
        fieldIdentity: String = "",
        requestMode: String = "",
        metadata: [String: String] = [:]
    ) {
        guard isEnabled else {
            return
        }

        record(
            type: .suggestionAccepted,
            suggestionID: suggestionID,
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentity: fieldIdentity,
            requestMode: requestMode,
            acceptedText: acceptedText,
            remainingVisibleText: remainingVisibleText ?? "",
            outcome: action,
            metadata: metadata
        )
    }

    func record(
        type: AutocompleteTraceEventType,
        suggestionID: String,
        appBundleIdentifier: String = "",
        fieldIdentity: String = "",
        requestMode: String = "",
        triggerReason: String = "",
        textBeforeCursor: String = "",
        textAfterCursor: String = "",
        systemPrompt: String = "",
        userPrompt: String = "",
        rawOutput: String = "",
        cleanedVisibleText: String = "",
        displayedText: String = "",
        acceptedText: String = "",
        remainingVisibleText: String = "",
        latencyMilliseconds: Int? = nil,
        outcome: String = "",
        reason: String = "",
        screenshotPath: String = "",
        metadata: [String: String] = [:]
    ) {
        guard isEnabled else {
            return
        }

        let rawContentEnabled = rawContentTracingEnabled
        var traceMetadata = metadata
        if type == .suggestionSuppressed {
            traceMetadata.merge(
                SuggestionSilenceExplanationPolicy().traceMetadata(
                    forTraceReason: reason,
                    metadata: metadata,
                    triggerReason: triggerReason
                )
            ) { _, code in code }
        }
        let proofMetadata = traceMetadata.merging(AutocompleteTraceProofMetadata.current) { _, current in
            current
        }
        let event = AutocompleteTraceEvent(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            sessionID: sessionID,
            suggestionID: suggestionID,
            type: type,
            appBundleIdentifier: appBundleIdentifier,
            fieldIdentity: fieldIdentity,
            requestMode: requestMode,
            triggerReason: triggerReason,
            textBeforeCursor: AutocompleteTracePrivacyFilter.textValue(
                textBeforeCursor,
                rawContentEnabled: rawContentEnabled
            ),
            textAfterCursor: AutocompleteTracePrivacyFilter.textValue(
                textAfterCursor,
                rawContentEnabled: rawContentEnabled
            ),
            systemPrompt: AutocompleteTracePrivacyFilter.textValue(
                systemPrompt,
                rawContentEnabled: rawContentEnabled
            ),
            userPrompt: AutocompleteTracePrivacyFilter.textValue(
                userPrompt,
                rawContentEnabled: rawContentEnabled
            ),
            rawOutput: AutocompleteTracePrivacyFilter.textValue(
                rawOutput,
                rawContentEnabled: rawContentEnabled
            ),
            cleanedVisibleText: AutocompleteTracePrivacyFilter.textValue(
                cleanedVisibleText,
                rawContentEnabled: rawContentEnabled
            ),
            displayedText: AutocompleteTracePrivacyFilter.textValue(
                displayedText,
                rawContentEnabled: rawContentEnabled
            ),
            acceptedText: AutocompleteTracePrivacyFilter.textValue(
                acceptedText,
                rawContentEnabled: rawContentEnabled
            ),
            remainingVisibleText: AutocompleteTracePrivacyFilter.textValue(
                remainingVisibleText,
                rawContentEnabled: rawContentEnabled
            ),
            latencyMilliseconds: latencyMilliseconds,
            outcome: outcome,
            reason: reason,
            screenshotPath: screenshotPath,
            metadata: AutocompleteTracePrivacyFilter.metadata(
                proofMetadata,
                rawContentEnabled: rawContentEnabled
            )
        )

        queue.async { [logURL, encoder] in
            do {
                // Owner-only (0700 dir / 0600 file): traces can hold raw text when raw-content
                // dogfood tracing is opted in, so the file must not rely on the parent
                // directory's mode to stay private. See docs/security/threat-model.md (F2).
                SecureLocalStorage.createDirectory(at: logURL.deletingLastPathComponent())

                let data = try encoder.encode(event)
                guard var line = String(data: data, encoding: .utf8) else {
                    return
                }

                line.append("\n")

                SecureLocalStorage.ensureFile(at: logURL)

                let handle = try FileHandle(forWritingTo: logURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
                try handle.close()
            } catch {
                // Raw tracing is diagnostic only and must never affect typing.
            }
        }
    }

    func recentEvents(limit: Int) -> [AutocompleteTraceEvent] {
        queue.sync { [logURL, decoder] in
            guard limit > 0,
                  let contents = try? String(contentsOf: logURL, encoding: .utf8) else {
                return []
            }

            return contents
                .split(separator: "\n", omittingEmptySubsequences: true)
                .suffix(limit)
                .compactMap { line in
                    try? decoder.decode(AutocompleteTraceEvent.self, from: Data(line.utf8))
                }
        }
    }

    func summary(limit: Int = 2_000) -> AutocompleteTraceSummary {
        AutocompleteTraceAnalyzer().summary(for: recentEvents(limit: limit))
    }

    func exportPrivacyBundle(limit: Int = 2_000) -> URL? {
        queue.sync { [folderURL] in
            LocalReportExporter(folderURL: folderURL).exportPrivacyBundle(limit: limit)
        }
    }

    private static func formattedCandidateScore(_ score: Double?) -> String {
        guard let score else {
            return "none"
        }

        return String(format: "%.3f", score)
    }
}
