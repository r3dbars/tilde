import AutocompleteLabCore
import Foundation

struct ClaudeCodeTerminalScreenPromptAnchorCache {
    private struct Entry {
        let hostBundleIdentifier: String
        let inputText: String
        let anchor: ClaudeCodeTerminalScreenPromptAnchor
        var recordedAt: Date
    }

    private var entry: Entry?
    private let maxAgeSeconds: TimeInterval

    init(maxAgeSeconds: TimeInterval = 8.0) {
        self.maxAgeSeconds = maxAgeSeconds
    }

    mutating func remember(
        _ anchor: ClaudeCodeTerminalScreenPromptAnchor,
        hostBundleIdentifier: String,
        now: Date = Date()
    ) {
        entry = Entry(
            hostBundleIdentifier: hostBundleIdentifier,
            inputText: anchor.inputText,
            anchor: anchor,
            recordedAt: now
        )
    }

    mutating func anchor(
        hostBundleIdentifier: String,
        inputText: String,
        now: Date = Date()
    ) -> ClaudeCodeTerminalScreenPromptAnchor? {
        guard let entry = validEntry(now: now) else {
            return nil
        }

        guard entry.hostBundleIdentifier == hostBundleIdentifier,
              Self.inputTextMatches(entry: entry, requestedInputText: inputText) else {
            return nil
        }

        touch(now: now)
        return entry.anchor
    }

    mutating func anchorForRepairedInput(
        hostBundleIdentifier: String,
        inputText: String,
        now: Date = Date()
    ) -> ClaudeCodeTerminalScreenPromptAnchor? {
        guard let entry = validEntry(now: now) else {
            return nil
        }

        guard entry.hostBundleIdentifier == hostBundleIdentifier,
              Self.inputTextMatches(entry: entry, requestedInputText: inputText)
                || Self.isPlausibleRepairedInput(inputText) else {
            return nil
        }

        touch(now: now)
        return entry.anchor
    }

    func diagnosticMetadata(
        hostBundleIdentifier: String,
        inputText: String,
        now: Date = Date()
    ) -> [String: String] {
        guard let entry else {
            return [
                "promptAnchorCacheState": "empty"
            ]
        }

        let ageMilliseconds = max(0, Int(now.timeIntervalSince(entry.recordedAt) * 1000))
        return [
            "promptAnchorCacheState": "present",
            "promptAnchorCacheAgeMilliseconds": String(ageMilliseconds),
            "promptAnchorCacheExpired": String(now.timeIntervalSince(entry.recordedAt) > maxAgeSeconds),
            "promptAnchorCacheHostMatches": String(entry.hostBundleIdentifier == hostBundleIdentifier),
            "promptAnchorCacheInputMatches": String(Self.inputTextMatches(
                entry: entry,
                requestedInputText: inputText
            )),
            "promptAnchorCacheRecoveredInputMatches": String(entry.inputText == inputText),
            "promptAnchorCacheRecoveredInputSuffixMatches": String(Self.inputTextIsSuffix(
                fullInputText: entry.inputText,
                requestedInputText: inputText
            )),
            "promptAnchorCacheRecoveredInputContainsRequest": String(Self.inputTextContains(
                fullInputText: entry.inputText,
                requestedInputText: inputText
            )),
            "promptAnchorCachePlausibleRepairedInput": String(Self.isPlausibleRepairedInput(inputText)),
            "promptAnchorCachePromptLineInputMatches": String(entry.anchor.promptLineInputText == inputText),
            "promptAnchorCacheInputChars": String(entry.inputText.count),
            "promptAnchorCachePromptLineInputChars": String(entry.anchor.promptLineInputText.count),
            "promptAnchorCacheRequestedInputChars": String(inputText.count),
            "promptAnchorCacheLineIndex": String(entry.anchor.lineIndex),
            "promptAnchorCacheLineCount": String(entry.anchor.lineCount)
        ]
    }

    private mutating func validEntry(now: Date) -> Entry? {
        guard let entry else {
            return nil
        }

        guard now.timeIntervalSince(entry.recordedAt) <= maxAgeSeconds else {
            self.entry = nil
            return nil
        }

        return entry
    }

    private mutating func touch(now: Date) {
        entry?.recordedAt = now
    }

    private static func inputTextMatches(entry: Entry, requestedInputText: String) -> Bool {
        entry.inputText == requestedInputText
            || entry.anchor.promptLineInputText == requestedInputText
            || inputTextIsSuffix(
                fullInputText: entry.inputText,
                requestedInputText: requestedInputText
            )
            || inputTextContains(
                fullInputText: entry.inputText,
                requestedInputText: requestedInputText
            )
    }

    private static func inputTextIsSuffix(
        fullInputText: String,
        requestedInputText: String
    ) -> Bool {
        let normalizedFullInput = normalizedInputText(fullInputText)
        let normalizedRequestedInput = normalizedInputText(requestedInputText)
        guard normalizedRequestedInput.split(separator: " ").count >= 3,
              normalizedRequestedInput.count >= 12,
              normalizedFullInput.count > normalizedRequestedInput.count else {
            return false
        }

        return normalizedFullInput.hasSuffix(normalizedRequestedInput)
    }

    private static func inputTextContains(
        fullInputText: String,
        requestedInputText: String
    ) -> Bool {
        let normalizedFullInput = normalizedInputText(fullInputText)
        let normalizedRequestedInput = normalizedInputText(requestedInputText)
        guard normalizedRequestedInput.split(separator: " ").count >= 3,
              normalizedRequestedInput.count >= 12,
              normalizedFullInput.count > normalizedRequestedInput.count else {
            return false
        }

        return normalizedFullInput.contains(normalizedRequestedInput)
    }

    private static func normalizedInputText(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func isPlausibleRepairedInput(_ text: String) -> Bool {
        let normalizedText = normalizedInputText(text)
        return normalizedText.count >= 12
            && normalizedText.split(separator: " ").count >= 3
    }
}
