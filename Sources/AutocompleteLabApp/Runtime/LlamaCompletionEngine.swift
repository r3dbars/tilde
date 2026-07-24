import AutocompleteLabCore
import Foundation

/// CompletionEngine speaking the raw-continuation recipe to a local llama.cpp
/// server (see RawContinuationPrompt). Output flows through the same
/// CompletionOutputCleaner discipline as the MLX engine — every model path
/// gets identical persona/echo/no-suggestion filtering.
enum LlamaEngineError: Error {
    case transport(String)
}

final class LlamaCompletionEngine: CompletionEngine, @unchecked Sendable {

    private let baseURL: URL
    // STEADYTYPE_MAX_VISIBLE_WORDS caps how many words a suggestion may show
    // (owner tuning 2026-07-24: shorter offers, higher precision).
    private let cleaner = CompletionOutputCleaner(
        maxVisibleWords: ProcessInfo.processInfo.environment["STEADYTYPE_MAX_VISIBLE_WORDS"].flatMap(Int.init)
            ?? CompletionModelPolicy.mvp.maxVisibleWords
    )

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func suggestion(for request: CompletionRequest) async throws -> CompletionSuggestion? {
        try await suggestion(for: request) { _ in }
    }

    func suggestion(
        for request: CompletionRequest,
        onPartialSuggestion: @escaping @Sendable (CompletionSuggestion) -> Void
    ) async throws -> CompletionSuggestion? {
        let startedAt = Date()
        // All tuning knobs read from the environment so the auto-research loop
        // can turn any dial without a rebuild (see script/research_loop.py).
        let env = ProcessInfo.processInfo.environment
        func envInt(_ k: String) -> Int? { env[k].flatMap(Int.init) }
        func envDouble(_ k: String) -> Double? { env[k].flatMap(Double.init) }

        let register = ContinuationRegister.from(bundleIdentifier: request.appBundleIdentifier)
        let recipe = RawContinuationPrompt(
            textBeforeCursor: request.textBeforeCursor,
            screenContext: request.visiblePageContext?.promptText,
            register: register,
            maxContextCharacters: envInt("STEADYTYPE_MAX_CONTEXT_CHARS") ?? 3000,
            maxScreenContextCharacters: envInt("STEADYTYPE_MAX_SCREEN_CHARS") ?? 700
        )
        // Greedy (temperature 0) is the default; the loop can explore warmer
        // settings with the sampler knobs below.
        let temperature = envDouble("STEADYTYPE_TEMPERATURE") ?? 0
        // Confidence gate (0..1): suppress the whole suggestion when the model's
        // first-token probability is below the bar. 0 = off. n_probs:1 asks
        // llama.cpp to report each token's logprob.
        var confidenceThreshold = envDouble("STEADYTYPE_CONFIDENCE") ?? 0
        // Brave start, strict cruise: with only a few words on the page the
        // model's first-token probability is naturally low (0.03–0.07 observed),
        // so a uniform bar mutes exactly the moment the writer wants company.
        // Under the short-context cutoff, halve the bar (both tunable).
        let shortContextCutoff = envInt("STEADYTYPE_CONFIDENCE_SHORT_CUTOFF") ?? 60
        if request.textBeforeCursor.count < shortContextCutoff {
            confidenceThreshold = envDouble("STEADYTYPE_CONFIDENCE_SHORT") ?? confidenceThreshold / 2
        }
        // Screen-echo guard: drop suggestions that copy >= N visible words from
        // the screen. Tunable because a low N can over-suppress good guesses.
        let echoGuardMinWords = envInt("STEADYTYPE_ECHO_GUARD_MIN_WORDS") ?? 4
        var body: [String: Any] = [
            "prompt": recipe.prompt,
            "n_predict": min(register.generatedTokenBudget, request.mode.generatedTokenCeiling),
            "temperature": temperature,
            "cache_prompt": true,
            "stop": ["\n"],
            "stream": true,
            "n_probs": 1,
        ]
        // Sampler knobs — only bite when temperature > 0; the loop pairs them
        // with warmer temperatures to explore beyond greedy decoding.
        if let v = envDouble("STEADYTYPE_TOP_P") { body["top_p"] = v }
        if let v = envInt("STEADYTYPE_TOP_K") { body["top_k"] = v }
        if let v = envDouble("STEADYTYPE_MIN_P") { body["min_p"] = v }
        if let v = envDouble("STEADYTYPE_REPEAT_PENALTY") { body["repeat_penalty"] = v }
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("completion"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        urlRequest.timeoutInterval = 10

        let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw LlamaEngineError.transport("http error")
        }

        var rawOutput = ""
        var lastPartialVisibleText = ""
        var firstChunkMilliseconds: Int?
        var promptTokensProcessed: Int?
        var firstTokenProbability: Double?
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            guard let object = try? JSONSerialization.jsonObject(
                with: Data(line.dropFirst(6).utf8)
            ) as? [String: Any] else { continue }

            // Read the first generated token's probability and gate before we
            // ever emit a partial, so a low-confidence guess is never shown.
            if firstTokenProbability == nil,
               let probs = object["completion_probabilities"] as? [[String: Any]],
               let logprob = probs.first?["logprob"] as? Double {
                firstTokenProbability = exp(logprob)
                if confidenceThreshold > 0, exp(logprob) < confidenceThreshold {
                    DiagnosticsLog.shared.record("llama-completion-gated", metadata: [
                        "firstTokenProbability": String(format: "%.3f", exp(logprob)),
                        "threshold": String(confidenceThreshold),
                    ])
                    return nil
                }
            }

            if let piece = object["content"] as? String, !piece.isEmpty {
                if firstChunkMilliseconds == nil {
                    firstChunkMilliseconds = Int(Date().timeIntervalSince(startedAt) * 1000)
                }
                rawOutput += piece
                let partial = cleaner.clean(
                    recipe.normalizedContinuation(rawOutput),
                    after: request.textBeforeCursor,
                    mode: request.mode
                )
                if let partial, !partial.isEmpty, partial.visibleText != lastPartialVisibleText {
                    lastPartialVisibleText = partial.visibleText
                    onPartialSuggestion(partial)
                }
            }
            if (object["stop"] as? Bool) == true {
                if let timings = object["timings"] as? [String: Any] {
                    promptTokensProcessed = (timings["prompt_n"] as? NSNumber)?.intValue
                }
                break
            }
        }

