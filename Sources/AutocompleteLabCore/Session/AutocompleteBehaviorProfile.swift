import Foundation

public enum AutocompleteBehaviorProfileID: String, Codable, Equatable, Sendable, CaseIterable {
    case casualChat = "casual_chat"
    case email
    case notes
    case coding
    case docsProse = "docs_prose"
    case bullets
    case forms
    case search
    case aiChat = "ai_chat"
}

public struct AutocompleteBehaviorSuppressionDefaults: Equatable, Sendable {
    public let suppressesSuggestionsByDefault: Bool
    public let suppressesFreshParagraphStart: Bool
    public let suppressesBlankLine: Bool
    public let suppressesQuestions: Bool
    public let suppressesEmotionalText: Bool
    public let allowsFullAccept: Bool
    public let allowsSubmitLikeCompletions: Bool

    public init(
        suppressesSuggestionsByDefault: Bool = false,
        suppressesFreshParagraphStart: Bool = false,
        suppressesBlankLine: Bool = false,
        suppressesQuestions: Bool = false,
        suppressesEmotionalText: Bool = false,
        allowsFullAccept: Bool = true,
        allowsSubmitLikeCompletions: Bool = false
    ) {
        self.suppressesSuggestionsByDefault = suppressesSuggestionsByDefault
        self.suppressesFreshParagraphStart = suppressesFreshParagraphStart
        self.suppressesBlankLine = suppressesBlankLine
        self.suppressesQuestions = suppressesQuestions
        self.suppressesEmotionalText = suppressesEmotionalText
        self.allowsFullAccept = allowsFullAccept
        self.allowsSubmitLikeCompletions = allowsSubmitLikeCompletions
    }
}

public struct AutocompleteBehaviorProfile: Equatable, Sendable {
    public let id: AutocompleteBehaviorProfileID
    public let maxVisibleWords: Int
    public let maxGeneratedTokens: Int
    public let suppressionDefaults: AutocompleteBehaviorSuppressionDefaults
    public let promptGuidance: [String]

    public init(
        id: AutocompleteBehaviorProfileID,
        maxVisibleWords: Int,
        maxGeneratedTokens: Int,
        suppressionDefaults: AutocompleteBehaviorSuppressionDefaults,
        promptGuidance: [String]
    ) {
        self.id = id
        self.maxVisibleWords = CompletionModelPolicy.clampedVisibleWords(maxVisibleWords)
        self.maxGeneratedTokens = CompletionModelPolicy.clampedGeneratedTokens(maxGeneratedTokens)
        self.suppressionDefaults = suppressionDefaults
        self.promptGuidance = promptGuidance
    }

    public var traceMetadata: [String: String] {
        [
            "behaviorProfile": id.rawValue,
            "behaviorProfileMaxVisibleWords": String(maxVisibleWords),
            "behaviorProfileMaxGeneratedTokens": String(maxGeneratedTokens),
            "behaviorProfileSuppressedByDefault": String(suppressionDefaults.suppressesSuggestionsByDefault),
            "behaviorProfileSuppressesFreshParagraphStart": String(suppressionDefaults.suppressesFreshParagraphStart),
            "behaviorProfileSuppressesBlankLine": String(suppressionDefaults.suppressesBlankLine),
            "behaviorProfileSuppressesQuestions": String(suppressionDefaults.suppressesQuestions),
            "behaviorProfileFullAccept": String(suppressionDefaults.allowsFullAccept),
            "behaviorProfileSubmitLikeCompletions": String(suppressionDefaults.allowsSubmitLikeCompletions)
        ]
    }

