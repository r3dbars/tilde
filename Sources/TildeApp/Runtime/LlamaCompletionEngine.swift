import TildeCore
import Foundation

/// One deterministic streaming completion request to the app-owned llama
/// server. Partials are surfaced only at complete-word boundaries; callers
/// never see a dangling token. The final cleaner still owns every safety,
/// repetition, and prefix decision.
final class LlamaCompletionEngine: @unchecked Sendable {
    /// A llama.cpp `stream:true` line can omit `content` on its terminal
    /// timing frame, so it has a looser shape than a final response.
    struct StreamFrame: Decodable {
        let content: String?
        let stop: Bool?
        let stoppedEOS: Bool?
        let stoppedLimit: Bool?
        let stoppedWord: Bool?
        let tokensPredicted: Int?

        enum CodingKeys: String, CodingKey {
            case content, stop
            case stoppedEOS = "stopped_eos"
            case stoppedLimit = "stopped_limit"
            case stoppedWord = "stopped_word"
            case tokensPredicted = "tokens_predicted"
        }

        var hasRecognizedField: Bool {
            content != nil || stop != nil || stoppedEOS != nil || stoppedLimit != nil
                || stoppedWord != nil || tokensPredicted != nil
        }
    }

    private let baseURL: URL
    private let cleaner: CompletionOutputCleaner
    private let diagnostics: DiagnosticsLog
    private let productProfile: TildeProductProfile
    private let transport: any LlamaCompletionStreamingTransport

    init(
        baseURL: URL,
        diagnostics: DiagnosticsLog = .shared,
        transport: any LlamaCompletionStreamingTransport = URLSessionLlamaCompletionTransport(),
        productProfile: TildeProductProfile = .current
    ) {
        self.baseURL = baseURL
        self.diagnostics = diagnostics
        self.transport = transport
        self.productProfile = productProfile
        cleaner = CompletionOutputCleaner(maxVisibleWords: productProfile.maximumVisibleWords)
    }

    func suggestion(
        textBeforeCursor: String,
        appBundleIdentifier: String?
    ) async throws -> CompletionSuggestion? {
        try await suggestion(
            textBeforeCursor: textBeforeCursor,
            appBundleIdentifier: appBundleIdentifier,
            scene: nil
        )
    }

    func suggestion(
        textBeforeCursor: String,
        appBundleIdentifier: String?,
        scene: ScreenScene.Scene?
    ) async throws -> CompletionSuggestion? {
        try await suggestion(
            textBeforeCursor: textBeforeCursor,
            appBundleIdentifier: appBundleIdentifier,
            scene: scene,
            onPartialSuggestion: { _ in }
        )
    }

    /// `onPartialSuggestion` runs off the main actor, inside the stream loop,
    /// each time a longer complete-word prefix passes the cleaner. Callers
    /// hop to their own actor and re-check their ticket.
    func suggestion(
        textBeforeCursor: String,
        appBundleIdentifier: String?,
        scene: ScreenScene.Scene?,
        onPartialSuggestion: @escaping @Sendable (CompletionSuggestion) -> Void
    ) async throws -> CompletionSuggestion? {
        let startedAt = ProcessInfo.processInfo.systemUptime
        let register = ContinuationRegister.following(scene: scene, hostBundleIdentifier: appBundleIdentifier)
        let recipe = RawContinuationPrompt(
            textBeforeCursor: textBeforeCursor,
            register: register,
            scene: scene
        )
        guard !recipe.prompt.isEmpty else { return nil }

        let prompt = Self.promptByAddingIntentFutures(
            to: recipe.prompt,
            register: register,
            scene: scene,
            textBeforeCursor: textBeforeCursor
        )

        let body: [String: Any] = [
            "prompt": prompt,
            "n_predict": productProfile == .production
                ? register.generatedTokenBudget
                : productProfile.generatedTokenBudget,
            "temperature": productProfile.completionTemperature,
            "cache_prompt": true,
            "stop": ["\n"],
            "stream": true,
        ]
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("completion"))
        urlRequest.httpMethod = "POST"
        urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        urlRequest.timeoutInterval = 8

        let stream = try await transport.open(request: urlRequest)
        guard stream.statusCode == 200 else {
            stream.cancel()
            throw URLError(.badServerResponse)
        }

        var firstTokenMilliseconds: Int?
        var firstPartialMilliseconds: Int?
        let content = try await withTaskCancellationHandler {
            var rawOutput = ""
            var lastPartialVisibleText = ""
            var sawCompletionFrame = false
            // One decoder for the whole stream. Building a JSONDecoder per SSE
            // frame meant one allocation per token; it stays local to this
            // closure so nothing crosses an isolation boundary.
            let frameDecoder = JSONDecoder()
            for try await line in stream.lines {
                guard line.hasPrefix("data:") else { continue }
                let json = line.dropFirst("data:".count).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !json.isEmpty, json != "[DONE]" else { continue }
                let frame: StreamFrame
                do {
                    frame = try frameDecoder.decode(StreamFrame.self, from: Data(json.utf8))
                } catch {
                    throw URLError(.cannotParseResponse)
                }
                guard frame.hasRecognizedField else { throw URLError(.cannotParseResponse) }
                sawCompletionFrame = true
                if let piece = frame.content, !piece.isEmpty {
                    if firstTokenMilliseconds == nil {
                        firstTokenMilliseconds = Self.milliseconds(since: startedAt)
                    }
                    // llama.cpp emits token deltas. Always append: a repeated
                    // token can legitimately equal the text so far (" is" + " is").
                    rawOutput += piece
                    if StableStreamPrefix.mayAdvanceBoundary(piece),
                       let partial = stablePartial(rawOutput, recipe: recipe, textBeforeCursor: textBeforeCursor, scene: scene),
                       partial.visibleText != lastPartialVisibleText {
                        if firstPartialMilliseconds == nil {
                            firstPartialMilliseconds = Self.milliseconds(since: startedAt)
                        }
                        lastPartialVisibleText = partial.visibleText
                        onPartialSuggestion(partial)
                    }
                }
                if frame.stop == true { break }
            }
            guard sawCompletionFrame else { throw URLError(.cannotParseResponse) }
            return rawOutput
        } onCancel: {
            stream.cancel()
        }

