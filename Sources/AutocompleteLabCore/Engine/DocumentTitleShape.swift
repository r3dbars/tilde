import Foundation

public struct DocumentTitleShape: Equatable, Sendable {
    public enum LengthBucket: String, Equatable, Sendable {
        case short
        case medium
        case long
    }

    public let wordCount: Int
    public let lengthBucket: LengthBucket
    public let fileExtension: String?
    public let isUntitled: Bool
    public let hasUnsavedMarker: Bool

    public init(
        wordCount: Int,
        lengthBucket: LengthBucket,
        fileExtension: String? = nil,
        isUntitled: Bool = false,
        hasUnsavedMarker: Bool = false
    ) {
        self.wordCount = max(0, wordCount)
        self.lengthBucket = lengthBucket
        self.fileExtension = fileExtension
        self.isUntitled = isUntitled
        self.hasUnsavedMarker = hasUnsavedMarker
    }

    public static func from(windowTitle: String?) -> DocumentTitleShape? {
        guard let rawTitle = windowTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawTitle.isEmpty else {
            return nil
        }

        let normalized = rawTitle.lowercased()
        let wordCount = rawTitle
            .split { !$0.isLetter && !$0.isNumber }
            .count
        let lengthBucket: LengthBucket
        switch rawTitle.count {
        case 0...32:
            lengthBucket = .short
        case 33...96:
            lengthBucket = .medium
        default:
            lengthBucket = .long
        }

        return DocumentTitleShape(
            wordCount: wordCount,
            lengthBucket: lengthBucket,
            fileExtension: fileExtension(in: rawTitle),
            isUntitled: normalized.hasPrefix("untitled"),
            hasUnsavedMarker: rawTitle.contains("*") || normalized.contains("edited")
        )
    }

    public var promptGuidance: String {
        var parts = [
            "Document/window title shape: \(lengthBucket.rawValue) title",
            "\(wordCount) \(wordCount == 1 ? "word" : "words")"
        ]

        if let fileExtension {
            parts.append("file extension \(fileExtension)")
        }
        if isUntitled {
            parts.append("untitled document")
        }
        if hasUnsavedMarker {
            parts.append("unsaved marker present")
        }

        return parts.joined(separator: ", ") + ". Use only as weak genre context; never repeat the title text."
    }

    public var traceMetadata: [String: String] {
        var metadata = [
            "documentTitleWordCount": String(wordCount),
            "documentTitleLengthBucket": lengthBucket.rawValue,
            "documentTitleIsUntitled": String(isUntitled),
            "documentTitleHasUnsavedMarker": String(hasUnsavedMarker)
        ]

        if let fileExtension {
            metadata["documentTitleExtension"] = fileExtension
        }

        return metadata
    }

    private static func fileExtension(in title: String) -> String? {
        for rawToken in title.split(whereSeparator: \.isWhitespace).reversed() {
            let token = rawToken
                .trimmingCharacters(in: CharacterSet(charactersIn: "[](){}<>\"'`,;:"))
            guard let dotIndex = token.lastIndex(of: ".") else {
                continue
            }

            let suffix = token[token.index(after: dotIndex)...]
                .lowercased()
                .filter { $0.isLetter || $0.isNumber }
            guard (1...8).contains(suffix.count) else {
                continue
            }

            return String(suffix)
        }

        return nil
    }
}
