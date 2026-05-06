import Foundation

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