    public static func profile(_ id: AutocompleteBehaviorProfileID) -> AutocompleteBehaviorProfile {
        switch id {
        case .casualChat:
            return AutocompleteBehaviorProfile(
                id: .casualChat,
                maxVisibleWords: 20,
                maxGeneratedTokens: 48,
                suppressionDefaults: AutocompleteBehaviorSuppressionDefaults(
                    suppressesQuestions: true,
                    suppressesEmotionalText: true
                ),
                promptGuidance: [
                    "Use a casual, plain style without sounding overeager.",
                    "Do not answer questions or steer emotional text; return <NO_SUGGESTION> instead."
                ]
            )
        case .email:
            return AutocompleteBehaviorProfile(
                id: .email,
                maxVisibleWords: 20,
                maxGeneratedTokens: 48,
                suppressionDefaults: AutocompleteBehaviorSuppressionDefaults(
                    suppressesFreshParagraphStart: true,
                    suppressesBlankLine: true
                ),
                promptGuidance: [
                    "Keep email continuations polite, simple, and not flowery.",
                    "Do not invent commitments, names, dates, deadlines, meetings, attachments, or follow-ups."
                ]
            )
        case .notes:
            return AutocompleteBehaviorProfile(
                id: .notes,
                maxVisibleWords: 20,
                maxGeneratedTokens: 48,
                suppressionDefaults: AutocompleteBehaviorSuppressionDefaults(
                    suppressesBlankLine: true
                ),
                promptGuidance: [
                    "Keep notes terse and local to the current thought.",
                    "Do not suggest on a blank paragraph unless the current line already constrains the continuation."
                ]
            )
        case .coding:
            return AutocompleteBehaviorProfile(
                id: .coding,
                maxVisibleWords: 5,
                maxGeneratedTokens: 8,
                suppressionDefaults: AutocompleteBehaviorSuppressionDefaults(
                    suppressesFreshParagraphStart: true
                ),
                promptGuidance: [
                    "Be conservative in code: continue only obvious syntax or identifiers already implied nearby.",
                    "Do not invent APIs, imports, blocks, filenames, configuration keys, or behavior."
                ]
            )
        case .docsProse:
            return AutocompleteBehaviorProfile(
                id: .docsProse,
                maxVisibleWords: 20,
                maxGeneratedTokens: 48,
                suppressionDefaults: AutocompleteBehaviorSuppressionDefaults(
                    suppressesFreshParagraphStart: true,
                    suppressesBlankLine: true
                ),
                promptGuidance: [
                    "Match the current prose rhythm and vocabulary.",
                    "Do not start a fresh paragraph or introduce a new point."
                ]
            )
        case .bullets:
            return AutocompleteBehaviorProfile(
                id: .bullets,
                maxVisibleWords: 20,
                maxGeneratedTokens: 48,
                suppressionDefaults: AutocompleteBehaviorSuppressionDefaults(),
                promptGuidance: [
                    "Preserve the current bullet marker, checkbox state, numbering style, and indentation.",
                    "After a bare marker, only continue when the local list clearly constrains the item."
                ]
            )
        case .forms:
            return AutocompleteBehaviorProfile(
                id: .forms,
                maxVisibleWords: 1,
                maxGeneratedTokens: 3,
                suppressionDefaults: AutocompleteBehaviorSuppressionDefaults(
                    suppressesSuggestionsByDefault: true,
                    suppressesFreshParagraphStart: true,
                    suppressesBlankLine: true,
                    allowsFullAccept: false
                ),
                promptGuidance: [
                    "Forms are suppressed by default; only explicit free-form exceptions should ask for suggestions.",
                    "Do not fill names, addresses, payment data, account data, dates, or identifiers."
                ]
            )
        case .search:
            return AutocompleteBehaviorProfile(
                id: .search,
                maxVisibleWords: 1,
                maxGeneratedTokens: 3,
                suppressionDefaults: AutocompleteBehaviorSuppressionDefaults(
                    suppressesSuggestionsByDefault: true,
                    suppressesFreshParagraphStart: true,
                    suppressesBlankLine: true,
                    allowsFullAccept: false
                ),
                promptGuidance: [
                    "Search fields are suppressed by default.",
                    "Do not complete or submit search queries."
                ]
            )
        case .aiChat:
            return AutocompleteBehaviorProfile(
                id: .aiChat,
                maxVisibleWords: 20,
                maxGeneratedTokens: 48,
                suppressionDefaults: AutocompleteBehaviorSuppressionDefaults(
                    suppressesQuestions: true,
                    allowsFullAccept: false
                ),
                promptGuidance: [
                    "Keep prompt-app continuations tiny unless the user explicitly raises the visible word limit.",
                    "Never suggest sending, submitting, pressing Enter or Return, running a command, approval text, slash commands, @ references, bang commands, shell text, or answering the prompt."
                ]
            )
        }
    }
}

