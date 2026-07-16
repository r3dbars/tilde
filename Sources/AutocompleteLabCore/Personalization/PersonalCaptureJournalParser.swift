import Foundation

public struct PersonalCaptureJournalEntry: Equatable, Sendable {
    public enum Kind: String, Codable, Equatable, Sendable {
        case typed
        case accepted
        case survival
        case fieldObserved
    }

    public let kind: Kind
    public let timeString: String
    public let appBundleIdentifier: String
    public let fieldKind: AXFieldKind
    public let text: String
    public let deletedCharacterCount: Int
    public let dayString: String

    public init(
        kind: Kind,
        timeString: String,
        appBundleIdentifier: String,
        fieldKind: AXFieldKind,
        text: String,
        deletedCharacterCount: Int = 0,
        dayString: String
    ) {
        self.kind = kind
        self.timeString = timeString
        self.appBundleIdentifier = appBundleIdentifier
        self.fieldKind = fieldKind
        self.text = text
        self.deletedCharacterCount = max(0, deletedCharacterCount)
        self.dayString = dayString
    }
}

public struct PersonalCaptureJournalParser: Equatable, Sendable {
    public init() {}

    public func entries(inDailyMarkdown markdown: String, dayString: String) -> [PersonalCaptureJournalEntry] {
        let lines = markdown.components(separatedBy: .newlines)
        let sectionStarts = lines.indices.filter { lines[$0].hasPrefix("## ") }
        return sectionStarts.enumerated().compactMap { offset, start in
            let end = offset + 1 < sectionStarts.count ? sectionStarts[offset + 1] : lines.endIndex
            return parseSection(Array(lines[start..<end]), dayString: dayString)
        }
    }

    private func parseSection(_ lines: [String], dayString: String) -> PersonalCaptureJournalEntry? {
        guard let header = lines.first,
              header.count >= 11 else {
            return nil
        }
        let timeStart = header.index(header.startIndex, offsetBy: 3)
        let timeEnd = header.index(timeStart, offsetBy: 8, limitedBy: header.endIndex) ?? header.endIndex
        let timeString = String(header[timeStart..<timeEnd])
        guard timeString.range(of: #"^\d{2}:\d{2}:\d{2}$"#, options: .regularExpression) != nil,
              let app = metadataValue(named: "App", in: lines),
              let kindText = metadataValue(named: "Kind", in: lines),
              let fieldKindRaw = kindText.split(whereSeparator: { $0.isWhitespace }).first,
              // Fail closed when the persisted classification is unknown. Treating it as a
              // compose field would let unclassified private text enter personalization.
              let fieldKind = AXFieldKind(rawValue: String(fieldKindRaw).trimmingCharacters(in: CharacterSet(charactersIn: "`"))) else {
            return nil
        }

        let kind: PersonalCaptureJournalEntry.Kind
        if lines.contains(where: { $0 == "Accepted suggestion:" }) {
            kind = .accepted
        } else if lines.contains(where: { $0 == "Accepted text:" }) {
            kind = .survival
        } else if lines.contains(where: { $0.contains("Field observed for personal capture") }) {
            kind = .fieldObserved
        } else if lines.contains(where: { $0 == "typed:" || $0 == "typed or replaced:" }) {
            kind = .typed
        } else {
            return nil
        }

        let text: String
        if kind == .fieldObserved {
            text = ""
        } else if let fencedText = fencedText(in: lines) {
            text = fencedText
        } else {
            return nil
        }

        return PersonalCaptureJournalEntry(
            kind: kind,
            timeString: timeString,
            appBundleIdentifier: app,
            fieldKind: fieldKind,
            text: text,
            deletedCharacterCount: Int(metadataValue(named: "Deleted chars", in: lines) ?? "") ?? 0,
            dayString: dayString
        )
    }

    private func metadataValue(named name: String, in lines: [String]) -> String? {
        let prefix = "- \(name):"
        guard let line = lines.first(where: { $0.hasPrefix(prefix) }) else {
            return nil
        }
        var value = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("`") && value.hasSuffix("`") && value.count >= 2 {
            value.removeFirst()
            value.removeLast()
        }
        return value
    }

    private func fencedText(in lines: [String]) -> String? {
        for openingIndex in lines.indices {
            let opening = lines[openingIndex]
            let fenceLength = opening.prefix(while: { $0 == "`" }).count
            guard fenceLength >= 3,
                  opening.dropFirst(fenceLength) == "text" else {
                continue
            }
            let fence = String(repeating: "`", count: fenceLength)
            guard let closingIndex = lines.indices.dropFirst(openingIndex + 1).first(where: { lines[$0] == fence }) else {
                return nil
            }
            return lines[(openingIndex + 1)..<closingIndex].joined(separator: "\n")
        }
        return nil
    }
}
