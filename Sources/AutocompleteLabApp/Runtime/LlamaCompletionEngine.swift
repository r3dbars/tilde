import AutocompleteLabCore
import Foundation

/// One deterministic, final-only completion request to the app-owned llama server.
final class LlamaCompletionEngine: @unchecked Sendable {
    private let baseURL: URL
    private let cleaner = CompletionOutputCleaner()
    private let diagnostics: DiagnosticsLog

    init(baseURL: URL, diagnostics: DiagnosticsLog = .shared) {
        self.baseURL = baseURL
        self.diagnostics = diagnostics
    }

    func suggestion(
        textBeforeCursor: String,
        appBundleIdentifier: String?
    ) async throws -> CompletionSuggestion? {
        try await evidence(
            textBeforeCursor: textBeforeCursor,
            appBundleIdentifier: appBundleIdentifier,
            scene: nil
        ).suggestion
    }

    func suggestion(
        textBeforeCursor: String,
        appBundleIdentifier: String?,
        scene: ScreenScene.Scene?
    ) async throws -> CompletionSuggestion? {
        try await evidence(
            textBeforeCursor: textBeforeCursor,
            appBundleIdentifier: appBundleIdentifier,
            scene: scene
        ).suggestion
    }

    /// Same completion the user already receives, plus a memory-only token
    /// uncertainty trace. `temperature: -1` is llama-server's documented
    /// greedy mode; with `n_probs > 0` it also returns a simple softmax of the
    /// logits, giving Tilde useful uncertainty without sampling a different
    /// visible answer or issuing extra model calls.
    ///
    /// The trace and its shortening are opt-in (`ConsensusShorteningEnabled`):
    /// live measurement 2026-08-17 showed greedy prose dips below any casual
    /// probability bar within a token or two (0.50 and 0.20 both trimmed most
    /// ghosts to 1–4 words) and the n_probs softmax added ~160ms to p50, so
    /// the default path stays the pre-evidence request until a swept,
    /// phrase-level signal earns the tax.
    func evidence(
        textBeforeCursor: String,
        appBundleIdentifier: String?,
        scene: ScreenScene.Scene?
    ) async throws -> CompletionEvidence {
        let startedAt = Date()
        let register = ContinuationRegister.following(scene: scene, hostBundleIdentifier: appBundleIdentifier)
        let recipe = RawContinuationPrompt(
            textBeforeCursor: textBeforeCursor,
            register: register,
            scene: scene
        )
        guard !recipe.prompt.isEmpty else { return CompletionEvidence(suggestion: nil, tokens: []) }

        let prompt = Self.promptByAddingIntentFutures(
            to: recipe.prompt,
            scene: scene,
            textBeforeCursor: textBeforeCursor
        )

        let consensusEnabled = TildeSettings().consensusShorteningEnabled
        var body: [String: Any] = [
            "prompt": prompt,
            "n_predict": register.generatedTokenBudget(scene: scene),
            "temperature": consensusEnabled ? -1 : 0,
            "cache_prompt": true,
            "stop": ["\n"],
            "stream": false,
        ]
        if consensusEnabled { body["n_probs"] = 8 }
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("completion"))
        urlRequest.httpMethod = "POST"
        urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        urlRequest.timeoutInterval = 8

        let (data, response) = try await LocalhostURLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let decoded: (content: String, tokens: [CompletionTokenEvidence])
        do {
            decoded = try LlamaCompletionEvidenceParser.decode(data)
        } catch {
            throw URLError(.cannotParseResponse)
        }

        let normalized = recipe.normalizedContinuation(decoded.content)
        let clean = cleaner.cleanWithReason(normalized, after: textBeforeCursor)
        var suggestion = clean.suggestion

        if consensusEnabled, let current = suggestion {
            let normalizedVisible = String(normalized.drop(while: \.isWhitespace))
            let visibleWords = current.visibleText.split(whereSeparator: \.isWhitespace).count
            if normalizedVisible.hasPrefix(current.visibleText),
               let budget = ConsensusGhostPolicy.visibleWordBudget(
                   tokens: decoded.tokens,
                   currentVisibleWords: visibleWords
               ) {
                let shortened = CompletionSuggestion(text: current.visibleText, maxVisibleWords: budget)
                if !shortened.visibleText.isEmpty { suggestion = shortened }
            }
        }

        if suggestion == nil, !decoded.content.isEmpty, let reason = clean.rejectionReason {
            diagnostics.record("llama-suggestion-rejected", metadata: [
                "reason": String(describing: reason),
            ])
        }
        diagnostics.record("llama-completion-timing", metadata: [
            "totalMilliseconds": String(Int(Date().timeIntervalSince(startedAt) * 1_000)),
            "cleanedChars": String(suggestion?.visibleText.count ?? 0),
        ])
        return CompletionEvidence(suggestion: suggestion, tokens: decoded.tokens)
    }

    static func promptByAddingIntentFutures(
        to prompt: String,
        scene: ScreenScene.Scene?,
        textBeforeCursor: String
    ) -> String {
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
