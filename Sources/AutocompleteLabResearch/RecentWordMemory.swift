import Foundation
import AutocompleteLabCore

public struct RecentWordMemory: Equatable, Sendable {
    public let capacity: Int
    public private(set) var words: [String]

    public init(capacity: Int = 500, words: [String] = []) {
        self.capacity = max(1, capacity)
        self.words = Array(words.suffix(self.capacity))
    }

    public mutating func remember(_ newWords: [String]) {
        guard !newWords.isEmpty else {
            return
        }

        words.append(contentsOf: newWords)
        if words.count > capacity {
            words.removeFirst(words.count - capacity)
        }
    }
}

public struct ScopedRecentWordMemory: Equatable, Sendable {
    public let capacityPerScope: Int
    private var memories: [String: RecentWordMemory]

    public init(
        capacityPerScope: Int = 500,
        memories: [String: RecentWordMemory] = [:]
    ) {
        self.capacityPerScope = max(1, capacityPerScope)
        self.memories = memories
    }

    public func words(for scope: String) -> [String] {
        memories[normalizedScope(scope)]?.words ?? []
    }

    public mutating func remember(_ newWords: [String], scope: String) {
        let scope = normalizedScope(scope)
        guard !scope.isEmpty,
              !newWords.isEmpty else {
            return
        }

        var memory = memories[scope] ?? RecentWordMemory(capacity: capacityPerScope)
        memory.remember(newWords)
        memories[scope] = memory
    }

    private func normalizedScope(_ scope: String) -> String {
        scope.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
