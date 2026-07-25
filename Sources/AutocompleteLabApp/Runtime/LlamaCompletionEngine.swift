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
        // env still wins; persisted "steadytype.<NAME>" defaults survive reboots.
        func envInt(_ k: String) -> Int? { RuntimeSetting.int(String(k.dropFirst("STEADYTYPE_".count))) }
        func envDouble(_ k: String) -> Double? { RuntimeSetting.double(String(k.dropFirst("STEADYTYPE_".count))) }

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
        // Owner's "holding it wrong" hypothesis (2026-07-25): instruct models
        // failed our RAW recipe — but the task can be ASKED as a question with
        // a proper chat template. STEADYTYPE_PROMPT_MODE=instruct tests that:
        // Gemma-template prompt framing screen+typed-text as an explicit task.
        let instructMode = RuntimeSetting.string("PROMPT_MODE") == "instruct"
        var stops = ["\n"]
        var servedPrompt = recipe.prompt
        if instructMode {
            let tail = String(request.textBeforeCursor.suffix(envInt("STEADYTYPE_MAX_CONTEXT_CHARS") ?? 3000))
            let screen = (request.visiblePageContext?.promptText).map { String($0.prefix(700)) }
            var task = "You are the writer's silent autocomplete. "
            if let screen, !screen.isEmpty {
                task += "Their screen shows:\n\(screen)\n\n"
            }
            task += "They are typing and have written so far:\n\(tail)\n\n"
            task += "Reply with ONLY the next few words they would type — continue their text "
            task += "exactly from where it stops, in their own casual voice. No quotes, no "
            task += "commentary, never repeat what is already written."
            servedPrompt = "<start_of_turn>user\n\(task)<end_of_turn>\n<start_of_turn>model\n"
            stops = ["\n", "<end_of_turn>"]
        }
        var body: [String: Any] = [
            "prompt": servedPrompt,
            "n_predict": min(register.generatedTokenBudget, request.mode.generatedTokenCeiling),
            "temperature": temperature,
            "cache_prompt": true,
            "stop": stops,
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
        // Adaptive length ("go after the accuracy"): instead of a fixed word
        // cap, cut the suggestion at the first token whose probability falls
        // below this floor. The model runs as far as it stays SURE — two words
        // on a shaky guess, fifteen on a confident one. 0 = off.
        let tokenConfidenceFloor = envDouble("STEADYTYPE_TOKEN_CONFIDENCE_FLOOR") ?? 0
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            guard let object = try? JSONSerialization.jsonObject(
                with: Data(line.dropFirst(6).utf8)
            ) as? [String: Any] else { continue }

            let chunkProbability = (object["completion_probabilities"] as? [[String: Any]])
                .flatMap { $0.first?["logprob"] as? Double }
                .map { exp($0) }

            // Read the first generated token's probability and gate before we
            // ever emit a partial, so a low-confidence guess is never shown.
            if firstTokenProbability == nil, let p = chunkProbability {
                firstTokenProbability = p
                if confidenceThreshold > 0, p < confidenceThreshold {
                    DiagnosticsLog.shared.record("llama-completion-gated", metadata: [
                        "firstTokenProbability": String(format: "%.3f", p),
                        "threshold": String(confidenceThreshold),
                    ])
                    return nil
                }
            }

            // Confidence cliff: certainty dropped mid-thought — stop here and
            // keep only the prefix the model was sure of. Tokens are not words,
            // so also trim any dangling word-fragment at the cut.
            if tokenConfidenceFloor > 0, !rawOutput.isEmpty,
               let p = chunkProbability, p < tokenConfidenceFloor {
                if !rawOutput.hasSuffix(" "), let lastSpace = rawOutput.lastIndex(of: " ") {
                    let trimmed = String(rawOutput[..<lastSpace])
                    // Never trim a lone word away to nothing.
                    if !trimmed.trimmingCharacters(in: .whitespaces).isEmpty {
                        rawOutput = trimmed
                    }
                }
                break
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
