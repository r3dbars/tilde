import Foundation

public enum VisiblePageContextSource: String, Equatable, Sendable {
    case screenOCR = "screen_ocr"
}

public enum VisiblePageContextCaptureScope: String, Equatable, Sendable {
    case focusedRegion = "focused_region"
    case visibleScreen = "visible_screen"
}

public struct VisiblePageContext: Equatable, Sendable {
    public static let maximumPromptCharacters = 1_000
    public static let maximumPromptTokens = 150

    public let source: VisiblePageContextSource
    public let captureScope: VisiblePageContextCaptureScope
    public let activeApplicationName: String?
    public let text: String

    public init?(
        source: VisiblePageContextSource = .screenOCR,
        captureScope: VisiblePageContextCaptureScope = .visibleScreen,
        activeApplicationName: String? = nil,
        text: String
    ) {
        let sanitized = Self.sanitizedText(text)
        guard !sanitized.isEmpty else {
            return nil
        }

        self.source = source
        self.captureScope = captureScope
        self.activeApplicationName = Self.sanitizedAppName(activeApplicationName)
        self.text = sanitized
    }

    public var promptGuidance: String {
        """
        Visible page context source: \(source.rawValue), scope: \(captureScope.rawValue). This may include OCR mistakes, nearby UI, or other visible app text.
        Use it to infer the active app, local topic, what the user is replying to, names, repeated terms, headings, list style, and the next words the user is likely trying to type.
        Act like a local writing companion that can see the screen but still only types the user's next words.
        Prefer a useful best guess when the visible context strongly implies the next word or short phrase.
        Ignore buttons, menus, sidebars, and anything unrelated to the active text field.
        """
    }

    public var promptText: String {
        var pieces: [String] = []
        if let activeApplicationName {
            pieces.append("Active app: \(activeApplicationName)")
        }
        pieces.append("OCR scope: \(captureScope.rawValue)")
        pieces.append(Self.truncatedForPrompt(text))
        return pieces.joined(separator: "\n")
    }

    public var traceMetadata: [String: String] {
        [
            "visiblePageContextSource": source.rawValue,
            "visiblePageContextCaptureScope": captureScope.rawValue,
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

    private static func sanitizedAppName(_ appName: String?) -> String? {
        guard let appName else {
            return nil
        }

        let sanitized = appName
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !sanitized.isEmpty else {
            return nil
        }

        return String(sanitized.prefix(80))
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
