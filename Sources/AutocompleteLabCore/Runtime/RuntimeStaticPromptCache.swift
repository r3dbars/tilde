import Foundation

public struct RuntimeStaticPromptCacheLookup: Equatable, Sendable {
    public let systemPrompt: String
    public let key: String
    public let hit: Bool
    public let size: Int

    public init(systemPrompt: String, key: String, hit: Bool, size: Int) {
        self.systemPrompt = systemPrompt
        self.key = key
        self.hit = hit
        self.size = size
    }

    public var traceMetadata: [String: String] {
        [
            "runtimeStaticPromptCacheHit": String(hit),
            "runtimeStaticPromptCacheKey": key,
            "runtimeStaticPromptCacheSize": String(size)
        ]
    }
}

public struct RuntimeStaticPromptCache: Equatable, Sendable {
    public let capacity: Int
    private var cachedPrompts: [String: String]
    private var orderedKeys: [String]

    public init(capacity: Int = 32) {
        self.capacity = max(1, capacity)
        self.cachedPrompts = [:]
        self.orderedKeys = []
    }

    public mutating func lookup(systemPrompt: String) -> RuntimeStaticPromptCacheLookup {
        let key = Self.fingerprint(systemPrompt)
        if let cachedPrompt = cachedPrompts[key] {
            touch(key)
            return RuntimeStaticPromptCacheLookup(
                systemPrompt: cachedPrompt,
                key: key,
                hit: true,
                size: cachedPrompts.count
            )
        }

        cachedPrompts[key] = systemPrompt
        orderedKeys.append(key)
        trimIfNeeded()

        return RuntimeStaticPromptCacheLookup(
            systemPrompt: systemPrompt,
            key: key,
            hit: false,
            size: cachedPrompts.count
        )
    }

    private mutating func touch(_ key: String) {
        orderedKeys.removeAll { $0 == key }
        orderedKeys.append(key)
    }

    private mutating func trimIfNeeded() {
        while cachedPrompts.count > capacity,
              let evictedKey = orderedKeys.first {
            orderedKeys.removeFirst()
            cachedPrompts[evictedKey] = nil
        }
    }

    private static func fingerprint(_ text: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return String(hash, radix: 16)
    }
}
