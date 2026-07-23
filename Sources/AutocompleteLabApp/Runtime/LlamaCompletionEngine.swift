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
    private let cleaner = CompletionOutputCleaner(maxVisibleWords: CompletionModelPolicy.mvp.maxVisibleWords)

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
        let register = ContinuationRegister.from(bundleIdentifier: request.appBundleIdentifier)
        let recipe = RawContinuationPrompt(
            textBeforeCursor: request.textBeforeCursor,
            screenContext: request.visiblePageContext?.promptText,
            register: register
        )
        // Tuning-sweep override: STEADYTYPE_TEMPERATURE lets the driver confirm
        // greedy (0) is best for exact-match without a rebuild. Default 0.
        let temperature = ProcessInfo.processInfo.environment["STEADYTYPE_TEMPERATURE"]
            .flatMap(Double.init) ?? 0
        let body: [String: Any] = [
            "prompt": recipe.prompt,
            "n_predict": min(register.generatedTokenBudget, request.mode.generatedTokenCeiling),
            "temperature": temperature,
            "cache_prompt": true,
            "stop": ["\n"],
            "stream": true,
        ]
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
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            guard let object = try? JSONSerialization.jsonObject(
                with: Data(line.dropFirst(6).utf8)
            ) as? [String: Any] else { continue }

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
                    maxVisibleWords: CompletionModelPolicy.mvp.maxVisibleWords
                )
            }
        }
        // Screen-echo guard: never "predict" words by copying a run of text the
        // user can already see on screen (their own draft elsewhere, the message
        // being replied to). Grounding is welcome; verbatim copying is not.
        if let visible = suggestion?.visibleText.trimmingCharacters(in: .whitespaces).lowercased(),
           visible.split(separator: " ").count >= 4,
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

    init(
        phraseEngine: any CompletionEngine,
        fallbackEngine: any CompletionEngine,
        phraseEngineIsHealthy: @escaping @Sendable () -> Bool
    ) {
        self.phraseEngine = phraseEngine
        self.fallbackEngine = fallbackEngine
        self.phraseEngineIsHealthy = phraseEngineIsHealthy
    }

    func suggestion(for request: CompletionRequest) async throws -> CompletionSuggestion? {
        try await suggestion(for: request) { _ in }
    }

    func suggestion(
        for request: CompletionRequest,
        onPartialSuggestion: @escaping @Sendable (CompletionSuggestion) -> Void
    ) async throws -> CompletionSuggestion? {
        if request.mode != .wordCompletion, phraseEngineIsHealthy() {
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
