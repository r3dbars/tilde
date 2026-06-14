import Foundation
import AutocompleteLabCore

struct PersonalCaptureJournalContext: Equatable, Sendable {
    let appDisplayName: String
    let appBundleIdentifier: String
    let fieldIdentity: String
    let fieldKind: AXFieldKind
    let fieldKindReason: String
    let source: String
}

final class PersonalCaptureJournalWriter: @unchecked Sendable {
    static let shared = PersonalCaptureJournalWriter(
        folderURL: FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/SteadyType/Personal Capture")
    )

    private let folderURL: URL
    private let queue = DispatchQueue(label: "app.steadytype.personal-capture-journal")
    private let calendar: Calendar
    private let now: () -> Date

    init(
        folderURL: URL,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.folderURL = folderURL
        self.calendar = calendar
        self.now = now
    }

    var folderPath: String {
        folderURL.path
    }

    func recordSnapshotChange(
        previous: FocusedTextSnapshot?,
        current: FocusedTextSnapshot,
        context: PersonalCaptureJournalContext
    ) {
        let date = now()
        guard let previous,
              previous.fieldIdentity == current.fieldIdentity else {
            append(
                """
                ## \(Self.timeString(from: date, calendar: calendar)) - \(context.appDisplayName)

                Field observed for personal capture. New writing will be logged after this point.

                - App: `\(context.appBundleIdentifier)`
                - Field: `\(context.fieldIdentity)`
                - Kind: `\(context.fieldKind.rawValue)`
                - Source: `\(context.source)`

                """,
                at: date
            )
            return
        }

        guard let diff = Self.textDiff(
            previous: previous.textBeforeCursor + previous.textAfterCursor,
            current: current.textBeforeCursor + current.textAfterCursor
        ) else {
            return
        }

        let changeLabel = diff.deletedCharacterCount > 0
            ? "typed or replaced"
            : "typed"
        append(
            """
            ## \(Self.timeString(from: date, calendar: calendar)) - \(context.appDisplayName)

            \(changeLabel):

            \(Self.fencedCodeBlock(diff.insertedText))

            - App: `\(context.appBundleIdentifier)`
            - Field: `\(context.fieldIdentity)`
            - Kind: `\(context.fieldKind.rawValue)` (`\(context.fieldKindReason)`)
            - Deleted chars: \(diff.deletedCharacterCount)
            - Source: `\(context.source)`

            """,
            at: date
        )
    }

    func recordAcceptedSuggestion(
        acceptedText: String,
        context: PersonalCaptureJournalContext,
        suggestionID: String,
        acceptanceID: String,
        acceptMode: String
    ) {
        let date = now()
        append(
            """
            ## \(Self.timeString(from: date, calendar: calendar)) - SteadyType accepted

            Accepted suggestion:

            \(Self.fencedCodeBlock(acceptedText))

            - App: `\(context.appBundleIdentifier)`
            - Field: `\(context.fieldIdentity)`
            - Kind: `\(context.fieldKind.rawValue)`
            - Accept mode: `\(acceptMode)`
            - Acceptance ID: `\(acceptanceID)`
            - Suggestion ID: `\(suggestionID)`

            """,
            at: date
        )
    }

    func recordAcceptanceSurvival(
        acceptedText: String,
        context: PersonalCaptureJournalContext,
        suggestionID: String,
        acceptanceID: String,
        acceptMode: String,
        checkpoint: String,
        survivalClass: String,
        isStrongPositive: Bool
    ) {
        let date = now()
        append(
            """
            ## \(Self.timeString(from: date, calendar: calendar)) - SteadyType \(isStrongPositive ? "five-star" : "survival") signal

            Accepted text:

            \(Self.fencedCodeBlock(acceptedText))

            - App: `\(context.appBundleIdentifier)`
            - Field: `\(context.fieldIdentity)`
            - Kind: `\(context.fieldKind.rawValue)`
            - Accept mode: `\(acceptMode)`
            - Checkpoint: `\(checkpoint)`
            - Survival: `\(survivalClass)`
            - Acceptance ID: `\(acceptanceID)`
            - Suggestion ID: `\(suggestionID)`

            """,
            at: date
        )
    }

    func deleteAll() {
        queue.sync {
            try? FileManager.default.removeItem(at: folderURL)
        }
    }

    func waitForPendingWrites() {
        queue.sync {}
    }

    private func append(_ markdown: String, at date: Date) {
        queue.async { [folderURL, calendar] in
            do {
                // The Personal Capture journal is verbatim typed text — keep it owner-only
                // (0700 dir / 0600 file). See docs/security/threat-model.md (F2).
                SecureLocalStorage.createDirectory(at: folderURL)
                let fileURL = Self.fileURL(folderURL: folderURL, date: date, calendar: calendar)
                let header = Self.header(for: date, calendar: calendar)
                SecureLocalStorage.ensureFile(at: fileURL, seededWith: Data(header.utf8))

                let handle = try FileHandle(forWritingTo: fileURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(markdown.utf8))
                try handle.close()
            } catch {
                DiagnosticsLog.shared.record(
                    "personal-capture-write-failed",
                    metadata: ["reason": DiagnosticValueRedactor.stringSummary(length: String(describing: error).count)]
                )
            }
        }
    }

    static func fileURL(folderURL: URL, date: Date, calendar: Calendar) -> URL {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let fileName = String(
            format: "%04d-%02d-%02d.md",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
        return folderURL.appendingPathComponent(fileName)
    }

    private static func header(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let dateString = String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
        return """
        # SteadyType Personal Capture - \(dateString)

        Local Justin dogfood journal. This is not telemetry, not a beta default, and not included in privacy bundles.

        """
    }

    private static func timeString(from date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        return String(
            format: "%02d:%02d:%02d",
            components.hour ?? 0,
            components.minute ?? 0,
            components.second ?? 0
        )
    }

    private static func textDiff(previous: String, current: String) -> TextDiff? {
        guard previous != current else {
            return nil
        }

        let previousCharacters = Array(previous)
        let currentCharacters = Array(current)
        var prefixCount = 0
        let sharedPrefixLimit = min(previousCharacters.count, currentCharacters.count)
        while prefixCount < sharedPrefixLimit,
              previousCharacters[prefixCount] == currentCharacters[prefixCount] {
            prefixCount += 1
        }

        var previousSuffixIndex = previousCharacters.count
        var currentSuffixIndex = currentCharacters.count
        while previousSuffixIndex > prefixCount,
              currentSuffixIndex > prefixCount,
              previousCharacters[previousSuffixIndex - 1] == currentCharacters[currentSuffixIndex - 1] {
            previousSuffixIndex -= 1
            currentSuffixIndex -= 1
        }

        let insertedCharacters = currentCharacters[prefixCount..<currentSuffixIndex]
        guard !insertedCharacters.isEmpty else {
            return nil
        }

        return TextDiff(
            insertedText: String(insertedCharacters),
            deletedCharacterCount: max(0, previousSuffixIndex - prefixCount)
        )
    }

    private static func fencedCodeBlock(_ text: String) -> String {
        let fence = String(repeating: "`", count: max(3, longestBacktickRun(in: text) + 1))
        return "\(fence)text\n\(text)\n\(fence)"
    }

    private static func longestBacktickRun(in text: String) -> Int {
        var longest = 0
        var current = 0
        for character in text {
            if character == "`" {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
        }
        return longest
    }
}

private struct TextDiff: Equatable {
    let insertedText: String
    let deletedCharacterCount: Int
}