        let normalized = recipe.normalizedContinuation(content)
        let clean = cleaner.cleanWithReason(normalized, after: textBeforeCursor)
        var suggestion = clean.suggestion
        var rejectionReason = clean.rejectionReason.map { String(describing: $0) }
        if let candidate = suggestion, SceneEchoPolicy.isEcho(candidate.visibleText, scene: scene) {
            suggestion = nil
            rejectionReason = "replaysScene"
        }

        if suggestion == nil, !content.isEmpty, let reason = rejectionReason {
            diagnostics.record("llama-suggestion-rejected", metadata: [
                "reason": reason,
            ])
        }
        var timing = [
            "totalMilliseconds": String(Self.milliseconds(since: startedAt)),
            "cleanedChars": String(suggestion?.visibleText.count ?? 0),
        ]
        if let firstTokenMilliseconds {
            timing["firstTokenMilliseconds"] = String(firstTokenMilliseconds)
        }
        if let firstPartialMilliseconds {
            timing["firstPartialMilliseconds"] = String(firstPartialMilliseconds)
        }
        diagnostics.record("llama-completion-timing", metadata: timing)
        return suggestion
    }

    /// The chat register gets no hint: on the 2026-08-23 synthetic eval the
    /// numeric label line placed before "Continuation:" lowered keyword hit
    /// rate (46% -> 39%) and produced the only empty outputs; the
    /// conversation-aware scaffold carries the intent instead.
    /// Monotonic, and clamped. `Date()` is wall-clock: an NTP correction or a
    /// manual clock change mid-request could produce a negative duration,
    /// which `latency_report.py`'s float parser would accept and fold
    /// straight into the percentile arrays these budgets depend on.
    /// `systemUptime` cannot step backwards, matching what
    /// `GhostInputController.slowKeyTiming` already does.
    private static func milliseconds(since start: TimeInterval) -> Int {
        max(0, Int(((ProcessInfo.processInfo.systemUptime - start) * 1_000).rounded()))
    }

    /// A partial is the cleaned continuation cut back to its last complete
    /// word. It goes through the same cleaner as the final, so anything the
    /// final would reject outright is never shown early either.
    private func stablePartial(
        _ rawOutput: String,
        recipe: RawContinuationPrompt,
        textBeforeCursor: String,
        scene: ScreenScene.Scene?
    ) -> CompletionSuggestion? {
        guard let cleaned = cleaner.cleanWithReason(
            recipe.normalizedContinuation(rawOutput),
            after: textBeforeCursor
        ).suggestion else { return nil }
        guard !SceneEchoPolicy.isEcho(cleaned.visibleText, scene: scene) else { return nil }
        guard let prefix = StableStreamPrefix.prefix(of: cleaned.visibleText) else { return nil }
        return CompletionSuggestion(text: prefix)
    }

    static func promptByAddingIntentFutures(
        to prompt: String,
        register: ContinuationRegister,
        scene: ScreenScene.Scene?,
        textBeforeCursor: String
    ) -> String {
        guard register != .chat else { return prompt }
        let futures = intentFutures(scene: scene, textBeforeCursor: textBeforeCursor)
        let summary = IntentFuturesPlanner.promptHint(for: futures)
        guard !summary.isEmpty,
              let marker = prompt.range(of: "Continuation:", options: .backwards)
        else { return prompt }
        let hint = "Likely response directions: \(summary)\n"
        var result = prompt
        result.insert(contentsOf: hint, at: marker.lowerBound)
        return result
    }

    /// Blends the scene-only prior (what Tilde already believed about this
    /// conversation before the user typed anything this turn) with the
    /// live, text-conditioned read — see `IntentFutureFusion`. This used to
    /// run through `IntentFutureCache`, a process-global lock-guarded cache
    /// keyed on the current scene; but `IntentFuturesPlanner.futures` is a
    /// pure, cheap function of `scene` alone, so recomputing the prior on
    /// every call produces exactly the value the cache would have served —
    /// the cache added a lock and mutable global state for no measurable
    /// benefit, and its "warm prior" was always discarded the moment the
    /// scene changed anyway. Call the planner directly.
    private static func intentFutures(
        scene: ScreenScene.Scene?,
        textBeforeCursor: String
    ) -> [IntentFuture] {
        guard scene != nil else {
            return IntentFuturesPlanner.futures(scene: nil, textBeforeCursor: textBeforeCursor)
        }
        let prior = IntentFuturesPlanner.futures(scene: scene, textBeforeCursor: "")
        let live = IntentFuturesPlanner.futures(scene: scene, textBeforeCursor: textBeforeCursor)
        return IntentFutureFusion.fuse(prior: prior, live: live)
    }
}
