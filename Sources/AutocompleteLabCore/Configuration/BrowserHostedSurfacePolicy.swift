import Foundation

public enum BrowserHostedSurface: String, Equatable, Sendable {
    case googleDocs = "google-docs"
    case notion = "notion"
    case gmail = "gmail"
    case chatGPT = "chatgpt"
    case claudeWeb = "claude-web"
    case codexWeb = "codex-web"
    case geminiWeb = "gemini-web"
    case perplexityWeb = "perplexity-web"
    case copilotWeb = "copilot-web"
    case poeWeb = "poe-web"
    case slack = "slack"
    case discord = "discord"
    case telegramWeb = "telegram-web"
    case teamsWeb = "teams-web"
    case whatsAppWeb = "whatsapp-web"
    case messengerWeb = "messenger-web"

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
        case .geminiWeb:
            return "Gemini web"
        case .perplexityWeb:
            return "Perplexity web"
        case .copilotWeb:
            return "Copilot web"
        case .poeWeb:
            return "Poe web"
        case .slack:
            return "Slack"
        case .discord:
            return "Discord"
        case .telegramWeb:
            return "Telegram web"
        case .teamsWeb:
            return "Teams web"
        case .whatsAppWeb:
            return "WhatsApp web"
        case .messengerWeb:
            return "Messenger web"
        }
    }

    public var surfaceKind: BrowserHostedSurfaceKind {
        switch self {
        case .googleDocs, .notion:
            return .productionRichEditor
        case .gmail:
            return .emailComposer
        case .chatGPT, .claudeWeb, .codexWeb, .geminiWeb, .perplexityWeb, .copilotWeb, .poeWeb:
            return .promptComposer
        case .slack, .discord, .telegramWeb, .teamsWeb, .whatsAppWeb, .messengerWeb:
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
        if matchesGeminiWeb(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .geminiWeb))
        }
        if matchesPerplexityWeb(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .perplexityWeb))
        }
        if matchesCopilotWeb(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .copilotWeb))
        }
        if matchesPoeWeb(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .poeWeb))
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
        if matchesTeamsWeb(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .teamsWeb))
        }
        if matchesWhatsAppWeb(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .whatsAppWeb))
        }
        if matchesMessengerWeb(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .messengerWeb))
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

    private func matchesGeminiWeb(_ searchableText: String) -> Bool {
        searchableText.contains("gemini.google.com")
            || searchableText.contains("bard.google.com")
            || searchableText.contains("google gemini")
            || searchableText.contains("gemini |")
            || searchableText.contains("| gemini")
            || searchableText.contains("gemini -")
            || searchableText.contains("- gemini")
            || searchableText == "gemini"
    }

    private func matchesPerplexityWeb(_ searchableText: String) -> Bool {
        searchableText.contains("perplexity.ai")
            || searchableText.contains("perplexity |")
            || searchableText.contains("| perplexity")
            || searchableText.contains("perplexity -")
            || searchableText.contains("- perplexity")
            || searchableText == "perplexity"
    }

    private func matchesCopilotWeb(_ searchableText: String) -> Bool {
        searchableText.contains("copilot.microsoft.com")
            || searchableText.contains("microsoft copilot")
            || searchableText.contains("copilot |")
            || searchableText.contains("| copilot")
            || searchableText.contains("copilot -")
            || searchableText.contains("- copilot")
            || searchableText == "copilot"
    }

    private func matchesPoeWeb(_ searchableText: String) -> Bool {
        searchableText.contains("poe.com")
            || searchableText.contains("poe |")
            || searchableText.contains("| poe")
            || searchableText.contains("poe -")
            || searchableText.contains("- poe")
            || searchableText == "poe"
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

    private func matchesTeamsWeb(_ searchableText: String) -> Bool {
        searchableText.contains("teams.microsoft.com")
            || searchableText.contains("microsoft teams")
            || searchableText.contains("teams |")
            || searchableText.contains("| teams")
            || searchableText.contains("teams -")
            || searchableText.contains("- teams")
    }

    private func matchesWhatsAppWeb(_ searchableText: String) -> Bool {
        searchableText.contains("web.whatsapp.com")
            || searchableText.contains("whatsapp |")
            || searchableText.contains("| whatsapp")
            || searchableText.contains("whatsapp -")
            || searchableText.contains("- whatsapp")
            || searchableText == "whatsapp"
    }

    private func matchesMessengerWeb(_ searchableText: String) -> Bool {
        searchableText.contains("messenger.com")
            || searchableText.contains("facebook messenger")
            || searchableText.contains("messenger |")
            || searchableText.contains("| messenger")
            || searchableText.contains("messenger -")
            || searchableText.contains("- messenger")
            || searchableText == "messenger"
    }
}