        var suggestion = cleaner.clean(
            recipe.normalizedContinuation(rawOutput),
            after: request.textBeforeCursor,
            mode: request.mode
        )
        // The display word-cap can slice a finished sentence back into a
        // dangling fragment ("…any thoughts on the proposal." capped at 8 words
        // ends on "the") — repair the visible tail after capping.
        if let capped = suggestion?.visibleText {
            let repaired = RawContinuationPrompt.repairDanglingTail(capped)
            if repaired != capped {
                let clean = repaired.trimmingCharacters(in: .whitespaces)
                suggestion = clean.isEmpty ? nil : CompletionSuggestion(
                    text: repaired,
                    maxVisibleWords: envInt("STEADYTYPE_MAX_VISIBLE_WORDS")
                        ?? CompletionModelPolicy.mvp.maxVisibleWords
                )
            }
        }
        // Screen-echo guard: never "predict" words by copying a run of text the
        // user can already see on screen (their own draft elsewhere, the message
        // being replied to). Grounding is welcome; verbatim copying is not.
        if echoGuardMinWords > 0,
           let visible = suggestion?.visibleText.trimmingCharacters(in: .whitespaces).lowercased(),
           visible.split(separator: " ").count >= echoGuardMinWords,
           let screen = request.visiblePageContext?.text.lowercased(),
           screen.contains(visible) {
            suggestion = nil
        }
        DiagnosticsLog.shared.record("llama-completion-timing", metadata: [
            "totalMilliseconds": String(Int(Date().timeIntervalSince(startedAt) * 1000)),
            "firstChunkMilliseconds": firstChunkMilliseconds.map(String.init) ?? "none",
            "promptTokensProcessed": promptTokensProcessed.map(String.init) ?? "unknown",
            "screenContextAttached": String(request.visiblePageContext != nil),
            "cleanedChars": String(suggestion?.visibleText.count ?? 0),
            "mode": request.mode.rawValue,
        ])
        // Owner-opt-in training capture: the situation the model saw (typed +
        // screen) with what it guessed — inference-identical training context.
        if let visible = suggestion?.visibleText, !visible.isEmpty {
            TrainingSampleLog.record(
                appBundle: request.appBundleIdentifier,
                mode: request.mode.rawValue,
                typedContext: request.textBeforeCursor,
                screenContext: request.visiblePageContext?.text,
                suggestion: visible,
                firstTokenProbability: firstTokenProbability
            )
        }
        return suggestion
    }
}

/// Routes phrase continuations to the reliability engine (llama.cpp/Gemma) when
/// it is healthy, everything else — and any llama failure — to the MLX engine.
/// A llama SILENCE (nil suggestion) is respected, not retried on MLX: both
/// engines share the same output discipline, and silence means low confidence.
final class ModeRoutedCompletionEngine: CompletionEngine, @unchecked Sendable {

    private let phraseEngine: any CompletionEngine
    private let fallbackEngine: any CompletionEngine
    private let phraseEngineIsHealthy: @Sendable () -> Bool
    private let routeWordCompletions: @Sendable () -> Bool

    init(
        phraseEngine: any CompletionEngine,
        fallbackEngine: any CompletionEngine,
        phraseEngineIsHealthy: @escaping @Sendable () -> Bool,
        routeWordCompletions: @escaping @Sendable () -> Bool = { false }
    ) {
        self.phraseEngine = phraseEngine
        self.fallbackEngine = fallbackEngine
        self.phraseEngineIsHealthy = phraseEngineIsHealthy
        self.routeWordCompletions = routeWordCompletions
    }

    func suggestion(for request: CompletionRequest) async throws -> CompletionSuggestion? {
        try await suggestion(for: request) { _ in }
    }

    func suggestion(
        for request: CompletionRequest,
        onPartialSuggestion: @escaping @Sendable (CompletionSuggestion) -> Void
    ) async throws -> CompletionSuggestion? {
        // Word-completion requests historically belonged to the keyboard's
        // dictionary layer, so the model answered them with silence. With the
        // dictionary off (model-only A/B), routeWordCompletions hands the model
        // the current word too — the cleaner already knows not to prepend a
        // space in word mode.
        if request.mode != .wordCompletion || routeWordCompletions(), phraseEngineIsHealthy() {
            do {
                // nil here is the engine's low-confidence silence — respected,
                // never retried on the fallback (both engines share the same
                // output discipline).
                return try await phraseEngine.suggestion(for: request, onPartialSuggestion: onPartialSuggestion)
            } catch {
                // Engine/transport failure only: fall back to MLX.
            }
        }
        return try await fallbackEngine.suggestion(for: request, onPartialSuggestion: onPartialSuggestion)
    }
}
