import Foundation

public enum PartialWordCasing: String, Equatable, Sendable {
    case lowercase
    case uppercase
    case titlecase
    case mixed
    case none
}

public struct PartialWordShape: Equatable, Sendable {
    public let characterCount: Int
    public let letterCount: Int
    public let digitCount: Int
    public let casing: PartialWordCasing
    public let hasHyphen: Bool
    public let hasApostrophe: Bool

    public init(
        characterCount: Int,
        letterCount: Int,
        digitCount: Int,
        casing: PartialWordCasing,
        hasHyphen: Bool,
        hasApostrophe: Bool
    ) {
        self.characterCount = max(0, characterCount)
        self.letterCount = max(0, letterCount)
        self.digitCount = max(0, digitCount)
        self.casing = casing
        self.hasHyphen = hasHyphen
        self.hasApostrophe = hasApostrophe
    }

    public var traceMetadata: [String: String] {
        [
            "partialWordCharacters": String(characterCount),
            "partialWordLetters": String(letterCount),
            "partialWordDigits": String(digitCount),
            "partialWordCasing": casing.rawValue,
            "partialWordHasHyphen": String(hasHyphen),
            "partialWordHasApostrophe": String(hasApostrophe)
        ]
    }

    public var promptGuidance: String {
        var parts = [
            "\(characterCount) \(characterCount == 1 ? "character" : "characters")",
            "\(letterCount) \(letterCount == 1 ? "letter" : "letters")",
            "\(digitCount) \(digitCount == 1 ? "digit" : "digits")",
            "\(casing.rawValue) casing"
        ]
        if hasHyphen {
            parts.append("has hyphen")
        }
        if hasApostrophe {
            parts.append("has apostrophe")
        }
        return "Partial word shape: \(parts.joined(separator: ", "))."
    }

    public static func from(textBeforeCursor: String) -> PartialWordShape? {
        guard textBeforeCursor.last?.isWhitespace == false else {
            return nil
        }

        guard let rawFragment = textBeforeCursor
            .split(whereSeparator: { $0.isWhitespace })
            .last else {
            return nil
        }

        guard rawFragment.last?.isLetterOrNumber == true else {
            return nil
        }

        let fragment = String(rawFragment).trimmingCharacters(in: .punctuationCharacters)
        guard !fragment.isEmpty else {
            return nil
        }

        let letters = Array(fragment.filter(\.isLetter))
        let digitCount = fragment.filter(\.isNumber).count
        guard !letters.isEmpty else {
            return nil
        }

        return PartialWordShape(
            characterCount: fragment.count,
            letterCount: letters.count,
            digitCount: digitCount,
            casing: casing(for: letters),
            hasHyphen: fragment.contains("-"),
            hasApostrophe: fragment.contains("'") || fragment.contains("’")
        )
    }

    private static func casing(for letters: [Character]) -> PartialWordCasing {
        guard !letters.isEmpty else {
            return .none
        }

        if letters.allSatisfy(\.isLowercase) {
            return .lowercase
        }

        if letters.allSatisfy(\.isUppercase) {
            return .uppercase
        }

        if let first = letters.first,
           first.isUppercase,
           letters.dropFirst().allSatisfy(\.isLowercase) {
            return .titlecase
        }

        return .mixed
    }
}

private extension Character {
    var isLetterOrNumber: Bool {
        isLetter || isNumber
    }
}
