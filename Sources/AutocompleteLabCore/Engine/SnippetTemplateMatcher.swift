import Foundation

public struct SnippetTemplate: Codable, Equatable, Sendable {
    public let id: String
    public let trigger: String
    public let replacement: String
    public let allowedBundleIdentifiers: [String]
    public let isEnabled: Bool

    public init(
        id: String,
        trigger: String,
        replacement: String,
        allowedBundleIdentifiers: [String],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.trigger = trigger
        self.replacement = replacement
        self.allowedBundleIdentifiers = allowedBundleIdentifiers
        self.isEnabled = isEnabled
    }
}

public struct SnippetTemplateMatch: Equatable, Sendable {
    public let template: SnippetTemplate
    public let triggerUTF16Location: Int
    public let triggerUTF16Length: Int

    public init(
        template: SnippetTemplate,
        triggerUTF16Location: Int,
        triggerUTF16Length: Int
    ) {
        self.template = template
        self.triggerUTF16Location = max(0, triggerUTF16Location)
        self.triggerUTF16Length = max(0, triggerUTF16Length)
    }

    public var visibleText: String {
        template.replacement
    }

    public var traceMetadata: [String: String] {
        [
            "snippetTriggerChars": String(template.trigger.count),
            "snippetReplacementChars": String(template.replacement.count),
            "snippetAllowedAppCount": String(template.allowedBundleIdentifiers.count),
            "snippetTriggerUTF16Length": String(triggerUTF16Length),
            "snippetTriggerUTF16Location": String(triggerUTF16Location)
        ]
    }
}

public struct SnippetTemplateMatcher: Equatable, Sendable {
    public let maxTriggerLength: Int
    public let maxReplacementLength: Int

    public init(
        maxTriggerLength: Int = 24,
        maxReplacementLength: Int = 160
    ) {
        self.maxTriggerLength = max(2, maxTriggerLength)
        self.maxReplacementLength = max(1, maxReplacementLength)
    }

    public func match(
        textBeforeCursor: String,
        appBundleIdentifier: String,
        templates: [SnippetTemplate]
    ) -> SnippetTemplateMatch? {
        let app = normalizedApp(appBundleIdentifier)
        guard !app.isEmpty else {
            return nil
        }

        return templates
            .filter { isUsable($0, appBundleIdentifier: app) }
            .compactMap { template -> SnippetTemplateMatch? in
                guard textBeforeCursor.hasSuffix(template.trigger),
                      hasTriggerBoundary(
                          textBeforeCursor: textBeforeCursor,
                          trigger: template.trigger
                      ) else {
                    return nil
                }

                return SnippetTemplateMatch(
                    template: template,
                    triggerUTF16Location: textBeforeCursor.utf16.count - template.trigger.utf16.count,
                    triggerUTF16Length: template.trigger.utf16.count
                )
            }
            .sorted {
                if $0.template.trigger.count != $1.template.trigger.count {
                    return $0.template.trigger.count > $1.template.trigger.count
                }

                return $0.template.id < $1.template.id
            }
            .first
    }

    private func isUsable(_ template: SnippetTemplate, appBundleIdentifier: String) -> Bool {
        guard template.isEnabled,
              isSafeTrigger(template.trigger),
              isSafeReplacement(template.replacement) else {
            return false
        }

        return template.allowedBundleIdentifiers
            .map(normalizedApp)
            .contains(appBundleIdentifier)
    }

    private func isSafeTrigger(_ trigger: String) -> Bool {
        guard trigger.hasPrefix(";"),
              trigger.count <= maxTriggerLength else {
            return false
        }

        let suffix = trigger.dropFirst()
        return !suffix.isEmpty && suffix.allSatisfy { character in
            character.isLetter || character.isNumber || character == "-" || character == "_"
        }
    }

    private func isSafeReplacement(_ replacement: String) -> Bool {
        let trimmed = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              replacement.count <= maxReplacementLength else {
            return false
        }

        return replacement.allSatisfy { character in
            !character.isNewline && !character.isASCIIControl
        }
    }

    private func hasTriggerBoundary(textBeforeCursor: String, trigger: String) -> Bool {
        let triggerStart = textBeforeCursor.index(
            textBeforeCursor.endIndex,
            offsetBy: -trigger.count
        )
        guard triggerStart > textBeforeCursor.startIndex else {
            return true
        }

        let previous = textBeforeCursor[textBeforeCursor.index(before: triggerStart)]
        return previous.isWhitespace
    }

    private func normalizedApp(_ bundleIdentifier: String) -> String {
        bundleIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

private extension Character {
    var isASCIIControl: Bool {
        unicodeScalars.allSatisfy { scalar in
            scalar.value < 0x20 || scalar.value == 0x7f
        }
    }
}
