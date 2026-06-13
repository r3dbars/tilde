import Foundation
import AutocompleteLabCore
import MLXLMCommon

struct MLXPromptKVCacheConfiguration: Equatable, Sendable {
    static let environmentKey = "AUTOCOMPLETE_LAB_MLX_KV_CACHE"

    let isEnabled: Bool

    init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    static func fromEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> Self {
        guard let value = environment[environmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return Self(isEnabled: false)
        }

        return Self(isEnabled: ["1", "true", "yes", "on"].contains(value))
    }
}

enum MLXPromptKVCacheMissReason: String, Equatable, Sendable {
    case envFlagOff = "env-flag-off"
    case noPriorPrompt = "no-prior-prompt"
    case wordCompletion = "word-completion"
    case missingApp = "missing-app"
    case missingFieldIdentity = "missing-field-identity"
    case appChanged = "app-changed"
    case fieldChanged = "field-changed"
    case fieldKindChanged = "field-kind-changed"
    case behaviorProfileChanged = "behavior-profile-changed"
    case modeChanged = "mode-changed"
    case textDidNotGrow = "text-did-not-grow"
    case earlierTextEdit = "earlier-text-edit"
    case textAfterCursorChanged = "text-after-cursor-changed"
    case paragraphChanged = "paragraph-changed"
    case sentenceChanged = "sentence-changed"
    case modelRevisionChanged = "model-revision-changed"
    case promptStyleChanged = "prompt-style-changed"
    case systemPromptChanged = "system-prompt-changed"
    case tokenPrefixMismatch = "token-prefix-mismatch"
    case emptyTokenAppend = "empty-token-append"
    case untrimmablePromptCache = "untrimmable-prompt-cache"
    case visionLanguageRuntime = "vision-language-runtime"
}

enum MLXPromptKVCacheDecision: Equatable, Sendable {
    case hit
    case miss(MLXPromptKVCacheMissReason)

    var isHit: Bool {
        if case .hit = self {
            return true
        }
        return false
    }

    var name: String {
        switch self {
        case .hit:
            return "hit"
        case .miss:
            return "miss"
        }
    }

    var missReason: MLXPromptKVCacheMissReason? {
        if case let .miss(reason) = self {
            return reason
        }
        return nil
    }
}

struct MLXPromptKVCacheKey: Equatable, Sendable {
    let modelRevision: String
    let promptStyleFingerprint: String
    let systemPromptFingerprint: String
    let promptTokenFingerprint: String

    var traceDescription: String {
        [
            modelRevision,
            promptStyleFingerprint,
            systemPromptFingerprint,
            promptTokenFingerprint
        ].joined(separator: "|")
    }
}

struct MLXPromptKVCacheLookup {
    let decision: MLXPromptKVCacheDecision
    let currentKey: MLXPromptKVCacheKey
    let reusedKey: MLXPromptKVCacheKey?
    let promptTokens: [Int]
    let appendTokens: [Int]
    let reusableCache: [KVCache]?

    var traceMetadata: [String: String] {
        var metadata: [String: String] = [
            "mlxPromptKVCacheEnabled": "true",
            "mlxPromptKVCacheDecision": decision.name,
            "mlxPromptKVCacheHit": String(decision.isHit),
            "mlxPromptKVCacheKey": currentKey.traceDescription,
            "mlxPromptKVCachePromptTokens": String(promptTokens.count),
            "mlxPromptKVCacheAppendTokens": String(appendTokens.count),
            "mlxPromptKVCacheTokenPrefixMatched": String(decision.isHit)
        ]

        if let reusedKey {
            metadata["mlxPromptKVCacheReuseKey"] = reusedKey.traceDescription
        }

        if let missReason = decision.missReason {
            metadata["mlxPromptKVCacheMissReason"] = missReason.rawValue
            metadata["mlxPromptKVCachePoisonedAvoided"] = String(missReason.avoidsPoisonedCache)
        } else {
            metadata["mlxPromptKVCacheMissReason"] = "none"
            metadata["mlxPromptKVCachePoisonedAvoided"] = "false"
        }

        return metadata
    }
}

struct MLXPromptKVCacheOwner {
    private struct Entry {
        let key: MLXPromptKVCacheKey
        let request: CompletionRequest
        let promptTokens: [Int]
        let promptCache: [KVCache]
    }

    private var entry: Entry?
    private var warmAppendStats = MLXPromptKVCacheWarmAppendStats()

