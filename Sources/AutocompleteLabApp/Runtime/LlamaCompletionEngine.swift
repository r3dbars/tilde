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
    // TILDE_MAX_VISIBLE_WORDS caps how many words a suggestion may show
    // (owner tuning 2026-07-24: shorter offers, higher precision).
    private let cleaner = CompletionOutputCleaner(
        maxVisibleWords: ProcessInfo.processInfo.environment["TILDE_MAX_VISIBLE_WORDS"].flatMap(Int.init)
            ?? CompletionSuggestion.defaultMaxVisibleWords
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
        // env still wins; persisted "tilde.<NAME>" defaults survive reboots.
        func envInt(_ k: String) -> Int? { RuntimeSetting.int(String(k.dropFirst("TILDE_".count))) }
        func envDouble(_ k: String) -> Double? { RuntimeSetting.double(String(k.dropFirst("TILDE_".count))) }

        let register = ContinuationRegister.from(bundleIdentifier: request.appBundleIdentifier)
        let recipe = RawContinuationPrompt(
            textBeforeCursor: request.textBeforeCursor,
            register: register,
            maxContextCharacters: envInt("TILDE_MAX_CONTEXT_CHARS") ?? 3000
        )
        // Nothing typed means there is nothing to continue. Stay silent rather
        // than hallucinate an opener.
        guard !recipe.prompt.isEmpty else { return nil }
        // Greedy (temperature 0) is the default; the loop can explore warmer
        // settings with the sampler knobs below.
        let temperature = envDouble("TILDE_TEMPERATURE") ?? 0
        // Confidence gate (0..1): suppress the whole suggestion when the model's
        // first-token probability is below the bar. 0 = off. n_probs:1 asks
        // llama.cpp to report each token's logprob.
        var confidenceThreshold = envDouble("TILDE_CONFIDENCE") ?? 0
        // Brave start, strict cruise: with only a few words on the page the
        // model's first-token probability is naturally low (0.03–0.07 observed),
        // so a uniform bar mutes exactly the moment the writer wants company.
        // Under the short-context cutoff, halve the bar (both tunable).
        let shortContextCutoff = envInt("TILDE_CONFIDENCE_SHORT_CUTOFF") ?? 60
        if request.textBeforeCursor.count < shortContextCutoff {
            confidenceThreshold = envDouble("TILDE_CONFIDENCE_SHORT") ?? confidenceThreshold / 2
        }
        // Owner's "holding it wrong" hypothesis (2026-07-25): instruct models
        // failed our RAW recipe — but the task can be ASKED as a question with
        // a proper chat template. TILDE_PROMPT_MODE=instruct tests that:
        // Gemma-template prompt framing typed text as an explicit task.
        let instructMode = RuntimeSetting.string("PROMPT_MODE") == "instruct"
        var stops = ["\n"]
        var servedPrompt = recipe.prompt
        if instructMode {
            let tail = String(request.textBeforeCursor.suffix(envInt("TILDE_MAX_CONTEXT_CHARS") ?? 3000))
            var task = "You are the writer's silent autocomplete. "
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
        if let v = envDouble("TILDE_TOP_P") { body["top_p"] = v }
        if let v = envInt("TILDE_TOP_K") { body["top_k"] = v }
        if let v = envDouble("TILDE_MIN_P") { body["min_p"] = v }
        if let v = envDouble("TILDE_REPEAT_PENALTY") { body["repeat_penalty"] = v }
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
        let tokenConfidenceFloor = envDouble("TILDE_TOKEN_CONFIDENCE_FLOOR") ?? 0
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

        let cleanResult = cleaner.cleanWithReason(
            recipe.normalizedContinuation(rawOutput),
            after: request.textBeforeCursor,
            mode: request.mode
        )
        var suggestion = cleanResult.suggestion
        // Rulebook-audit telemetry: WHICH filter killed a generation (reason
        // enum only — never text). Feeds the filter-worth audit; see the
        // cleaner-audit task. Only meaningful when the model actually spoke.
        if suggestion == nil, !rawOutput.isEmpty, let reason = cleanResult.rejectionReason {
            DiagnosticsLog.shared.record("llama-suggestion-rejected", metadata: [
                "reason": String(describing: reason),
                "mode": request.mode.rawValue,
            ])
        }
        // The display word-cap can slice a finished sentence back into a
        // dangling fragment ("…any thoughts on the proposal." capped at 8 words
        // ends on "the") — repair the visible tail after capping.
        if let capped = suggestion?.visibleText {
            let repaired = RawContinuationPrompt.repairDanglingTail(capped)
            if repaired != capped {
                let clean = repaired.trimmingCharacters(in: .whitespaces)
                suggestion = clean.isEmpty ? nil : CompletionSuggestion(
                    text: repaired,
                    maxVisibleWords: envInt("TILDE_MAX_VISIBLE_WORDS")
                        ?? CompletionSuggestion.defaultMaxVisibleWords
                )
            }
        }
        DiagnosticsLog.shared.record("llama-completion-timing", metadata: [
            "totalMilliseconds": String(Int(Date().timeIntervalSince(startedAt) * 1000)),
            "firstChunkMilliseconds": firstChunkMilliseconds.map(String.init) ?? "none",
            "promptTokensProcessed": promptTokensProcessed.map(String.init) ?? "unknown",
            "cleanedChars": String(suggestion?.visibleText.count ?? 0),
            "mode": request.mode.rawValue,
        ])
        return suggestion
    }
}