public struct AutocompleteBehaviorProfileInput: Equatable, Sendable {
    public let requestedProfileID: AutocompleteBehaviorProfileID?
    public let appBundleIdentifier: String?
    public let fieldKind: AXFieldKind?
    public let currentLineStructure: CurrentLineStructure?

    public init(
        requestedProfileID: AutocompleteBehaviorProfileID? = nil,
        appBundleIdentifier: String? = nil,
        fieldKind: AXFieldKind? = nil,
        currentLineStructure: CurrentLineStructure? = nil
    ) {
        self.requestedProfileID = requestedProfileID
        self.appBundleIdentifier = appBundleIdentifier
        self.fieldKind = fieldKind
        self.currentLineStructure = currentLineStructure
    }
}

public struct AutocompleteBehaviorProfileResolver: Equatable, Sendable {
    public init() {}

    public func profile(for input: AutocompleteBehaviorProfileInput) -> AutocompleteBehaviorProfile {
        if let requestedProfileID = input.requestedProfileID {
            return AutocompleteBehaviorProfile.profile(requestedProfileID)
        }

        if input.fieldKind == .search {
            return AutocompleteBehaviorProfile.profile(.search)
        }

        if input.fieldKind == .form || input.fieldKind == .secure || input.fieldKind == .url {
            return AutocompleteBehaviorProfile.profile(.forms)
        }

        guard let appBundleIdentifier = input.appBundleIdentifier?.lowercased() else {
            if input.currentLineStructure?.isListLike == true {
                return AutocompleteBehaviorProfile.profile(.bullets)
            }
            return AutocompleteBehaviorProfile.profile(.docsProse)
        }

        if Self.aiChatBundleIdentifiers.contains(appBundleIdentifier) {
            return AutocompleteBehaviorProfile.profile(.aiChat)
        }

        if appBundleIdentifier == "com.apple.mail" {
            return AutocompleteBehaviorProfile.profile(.email)
        }

        if appBundleIdentifier == "com.apple.notes" {
            return AutocompleteBehaviorProfile.profile(.notes)
        }

        if Self.casualChatBundleIdentifiers.contains(appBundleIdentifier) {
            return AutocompleteBehaviorProfile.profile(.casualChat)
        }

        if Self.codingBundleIdentifiers.contains(appBundleIdentifier)
            || appBundleIdentifier.contains("xcode")
            || appBundleIdentifier.contains("vscode") {
            return AutocompleteBehaviorProfile.profile(.coding)
        }

        if input.currentLineStructure?.isListLike == true {
            return AutocompleteBehaviorProfile.profile(.bullets)
        }

        return AutocompleteBehaviorProfile.profile(.docsProse)
    }

    private static let aiChatBundleIdentifiers: Set<String> = [
        "com.openai.codex",
        "com.anthropic.claude-code",
        "com.anthropic.claudefordesktop"
    ]

    private static let casualChatBundleIdentifiers: Set<String> = [
        "com.apple.mobilesms",
        "ru.keepcoder.telegram"
    ]

    private static let codingBundleIdentifiers: Set<String> = [
        "com.apple.dt.xcode",
        "com.microsoft.vscode",
        "com.todesktop.230313mzl4w4u92"
    ]
}
