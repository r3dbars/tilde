import Foundation

public enum CurrentLineStructureKind: String, Equatable, Sendable {
    case bullet
    case numbered
    case checklistUnchecked = "checklist_unchecked"
    case checklistChecked = "checklist_checked"
}

public enum CurrentLineMarkerStyle: String, Equatable, Sendable {
    case dash
    case asterisk
    case plus
    case numberedDot = "numbered_dot"
    case numberedParen = "numbered_paren"
    case bareCheckbox = "bare_checkbox"
}

public struct CurrentLineStructure: Equatable, Sendable {
    public let kind: CurrentLineStructureKind
    public let markerStyle: CurrentLineMarkerStyle
    public let indentationColumns: Int
    public let contentWordCount: Int

    public init(
        kind: CurrentLineStructureKind,
        markerStyle: CurrentLineMarkerStyle,
        indentationColumns: Int,
        contentWordCount: Int
    ) {
        self.kind = kind
        self.markerStyle = markerStyle
        self.indentationColumns = max(0, indentationColumns)
        self.contentWordCount = max(0, contentWordCount)
    }

    public var isListLike: Bool {
        true
    }

    public var traceMetadata: [String: String] {
        [
            "currentLineStructure": kind.rawValue,
            "currentLineMarkerStyle": markerStyle.rawValue,
            "currentLineIndentationColumns": String(indentationColumns),
            "currentLineContentWords": String(contentWordCount)
        ]
    }

    public var promptGuidance: String {
        let itemName: String
        switch kind {
        case .bullet:
            itemName = "bullet item"
        case .numbered:
            itemName = "numbered item"
        case .checklistUnchecked:
            itemName = "unchecked checklist item"
        case .checklistChecked:
            itemName = "checked checklist item"
        }

        return "Current line shape: \(itemName), marker style \(markerStyle.rawValue), indentation \(indentationColumns) columns, \(contentWordCount) content words. Preserve this list shape, return only the continuation after the cursor, and do not repeat the marker or checkbox."
    }

    public static func from(textBeforeCursor: String) -> CurrentLineStructure? {
        let currentLine = textBeforeCursor
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .last
            .map(String.init) ?? ""
        let indentationColumns = leadingIndentationColumns(in: currentLine)
        let trimmedLine = currentLine.trimmingCharacters(in: .whitespaces)

        guard !trimmedLine.isEmpty else {
            return nil
        }

        if let parsed = parseBulletMarker(in: trimmedLine, indentationColumns: indentationColumns) {
            return parsed
        }

        if let parsed = parseNumberedMarker(in: trimmedLine, indentationColumns: indentationColumns) {
            return parsed
        }

        if let parsed = parseBareCheckbox(in: trimmedLine, indentationColumns: indentationColumns) {
            return parsed
        }

        return nil
    }

    private static func parseBulletMarker(
        in trimmedLine: String,
        indentationColumns: Int
    ) -> CurrentLineStructure? {
        guard let marker = trimmedLine.first,
              let markerStyle = bulletMarkerStyle(for: marker),
              isMarkerBoundary(trimmedLine.dropFirst().first) else {
            return nil
        }

        let remainder = trimmedLine
            .dropFirst()
            .drop(while: \.isWhitespace)
        if let checkbox = parseCheckboxPrefix(in: remainder) {
            return CurrentLineStructure(
                kind: checkbox.kind,
                markerStyle: markerStyle,
                indentationColumns: indentationColumns,
                contentWordCount: contentWordCount(in: checkbox.content)
            )
        }

        return CurrentLineStructure(
            kind: .bullet,
            markerStyle: markerStyle,
            indentationColumns: indentationColumns,
            contentWordCount: contentWordCount(in: remainder)
        )
    }

    private static func parseNumberedMarker(
        in trimmedLine: String,
        indentationColumns: Int
    ) -> CurrentLineStructure? {
        let digits = trimmedLine.prefix(while: \.isNumber)
        guard !digits.isEmpty,
              let marker = trimmedLine.dropFirst(digits.count).first,
              marker == "." || marker == ")",
              isMarkerBoundary(trimmedLine.dropFirst(digits.count + 1).first) else {
            return nil
        }

        let markerStyle: CurrentLineMarkerStyle = marker == "." ? .numberedDot : .numberedParen
        let remainder = trimmedLine
            .dropFirst(digits.count + 1)
            .drop(while: \.isWhitespace)
        if let checkbox = parseCheckboxPrefix(in: remainder) {
            return CurrentLineStructure(
                kind: checkbox.kind,
                markerStyle: markerStyle,
                indentationColumns: indentationColumns,
                contentWordCount: contentWordCount(in: checkbox.content)
            )
        }

        return CurrentLineStructure(
            kind: .numbered,
            markerStyle: markerStyle,
            indentationColumns: indentationColumns,
            contentWordCount: contentWordCount(in: remainder)
        )
    }

    private static func parseBareCheckbox(
        in trimmedLine: String,
        indentationColumns: Int
    ) -> CurrentLineStructure? {
        guard let checkbox = parseCheckboxPrefix(in: trimmedLine[...]) else {
            return nil
        }

        return CurrentLineStructure(
            kind: checkbox.kind,
            markerStyle: .bareCheckbox,
            indentationColumns: indentationColumns,
            contentWordCount: contentWordCount(in: checkbox.content)
        )
    }

    private static func parseCheckboxPrefix(
        in text: Substring
    ) -> (kind: CurrentLineStructureKind, content: Substring)? {
        guard text.count >= 3,
              text.first == "[",
              let state = text.dropFirst().first,
              text.dropFirst(2).first == "]",
              isMarkerBoundary(text.dropFirst(3).first) else {
            return nil
        }

        let kind: CurrentLineStructureKind
        switch state {
        case " ":
            kind = .checklistUnchecked
        case "x", "X":
            kind = .checklistChecked
        default:
            return nil
        }

        return (
            kind,
            text
                .dropFirst(3)
                .drop(while: \.isWhitespace)
        )
    }

    private static func bulletMarkerStyle(for marker: Character) -> CurrentLineMarkerStyle? {
        switch marker {
        case "-":
            return .dash
        case "*":
            return .asterisk
        case "+":
            return .plus
        default:
            return nil
        }
    }

    private static func isMarkerBoundary(_ character: Character?) -> Bool {
        character == nil || character?.isWhitespace == true
    }

    private static func leadingIndentationColumns(in text: String) -> Int {
        text.prefix(while: \.isWhitespace).reduce(0) { total, character in
            character == "\t" ? total + 4 : total + 1
        }
    }

    private static func contentWordCount(in text: Substring) -> Int {
        text
            .split(whereSeparator: \.isWhitespace)
            .map { token in
                token.trimmingCharacters(in: .punctuationCharacters)
            }
            .filter { token in
                token.contains(where: \.isLetter)
            }
            .count
    }
}
