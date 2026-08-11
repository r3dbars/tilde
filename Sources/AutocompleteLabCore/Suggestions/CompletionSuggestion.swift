import Foundation

public struct CompletionSuggestion: Equatable, Sendable {
    public static let defaultMaxVisibleWords = 8
    public static let maximumVisibleWords = 20
    public static let defaultMaxVisibleCharacters = 42

    public let text: String
    public let maxVisibleWords: Int
    public let maxVisibleCharacters: Int

    public init(
        text: String,
        maxVisibleWords: Int = Self.defaultMaxVisibleWords,
        maxVisibleCharacters: Int? = nil
    ) {
        self.maxVisibleWords = max(1, maxVisibleWords)
        self.maxVisibleCharacters = max(
            1,
            maxVisibleCharacters ?? Self.defaultMaxVisibleCharacters(forVisibleWords: self.maxVisibleWords)
        )
        self.text = Self.cappedText(
            text,
            wordLimit: self.maxVisibleWords,
            characterLimit: self.maxVisibleCharacters
        )
    }

    public var visibleText: String {
        Self.acceptedPrefix(in: text, wordLimit: maxVisibleWords)
    }

    public var visibleWordCount: Int {
        visibleText.split(whereSeparator: { $0.isWhitespace }).count
    }

    public var isEmpty: Bool {
        visibleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func cappedText(
        _ text: String,
        wordLimit: Int,
        characterLimit: Int
    ) -> String {
        let singleLineText = String(text.prefix { !$0.isNewline })
        let wordCappedText = acceptedPrefix(in: singleLineText, wordLimit: wordLimit)
        return characterCappedText(wordCappedText, characterLimit: characterLimit)
    }

    static func acceptedPrefix(in text: String, wordLimit: Int) -> String {
        guard wordLimit > 0 else {
            return ""
        }

        var accepted = ""
        var wordCount = 0
        var isInsideWord = false

        for character in text {
            if character.isWhitespace {
                if wordCount >= wordLimit {
                    break
                }

                accepted.append(character)
                isInsideWord = false
                continue
            }

            if !isInsideWord {
                if wordCount >= wordLimit {
                    break
                }

                wordCount += 1
                isInsideWord = true
            }

            accepted.append(character)
        }

        return accepted
    }

    public static func clampedVisibleWords(_ value: Int) -> Int {
        min(maximumVisibleWords, max(1, value))
    }

    public static func defaultMaxVisibleCharacters(forVisibleWords visibleWords: Int) -> Int {
        max(defaultMaxVisibleCharacters, max(1, visibleWords) * 10)
    }

    private static func characterCappedText(_ text: String, characterLimit: Int) -> String {
        guard text.count > characterLimit else {
            return text
        }

        let capped = String(text.prefix(characterLimit))
        guard let lastWhitespaceIndex = capped.lastIndex(where: { $0.isWhitespace }) else {
            return capped
        }

        let wordBoundaryCapped = String(capped[..<lastWhitespaceIndex])
        if wordBoundaryCapped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return capped
        }

        return wordBoundaryCapped
    }
}
