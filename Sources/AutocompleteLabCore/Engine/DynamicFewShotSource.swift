import Foundation

public struct DynamicFewShotSource: Equatable, Sendable {
    public let minimumWords: Int
    public let continuationWords: Int
    public let maximumExamples: Int

    public init(
        minimumWords: Int = 6,
        continuationWords: Int = 3,
        maximumExamples: Int = 3
    ) {
        self.minimumWords = max(3, minimumWords)
        self.continuationWords = max(1, continuationWords)
        self.maximumExamples = max(0, maximumExamples)
    }

    public func examples(from personalContext: PersonalContext?) -> [String] {
        guard let personalContext, maximumExamples > 0 else { return [] }

        return personalContext.snippets.compactMap { snippet in
            let words = snippet.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard words.count >= minimumWords else { return nil }
            let suffixCount = min(continuationWords, words.count / 2)
            let before = words.dropLast(suffixCount).joined(separator: " ")
            let continuation = words.suffix(suffixCount).joined(separator: " ")
            guard !before.isEmpty, !continuation.isEmpty else { return nil }
            return #""\#(before)" -> "\#(continuation)""#
        }.prefix(maximumExamples).map { $0 }
    }
}
