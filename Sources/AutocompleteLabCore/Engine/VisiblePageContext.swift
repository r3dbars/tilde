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
        Never output visible window titles, document titles, tab labels, menu labels, sidebar labels, font controls, app navigation, or other OCR chrome.
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

    public var completionCandidateWords: [String] {
        Self.completionCandidateWords(in: text)
    }

    public var traceMetadata: [String: String] {
        [
            "visiblePageContextSource": source.rawValue,
            "visiblePageContextCaptureScope": captureScope.rawValue,
            "visiblePageContextChars": String(text.count),
            "visiblePageContextLines": String(text.split(whereSeparator: \.isNewline).count),
            "visiblePageContextCompletionCandidateWords": String(completionCandidateWords.count)
        ]
    }

    public static func sanitizedText(_ text: String) -> String {
        var isInsideCodeFence = false
        let lines = promptSafeText(text)
            .components(separatedBy: .newlines)
            .compactMap { line -> String? in
                if Self.isMarkdownFenceLine(line) {
                    isInsideCodeFence.toggle()
                    return nil
                }

                guard !isInsideCodeFence,
                      !Self.looksLikePromptControlLine(line) else {
                    return nil
                }

                let cleanedLine = Self.scrubOCRChromeFragments(in: line)
                    .split(whereSeparator: { $0.isWhitespace })
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard Self.isUsefulLine(cleanedLine),
                      !Self.looksLikeOCRChromeLine(cleanedLine) else {
                    return nil
                }

                return cleanedLine
            }

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

    private static func promptSafeText(_ text: String) -> String {
        let withoutANSIEscapes = text
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .replacingOccurrences(
                of: ansiEscapePattern,
                with: " ",
                options: .regularExpression
            )

        let scalars = withoutANSIEscapes.unicodeScalars.map { scalar in
            if scalar == "\n" || scalar == "\t" {
                return scalar
            }

            guard CharacterSet.controlCharacters.contains(scalar) else {
                return scalar
            }

            return replacementScalar
        }

        return String(String.UnicodeScalarView(scalars))
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

    private static func scrubOCRChromeFragments(in line: String) -> String {
        var scrubbed = line

        for pattern in ocrChromeFragmentPatterns {
            scrubbed = scrubbed.replacingOccurrences(
                of: pattern,
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        return scrubbed
    }

    private static func isMarkdownFenceLine(_ line: String) -> Bool {
        line.range(
            of: #"^\s*(?:`{3,}|~{3,})"#,
            options: .regularExpression
        ) != nil
    }

    private static func looksLikePromptControlLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        return promptControlLinePatterns.contains { pattern in
            trimmed.range(
                of: pattern,
                options: [.regularExpression, .caseInsensitive]
            ) != nil
        }
    }

    private static func looksLikeOCRChromeLine(_ line: String) -> Bool {
        let words = normalizedWords(in: line)
        guard !words.isEmpty else {
            return true
        }

        if words[0] == "untitled" {
            return words.count == 1
                || words.dropFirst().allSatisfy { $0.allSatisfy(\.isNumber) || ocrChromeTokens.contains($0) }
        }

        guard words.count >= 2, words.count <= 5 else {
            return false
        }

        return words.allSatisfy { ocrChromeTokens.contains($0) || $0.allSatisfy(\.isNumber) }
    }

    private static func normalizedWords(in text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.lowercased() }
            .filter { !$0.isEmpty }
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

    private static func completionCandidateWords(in text: String) -> [String] {
        var seen = Set<String>()
        let words = text
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
            .filter { word in
                let normalized = word.lowercased()
                return word.count >= 4
                    && word.count <= 48
                    && !ocrChromeTokens.contains(normalized)
            }
            .filter { word in
                let normalized = word.lowercased()
                guard !seen.contains(normalized) else {
                    return false
                }

                seen.insert(normalized)
                return true
            }

        return Array(words.suffix(80))
    }

    private static let ocrChromeTokens: Set<String> = [
        "automations",
        "chat",
        "chats",
        "edited",
        "font",
        "format",
        "helvetica",
        "new",
        "plugins",
        "projects",
        "regular",
        "search",
        "settings",
        "untitled"
    ]

    private static let ocrChromeFragmentPatterns: [String] = [
        #"\bUntitled(?:\s+\d+)?\b"#,
        #"\bNew\s+chat\b"#,
        #"\bPlugins\s+Automations\s+Projects\b"#,
        #"\bSettings\s+Show\s+more\b"#,
        #"\bHelvetica\s+\d*\s*Regular(?:\s+\d+(?:\.\d+)?){0,2}\b"#,
        #"\bEp\s+[A-Za-z][A-Za-z0-9_-]{2,}\b"#
    ]

    private static let ansiEscapePattern = "\u{001B}\\[[0-?]*[ -/]*[@-~]"
    private static let replacementScalar = UnicodeScalar(" ")

    private static let promptControlLinePatterns: [String] = [
        #"^(?:system|assistant|developer|tool)\s*:"#,
        #"^(?:before cursor|after cursor|visible page context|next words|suffix)\s*:"#,
        #"^(?:inline autocomplete|inline word completion)\b"#,
        #"^(?:return only|return exactly|return the exact|return the same)\b"#,
        #"^(?:press tab|press enter|press return|submit the prompt|click send)\b"#,
        #"^\$\s+\S+"#
    ]
}
