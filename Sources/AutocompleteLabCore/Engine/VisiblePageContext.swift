import Foundation

public enum VisiblePageContextSource: String, Equatable, Sendable {
    case screenOCR = "screen_ocr"
}

public struct VisiblePageContext: Equatable, Sendable {
    public static let maximumPromptCharacters = 600
    public static let maximumPromptTokens = 90

    public let source: VisiblePageContextSource
    public let text: String

    public init?(
        source: VisiblePageContextSource = .screenOCR,
        text: String
    ) {
        let sanitized = Self.sanitizedText(text)
        guard !sanitized.isEmpty else {
            return nil
        }

        self.source = source
        self.text = sanitized
    }

    public var promptGuidance: String {
        """
        Visible page context source: \(source.rawValue). This may include OCR mistakes or nearby UI.
        Use it only to match local names, terms, headings, list style, and topic.
        Ignore buttons, menus, sidebars, and anything unrelated to the Before cursor text.
        """
    }

    public var promptText: String {
        Self.truncatedForPrompt(text)
    }

    public var traceMetadata: [String: String] {
        [
            "visiblePageContextSource": source.rawValue,
            "visiblePageContextChars": String(text.count),
            "visiblePageContextLines": String(text.split(whereSeparator: \.isNewline).count)
        ]
    }

    public static func sanitizedText(_ text: String) -> String {
        let lines = text
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .components(separatedBy: .newlines)
            .map { line in
                line
                    .split(whereSeparator: { $0.isWhitespace })
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter(Self.isUsefulLine)

        var seen = Set<String>()
        var uniqueLines: [String] = []
        for line in lines {
            let key = line.lowercased()
            guard !seen.contains(key) else {
                continue
            }

            seen.insert(key)
            uniqueLines.append(line)
        }

        return truncatedForPrompt(uniqueLines.joined(separator: "\n"))
    }

    private static func isUsefulLine(_ line: String) -> Bool {
        guard line.count >= 2 else {
            return false
        }

        let scalars = line.unicodeScalars
        let alphanumericCount = scalars.filter(CharacterSet.alphanumerics.contains).count
        guard alphanumericCount >= 2 else {
            return false
        }

        return Double(alphanumericCount) / Double(max(1, scalars.count)) >= 0.25
    }

    private static func truncatedForPrompt(_ text: String) -> String {
        let characterTrimmed = String(text.prefix(maximumPromptCharacters))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let words = characterTrimmed
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)

        guard words.count > maximumPromptTokens else {
            return characterTrimmed
        }

        return words
            .prefix(maximumPromptTokens)
            .joined(separator: " ")
    }
}