    let configuration: MLXPromptKVCacheConfiguration

    init(configuration: MLXPromptKVCacheConfiguration = .fromEnvironment()) {
        self.configuration = configuration
    }

    mutating func clear() {
        entry = nil
        warmAppendStats = MLXPromptKVCacheWarmAppendStats()
    }

    func bypassMetadata(reason: MLXPromptKVCacheMissReason) -> [String: String] {
        [
            "mlxPromptKVCacheEnabled": String(configuration.isEnabled),
            "mlxPromptKVCacheDecision": "miss",
            "mlxPromptKVCacheHit": "false",
            "mlxPromptKVCacheMissReason": reason.rawValue,
            "mlxPromptKVCachePoisonedAvoided": String(reason.avoidsPoisonedCache)
        ]
    }

    func lookup(
        request: CompletionRequest,
        promptTokens: [Int],
        systemPrompt: String,
        modelRevision: String,
        promptStyleIdentifier: String
    ) -> MLXPromptKVCacheLookup {
        let currentKey = Self.key(
            modelRevision: modelRevision,
            promptStyleIdentifier: promptStyleIdentifier,
            systemPrompt: systemPrompt,
            promptTokens: promptTokens
        )

        guard configuration.isEnabled else {
            return miss(
                .envFlagOff,
                currentKey: currentKey,
                promptTokens: promptTokens
            )
        }

        guard let entry else {
            return miss(
                .noPriorPrompt,
                currentKey: currentKey,
                promptTokens: promptTokens
            )
        }

        if entry.key.modelRevision != currentKey.modelRevision {
            return miss(.modelRevisionChanged, currentKey: currentKey, promptTokens: promptTokens)
        }

        if entry.key.promptStyleFingerprint != currentKey.promptStyleFingerprint {
            return miss(.promptStyleChanged, currentKey: currentKey, promptTokens: promptTokens)
        }

        if entry.key.systemPromptFingerprint != currentKey.systemPromptFingerprint {
            return miss(.systemPromptChanged, currentKey: currentKey, promptTokens: promptTokens)
        }

        switch RuntimeSessionCachePolicy().decision(previous: entry.request, current: request) {
        case .reuse:
            break
        case let .reset(reason):
            return miss(
                Self.missReason(for: reason, previous: entry.request, current: request),
                currentKey: currentKey,
                promptTokens: promptTokens,
                reusedKey: entry.key
            )
        }

        guard promptTokens.starts(with: entry.promptTokens) else {
            let reason: MLXPromptKVCacheMissReason = request.textBeforeCursor.hasPrefix(entry.request.textBeforeCursor)
                ? .tokenPrefixMismatch
                : .earlierTextEdit
            return miss(
                reason,
                currentKey: currentKey,
                promptTokens: promptTokens,
                reusedKey: entry.key
            )
        }

        let appendTokens = Array(promptTokens.dropFirst(entry.promptTokens.count))
        guard !appendTokens.isEmpty else {
            return miss(
                .emptyTokenAppend,
                currentKey: currentKey,
                promptTokens: promptTokens,
                reusedKey: entry.key
            )
        }

        return MLXPromptKVCacheLookup(
            decision: .hit,
            currentKey: currentKey,
            reusedKey: entry.key,
            promptTokens: promptTokens,
            appendTokens: appendTokens,
            reusableCache: entry.promptCache.map { $0.copy() }
        )
    }

    mutating func storePreparedPromptCache(
        _ cache: [KVCache],
        key: MLXPromptKVCacheKey,
        request: CompletionRequest,
        promptTokens: [Int]
    ) -> [String: String] {
        guard configuration.isEnabled else {
            return bypassMetadata(reason: .envFlagOff)
        }

        guard canTrimPromptCache(cache), !cache.isEmpty else {
            entry = nil
            return [
                "mlxPromptKVCacheStored": "false",
                "mlxPromptKVCacheStoreReason": MLXPromptKVCacheMissReason.untrimmablePromptCache.rawValue
            ]
        }

        entry = Entry(
            key: key,
            request: request,
            promptTokens: promptTokens,
            promptCache: cache.map { $0.copy() }
        )

        return [
            "mlxPromptKVCacheStored": "true",
            "mlxPromptKVCacheStoreReason": "prompt-prefill",
            "mlxPromptKVCacheStoredTokens": String(promptTokens.count)
        ]
    }

