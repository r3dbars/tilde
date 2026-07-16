import Foundation
import AutocompleteLabCore

public struct RecentWordExtractor: Equatable, Sendable {
    public let minimumWordLength: Int

    public init(minimumWordLength: Int = 3) {
        self.minimumWordLength = max(1, minimumWordLength)
    }

    public func words(in text: String) -> [String] {
        text
            .split(whereSeparator: { !$0.isLetter })
            .map { String($0).lowercased() }
            .filter { $0.count >= minimumWordLength }
    }

    public func completedWords(
        previousTextBeforeCursor: String,
        currentTextBeforeCursor: String
    ) -> [String] {
        guard currentTextBeforeCursor.count > previousTextBeforeCursor.count,
              currentTextBeforeCursor.hasPrefix(previousTextBeforeCursor),
              let lastCharacter = currentTextBeforeCursor.last,
              !lastCharacter.isLetter else {
            return []
        }

        let textBeforeBoundary = currentTextBeforeCursor.dropLast()
        guard let word = textBeforeBoundary.split(whereSeparator: { !$0.isLetter }).last else {
            return []
        }

        let normalizedWord = String(word).lowercased()
        guard normalizedWord.count >= minimumWordLength else {
            return []
        }

        return [normalizedWord]
    }
}
