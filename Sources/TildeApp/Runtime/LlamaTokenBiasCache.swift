import TildeCore
import Foundation

/// Bounded, loopback-only token-ID cache for decode-time Word Nudge (`logit_bias`).
///
/// Resolves `" " + term` once via the app-owned `llama-server`'s `/tokenize`
/// endpoint (`with_pieces: true`) and caches exact-case `term -> firstTokenID`
/// in memory (0 ms on repeated keystrokes). Rejects bare-whitespace or
/// 1-character split pieces so tokenizers never boost `" "` or single letters.
/// Bounded to 512 entries, timed tightly (35 ms), hardened against redirects
/// and system proxies, and cleared on helper stop, model swap, or privacy wipe.
actor LlamaTokenBiasCache {
    struct TokenizePiece: Equatable, Sendable {
        let id: Int
        let piece: String?
    }

    typealias TokenizeRequest = @Sendable (URLRequest) async -> [TokenizePiece]?

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

    /// Convenience test initializer accepting plain `[Int]?` token ID stubs.
    init(
        baseURL: URL,
        apiKey: String? = nil,
        performTokenIDs: @escaping @Sendable (URLRequest) async -> [Int]?
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.perform = { request in
            await performTokenIDs(request)?.map { TokenizePiece(id: $0, piece: nil) }
        }
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
            // Preserve exact surface casing so "Thursday" and "thursday" keep
            // their distinct BPE token IDs.
            let key = entry.term
            if let tokenID = cache[key] {
                resolvedByTokenID[tokenID] = max(resolvedByTokenID[tokenID] ?? 0, entry.weight)
            } else {
                uncached.append(entry)
            }
        }

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
                              let first = tokens.first,
                              Self.isSafeFirstPiece(first) else {
                            return nil
                        }
                        return (entry.term, first.id, entry.weight)
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

    /// Rejects bare whitespace tokens (e.g. Qwen 3.5 `" "` ID 220) and 1-letter
    /// prefix splits (e.g. `" g"` for `" gRPC"`) that would distort unrelated words.
    static func isSafeFirstPiece(_ token: TokenizePiece) -> Bool {
        guard let piece = token.piece else { return true }
        let core = piece.trimmingCharacters(in: .whitespacesAndNewlines)
        return core.count >= 2 && core.contains(where: \.isLetter)
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
            "with_pieces": true,
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

    private static let sessionDelegate = LocalhostURLSessionDelegate()

    private static let sharedSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.connectionProxyDictionary = [:]
        configuration.timeoutIntervalForRequest = uncachedTimeoutSeconds
        configuration.timeoutIntervalForResource = uncachedTimeoutSeconds * 2
        return URLSession(configuration: configuration, delegate: sessionDelegate, delegateQueue: nil)
    }()

    private struct TokenizeWithPiecesResponse: Decodable {
        struct Item: Decodable {
            let id: Int
            let piece: String?
        }
        let tokens: [Item]
    }

    private struct TokenizeIDsResponse: Decodable {
        let tokens: [Int]
    }

    private static let defaultPerform: TokenizeRequest = { request in
        guard let (data, response) = try? await sharedSession.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else {
            return nil
        }
        if let decoded = try? JSONDecoder().decode(TokenizeWithPiecesResponse.self, from: data) {
            return decoded.tokens.map { TokenizePiece(id: $0.id, piece: $0.piece) }
        }
        if let decoded = try? JSONDecoder().decode(TokenizeIDsResponse.self, from: data) {
            return decoded.tokens.map { TokenizePiece(id: $0, piece: nil) }
        }
        return nil
    }
}