    mutating func recordWarmAppendFirstToken(milliseconds: Int?, wasHit: Bool) -> [String: String] {
        guard wasHit, let milliseconds else {
            return [:]
        }

        warmAppendStats.record(milliseconds)
        return [
            "mlxPromptKVCacheWarmAppendFirstTokenMilliseconds": String(milliseconds),
            "mlxPromptKVCacheWarmAppendFirstTokenP95Milliseconds": String(warmAppendStats.p95)
        ]
    }

    mutating func storePreparedPromptForTesting(
        request: CompletionRequest,
        promptTokens: [Int],
        systemPrompt: String,
        modelRevision: String,
        promptStyleIdentifier: String
    ) {
        let key = Self.key(
            modelRevision: modelRevision,
            promptStyleIdentifier: promptStyleIdentifier,
            systemPrompt: systemPrompt,
            promptTokens: promptTokens
        )
        entry = Entry(key: key, request: request, promptTokens: promptTokens, promptCache: [])
    }

    private func miss(
        _ reason: MLXPromptKVCacheMissReason,
        currentKey: MLXPromptKVCacheKey,
        promptTokens: [Int],
        reusedKey: MLXPromptKVCacheKey? = nil
    ) -> MLXPromptKVCacheLookup {
        MLXPromptKVCacheLookup(
            decision: .miss(reason),
            currentKey: currentKey,
            reusedKey: reusedKey,
            promptTokens: promptTokens,
            appendTokens: [],
            reusableCache: nil
        )
    }

    private static func missReason(
        for reason: RuntimeSessionCacheResetReason,
        previous: CompletionRequest,
        current: CompletionRequest
    ) -> MLXPromptKVCacheMissReason {
        switch reason {
        case .noPriorRequest:
            return .noPriorPrompt
        case .wordCompletion:
            return .wordCompletion
        case .missingApp:
            return .missingApp
        case .missingFieldIdentity:
            return .missingFieldIdentity
        case .appChanged:
            return .appChanged
        case .fieldChanged:
            return .fieldChanged
        case .fieldKindChanged:
            return .fieldKindChanged
        case .behaviorProfileChanged:
            return .behaviorProfileChanged
        case .modeChanged:
            return .modeChanged
        case .textDidNotGrow:
            return current.textBeforeCursor.hasPrefix(previous.textBeforeCursor)
                ? .textDidNotGrow
                : .earlierTextEdit
        case .textAfterCursorChanged:
            return .textAfterCursorChanged
        case .paragraphChanged:
            return .paragraphChanged
        case .sentenceChanged:
            return .sentenceChanged
        }
    }

    private static func key(
        modelRevision: String,
        promptStyleIdentifier: String,
        systemPrompt: String,
        promptTokens: [Int]
    ) -> MLXPromptKVCacheKey {
        MLXPromptKVCacheKey(
            modelRevision: modelRevision,
            promptStyleFingerprint: fingerprint(promptStyleIdentifier),
            systemPromptFingerprint: fingerprint(systemPrompt),
            promptTokenFingerprint: fingerprint(promptTokens)
        )
    }

    private static func fingerprint(_ text: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return String(hash, radix: 16)
    }

    private static func fingerprint(_ tokens: [Int]) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for token in tokens {
            var value = UInt64(bitPattern: Int64(token))
            for _ in 0..<8 {
                hash ^= value & 0xff
                hash &*= 0x100000001b3
                value >>= 8
            }
        }
        return String(hash, radix: 16)
    }
}

private extension MLXPromptKVCacheMissReason {
    var avoidsPoisonedCache: Bool {
        switch self {
        case .earlierTextEdit, .tokenPrefixMismatch, .modelRevisionChanged, .promptStyleChanged, .systemPromptChanged:
            return true
        default:
            return false
        }
    }
}

private struct MLXPromptKVCacheWarmAppendStats {
    private var samples: [Int] = []
    private let capacity = 128

    var p95: Int {
        guard !samples.isEmpty else {
            return 0
        }

        let sorted = samples.sorted()
        let index = min(sorted.count - 1, Int(Double(sorted.count - 1) * 0.95))
        return sorted[index]
    }

    mutating func record(_ milliseconds: Int) {
        samples.append(max(0, milliseconds))
        if samples.count > capacity {
            samples.removeFirst(samples.count - capacity)
        }
    }
}
