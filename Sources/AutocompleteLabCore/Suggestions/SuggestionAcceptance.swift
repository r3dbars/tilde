import Foundation

public extension CompletionSuggestion {
    func acceptedPrefix(wordLimit: Int) -> String {
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
}
