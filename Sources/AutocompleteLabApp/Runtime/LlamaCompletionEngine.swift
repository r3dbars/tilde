import AutocompleteLabCore
import Foundation

/// One deterministic, final-only completion request to the app-owned llama server.
final class LlamaCompletionEngine: @unchecked Sendable {
    private let baseURL: URL
    private let cleaner = CompletionOutputCleaner()

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func suggestion(
        textBeforeCursor: String,
        appBundleIdentifier: String?
    ) async throws -> CompletionSuggestion? {
        let startedAt = Date()
        let register = ContinuationRegister.from(bundleIdentifier: appBundleIdentifier)
        let recipe = RawContinuationPrompt(
            textBeforeCursor: textBeforeCursor,
            register: register
        )
        guard !recipe.prompt.isEmpty else { return nil }

        let body: [String: Any] = [
            "prompt": recipe.prompt,
            "n_predict": register.generatedTokenBudget,
            "temperature": 0,
            "cache_prompt": true,
            "stop": ["\n"],
            "stream": false,
        ]
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
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = object["content"] as? String else {
            throw URLError(.cannotParseResponse)
        }

        let clean = cleaner.cleanWithReason(
            recipe.normalizedContinuation(raw),
            after: textBeforeCursor
        )
        if clean.suggestion == nil, !raw.isEmpty, let reason = clean.rejectionReason {
            DiagnosticsLog.shared.record("llama-suggestion-rejected", metadata: [
                "reason": String(describing: reason),
            ])
        }
        DiagnosticsLog.shared.record("llama-completion-timing", metadata: [
            "totalMilliseconds": String(Int(Date().timeIntervalSince(startedAt) * 1_000)),
            "cleanedChars": String(clean.suggestion?.visibleText.count ?? 0),
        ])
        return clean.suggestion
    }
}
