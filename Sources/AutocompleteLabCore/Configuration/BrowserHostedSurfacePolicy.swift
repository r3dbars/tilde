import Foundation

public enum BrowserHostedSurface: String, Equatable, Sendable {
    case googleDocs = "google-docs"
    case notion = "notion"
    case gmail = "gmail"
    case chatGPT = "chatgpt"
    case claudeWeb = "claude-web"
    case codexWeb = "codex-web"
    case slack = "slack"
    case discord = "discord"
    case telegramWeb = "telegram-web"

    public var displayName: String {
        switch self {
        case .googleDocs:
            return "Google Docs"
        case .notion:
            return "Notion"
        case .gmail:
            return "Gmail"
        case .chatGPT:
            return "ChatGPT"
        case .claudeWeb:
            return "Claude web"
        case .codexWeb:
            return "Codex web"
        case .slack:
            return "Slack"
        case .discord:
            return "Discord"
        case .telegramWeb:
            return "Telegram web"
        }
    }

    public var surfaceKind: BrowserHostedSurfaceKind {
        switch self {
        case .googleDocs, .notion:
            return .productionRichEditor
        case .gmail:
            return .emailComposer
        case .chatGPT, .claudeWeb, .codexWeb:
            return .promptComposer
        case .slack, .discord, .telegramWeb:
            return .messageComposer
        }
    }

    public var isActionBearing: Bool {
        switch surfaceKind {
        case .productionRichEditor:
            return false
        case .emailComposer, .promptComposer, .messageComposer:
            return true
        }
    }

    public var defaultBlockReason: BrowserHostedSurfaceBlockReason {
        isActionBearing ? .actionBearingNeedsNoSubmitProof : .unsupportedSurfaceNeedsProof
    }
}

public enum BrowserHostedSurfaceKind: String, Equatable, Sendable {
    case productionRichEditor = "production-rich-editor"
    case emailComposer = "email-composer"
    case promptComposer = "prompt-composer"
    case messageComposer = "message-composer"
}

public enum BrowserHostedSurfaceBlockReason: String, Equatable, Sendable {
    case unsupportedSurfaceNeedsProof = "unsupported-surface-needs-proof"
    case actionBearingNeedsNoSubmitProof = "action-bearing-needs-no-submit-proof"
}

public struct BrowserHostedSurfaceBlock: Equatable, Sendable {
    public let surface: BrowserHostedSurface
    public let reason: BrowserHostedSurfaceBlockReason

    public init(
        surface: BrowserHostedSurface,
        reason: BrowserHostedSurfaceBlockReason? = nil
    ) {
        self.surface = surface
        self.reason = reason ?? surface.defaultBlockReason
    }

    public var traceReason: String {
        "unsupported-browser-surface"
    }

    public var userFacingReason: String {
        switch reason {
        case .unsupportedSurfaceNeedsProof:
            "\(surface.displayName) needs proof first"
        case .actionBearingNeedsNoSubmitProof:
            "\(surface.displayName) needs no-submit proof first"
        }
    }

    public var traceMetadata: [String: String] {
        [
            "reason": traceReason,
            "browserSurface": surface.rawValue,
            "browserSurfaceKind": surface.surfaceKind.rawValue,
            "browserSurfaceActionBearing": String(surface.isActionBearing),
            "browserSurfaceDecision": "blocked",
            "browserSurfaceReason": reason.rawValue
        ]
    }
}

public enum BrowserHostedSurfaceDecision: Equatable, Sendable {
    case allowed
    case blocked(BrowserHostedSurfaceBlock)

    public var canSuggest: Bool {
        switch self {
        case .allowed:
            return true
        case .blocked:
            return false
        }
    }
}

public struct BrowserHostedSurfacePolicy: Equatable, Sendable {
    public static let browserBundleIdentifiers: Set<String> = [
        "com.google.Chrome"
    ]

    public init() {}

    public func decision(
        bundleIdentifier: String,
        fingerprint: FocusedElementFingerprint
    ) -> BrowserHostedSurfaceDecision {
        guard Self.browserBundleIdentifiers.contains(bundleIdentifier) else {
            return .allowed
        }

        let searchableText = fingerprint.searchableText
        if matchesGoogleDocs(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .googleDocs))
        }
        if matchesNotion(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .notion))
        }
        if matchesGmail(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .gmail))
        }
        if matchesChatGPT(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .chatGPT))
        }
        if matchesClaudeWeb(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .claudeWeb))
        }
        if matchesCodexWeb(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .codexWeb))
        }
        if matchesSlack(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .slack))
        }
        if matchesDiscord(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .discord))
        }
        if matchesTelegramWeb(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .telegramWeb))
        }

        return .allowed
    }

    private func matchesGoogleDocs(_ searchableText: String) -> Bool {
        searchableText.contains("docs.google.com")
            || searchableText.contains("google docs")
    }

    private func matchesNotion(_ searchableText: String) -> Bool {
        searchableText.contains("notion.so")
            || searchableText.contains("notion.site")
            || searchableText.contains("notion -")
            || searchableText.contains("- notion")
            || searchableText == "notion"
    }

    private func matchesGmail(_ searchableText: String) -> Bool {
        searchableText.contains("mail.google.com")
            || searchableText.contains("gmail |")
            || searchableText.contains("| gmail")
            || searchableText.contains("gmail -")
            || searchableText.contains("- gmail")
            || searchableText == "gmail"
    }

    private func matchesChatGPT(_ searchableText: String) -> Bool {
        searchableText.contains("chatgpt.com")
            || searchableText.contains("chat.openai.com")
            || searchableText.contains("chatgpt |")
            || searchableText.contains("| chatgpt")
            || searchableText.contains("chatgpt -")
            || searchableText.contains("- chatgpt")
            || searchableText == "chatgpt"
    }

    private func matchesClaudeWeb(_ searchableText: String) -> Bool {
        searchableText.contains("claude.ai")
            || searchableText.contains("claude |")
            || searchableText.contains("| claude")
            || searchableText.contains("claude -")
            || searchableText.contains("- claude")
            || searchableText == "claude"
    }

    private func matchesCodexWeb(_ searchableText: String) -> Bool {
        searchableText.contains("codex.openai.com")
            || searchableText.contains("openai codex")
            || searchableText.contains("codex | openai")
            || searchableText.contains("openai | codex")
            || searchableText.contains("codex - openai")
            || searchableText.contains("openai - codex")
    }

    private func matchesSlack(_ searchableText: String) -> Bool {
        searchableText.contains("app.slack.com")
            || searchableText.contains("slack.com")
            || searchableText.contains("slack |")
            || searchableText.contains("| slack")
            || searchableText.contains("slack -")
            || searchableText.contains("- slack")
            || searchableText == "slack"
    }

    private func matchesDiscord(_ searchableText: String) -> Bool {
        searchableText.contains("discord.com")
            || searchableText.contains("discordapp.com")
            || searchableText.contains("discord |")
            || searchableText.contains("| discord")
            || searchableText.contains("discord -")
            || searchableText.contains("- discord")
            || searchableText == "discord"
    }

    private func matchesTelegramWeb(_ searchableText: String) -> Bool {
        searchableText.contains("web.telegram.org")
            || searchableText.contains("telegram |")
            || searchableText.contains("| telegram")
            || searchableText.contains("telegram -")
            || searchableText.contains("- telegram")
            || searchableText == "telegram"
    }
}
