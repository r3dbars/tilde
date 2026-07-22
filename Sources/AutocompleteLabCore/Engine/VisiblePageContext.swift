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
    public let activeTextLineFiltered: Bool
    public let text: String

    public init?(
        source: VisiblePageContextSource = .screenOCR,
        captureScope: VisiblePageContextCaptureScope = .visibleScreen,
        activeApplicationName: String? = nil,
        excludingActiveTextLine activeTextLine: String? = nil,
        text: String
    ) {
        let sanitized = Self.sanitizedTextResult(
            text,
            excludingActiveTextLine: activeTextLine
        )
        guard !sanitized.isEmpty else {
            return nil
        }

        self.source = source
        self.captureScope = captureScope
        self.activeApplicationName = Self.sanitizedAppName(activeApplicationName)
        self.activeTextLineFiltered = sanitized.activeTextLineFiltered
        self.text = sanitized.text
    }

    public var promptGuidance: String {
        """
        Visible page context source: \(source.rawValue), scope: \(captureScope.rawValue). This is a noisy OCR snapshot of what is VISIBLE on the user's screen right now — it is not text the user wrote, and never text to continue.
        Its relationship to the typing is unknown — infer it from content: it may be a message, email, or comment the user is REPLYING to; an article or document they are reading and reacting to; their own earlier writing scrolled above the cursor; or unrelated windows and UI.
        If it reads like a received message or question, treat the typing as a reply to it and let the reply address it. If it reads like source material, treat the typing as notes or commentary about it. If it matches the typed text's topic and voice, treat it as the user's own earlier writing and stay consistent with it.
        Use it for grounding: the active app and its register, the topic at hand, names, project terms, repeated vocabulary, headings, and list style — and prefer a useful best guess when it strongly implies the user's next words.
        Only ever continue the "Before cursor" text. Never quote, copy, or continue the visible context itself; never output window titles, tab labels, buttons, menus, timestamps, or other OCR chrome; expect OCR misreadings and silently correct them.
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
            "visiblePageContextCompletionCandidateWords": String(completionCandidateWords.count),
            "visiblePageContextActiveLineFiltered": String(activeTextLineFiltered)
        ]
    }

    public static func sanitizedText(_ text: String) -> String {
        sanitizedTextResult(text, excludingActiveTextLine: nil).text
    }

    public static func sanitizedText(_ text: String, excludingActiveTextLine activeTextLine: String?) -> String {
        sanitizedTextResult(text, excludingActiveTextLine: activeTextLine).text
    }

    private static func sanitizedTextResult(
        _ text: String,
        excludingActiveTextLine activeTextLine: String?
    ) -> SanitizedTextResult {
        let normalizedActiveLine = normalizedActiveLine(activeTextLine)
        var activeTextLineFiltered = false
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
            .filter { line in
                if Self.shouldFilterActiveTextLine(line, normalizedActiveLine: normalizedActiveLine) {
                    activeTextLineFiltered = true
                    return false
                }

                return true
            }
            .filter(Self.isUsefulLine)
            .filter { !Self.looksLikeOCRChromeLine($0) }

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

        return SanitizedTextResult(
            text: truncatedForPrompt(uniqueLines.joined(separator: "\n")),
            activeTextLineFiltered: activeTextLineFiltered
        )
    }

    private struct SanitizedTextResult {
        let text: String
        let activeTextLineFiltered: Bool

        var isEmpty: Bool {
            text.isEmpty
        }
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

    private static func normalizedActiveLine(_ activeTextLine: String?) -> String? {
        guard let activeTextLine else {
            return nil
        }

        let normalized = normalizedForActiveLineFilter(activeTextLine)
        guard normalized.count >= 6 else {
            return nil
        }

        return normalized
    }

    private static func shouldFilterActiveTextLine(
        _ line: String,
        normalizedActiveLine: String?
    ) -> Bool {
        guard let normalizedActiveLine else {
            return false
        }

        let normalizedLine = normalizedForActiveLineFilter(line)
        guard normalizedLine.count >= 4 else {
            return false
        }

        if normalizedLine == normalizedActiveLine {
            return true
        }
        if normalizedLine.contains(normalizedActiveLine) {
            return true
        }
        if normalizedLine.count >= 6, normalizedActiveLine.contains(normalizedLine) {
            return true
        }

        let prefixLength = min(24, normalizedActiveLine.count)
        if prefixLength >= 8 {
            let prefix = String(normalizedActiveLine.prefix(prefixLength))
            return normalizedLine.contains(prefix)
        }

        return false
    }

    private static func normalizedForActiveLineFilter(_ text: String) -> String {
        let transformed = text.applyingTransform(.toLatin, reverse: false) ?? text
        let folded = transformed.folding(
            options: [.diacriticInsensitive, .widthInsensitive],
            locale: .current
        )
        let lowered = folded.lowercased()
        let filtered = lowered.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            }

            return " "
        }

        return String(filtered)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
