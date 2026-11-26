import TildeCore
import Foundation

/// Bounded, loopback-only token-ID cache for decode-time Word Nudge (`logit_bias`).
///
/// Resolves `" " + term` once via the app-owned `llama-server`'s `/tokenize`
/// endpoint and caches `term -> firstTokenID` in memory (0 ms on repeated
/// keystrokes). Bounded to 512 entries, timed tightly (35 ms) so an uncached
/// miss can never stall typing, and cleared immediately on helper restart,
/// model swap, or Personal History deletion.
actor LlamaTokenBiasCache {
    typealias TokenizeRequest = @Sendable (URLRequest) async -> [Int]?

    private static let maxEntries = 512
    private static let uncachedTimeoutSeconds: TimeInterval = 0.035

    private let baseURL: URL
    private let apiKey: String?
    private let perform: TokenizeRequest
    private var cache: [String: Int] = [:]
    private var insertionOrder: [String] = []
    private var generation: Int = 0

    init(
        baseURL: URL,
        apiKey: String? = nil,
        perform: TokenizeRequest? = nil
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.perform = perform ?? Self.defaultPerform
    }

    func clear() {
        generation &+= 1
        cache.removeAll(keepingCapacity: true)
        insertionOrder.removeAll(keepingCapacity: true)
    }

    struct TokenBiasEntry: Equatable, Sendable {
        let tokenID: Int
        let weight: Double
    }

    /// Resolves `terms` into Sendable `(tokenID, weight)` entries for `llama.cpp`'s
    /// `logit_bias` payload. Cached terms resolve synchronously in microseconds;
    /// uncached terms are resolved concurrently within a tight timeout so typing never waits.
    func logitBiasEntries(for terms: [WeightedBiasTerm]) async -> [TokenBiasEntry] {
        guard !terms.isEmpty else { return [] }
        let startGeneration = generation
        var resolvedByTokenID: [Int: Double] = [:]
        var uncached: [WeightedBiasTerm] = []

        for entry in terms {
            let key = entry.term.lowercased()
            if let tokenID = cache[key] {
                resolvedByTokenID[tokenID] = max(resolvedByTokenID[tokenID] ?? 0, entry.weight)
            } else {
                uncached.append(entry)
            }
        }

        // Resolve up to 10 uncached terms concurrently with a tight ceiling so
        // first-seen conversation words get nudged right away without adding lag.
        if !uncached.isEmpty {
            let batch = Array(uncached.prefix(10))
            let baseURL = self.baseURL
            let apiKey = self.apiKey
            let perform = self.perform
            let fetched: [(key: String, tokenID: Int, weight: Double)] = await withTaskGroup(
                of: (String, Int, Double)?.self
            ) { group in
                for entry in batch {
                    group.addTask {
                        guard let request = Self.makeTokenizeRequest(
                            baseURL: baseURL,
                            apiKey: apiKey,
                            text: " " + entry.term
                        ),
                              let tokens = await perform(request),
                              let first = tokens.first else {
                            return nil
                        }
                        return (entry.term.lowercased(), first, entry.weight)
                    }
                }
                var results: [(String, Int, Double)] = []
                for await item in group {
                    if let item { results.append(item) }
                }
                return results
            }

            if generation == startGeneration {
                for item in fetched {
                    store(key: item.key, tokenID: item.tokenID)
                    resolvedByTokenID[item.tokenID] = max(resolvedByTokenID[item.tokenID] ?? 0, item.weight)
                }
            }
        }

        return resolvedByTokenID
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }
            .map { TokenBiasEntry(tokenID: $0.key, weight: $0.value) }
    }

    private func store(key: String, tokenID: Int) {
        if cache[key] == nil {
            insertionOrder.append(key)
        }
        cache[key] = tokenID
        while insertionOrder.count > Self.maxEntries {
            let evicted = insertionOrder.removeFirst()
            cache.removeValue(forKey: evicted)
        }
    }

    private static func makeTokenizeRequest(
        baseURL: URL,
        apiKey: String?,
        text: String
    ) -> URLRequest? {
        let body: [String: Any] = [
            "content": text,
            "add_special": false,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        var request = URLRequest(url: baseURL.appendingPathComponent("tokenize"))
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        if let apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = data
        request.timeoutInterval = uncachedTimeoutSeconds
        return request
    }

    private static let sharedSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = uncachedTimeoutSeconds
        configuration.timeoutIntervalForResource = uncachedTimeoutSeconds * 2
        return URLSession(configuration: configuration)
    }()

    private struct TokenizeResponse: Decodable {
        let tokens: [Int]
    }

    private static let defaultPerform: TokenizeRequest = { request in
        guard let (data, response) = try? await sharedSession.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let decoded = try? JSONDecoder().decode(TokenizeResponse.self, from: data) else {
            return nil
        }
        return decoded.tokens
    }
}
