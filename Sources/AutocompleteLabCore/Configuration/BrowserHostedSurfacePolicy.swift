import Foundation

public enum BrowserHostedSurface: String, Equatable, Sendable {
    case unproven = "unproven-browser-surface"
    case googleDocs = "google-docs"
    case notion = "notion"
    case chatGPT = "chatgpt"
    case slack = "slack"
    case discord = "discord"

    public var displayName: String {
        switch self {
        case .unproven:
            return "This browser page"
        case .googleDocs:
            return "Google Docs"
        case .notion:
            return "Notion"
        case .chatGPT:
            return "ChatGPT"
        case .slack:
            return "Slack"
        case .discord:
            return "Discord"
        }
    }

    public var safetyClass: String {
        switch self {
        case .chatGPT, .slack, .discord:
            return "browser-chat"
        case .unproven:
            return "browser-unknown"
        case .googleDocs, .notion:
            return "browser-editor"
        }
    }
}

public enum BrowserHostedSurfaceBlockReason: String, Equatable, Sendable {
    case unsupportedSurfaceNeedsProof = "unsupported-surface-needs-proof"
}

public struct BrowserHostedSurfaceBlock: Equatable, Sendable {
    public let surface: BrowserHostedSurface
    public let reason: BrowserHostedSurfaceBlockReason

    public init(
        surface: BrowserHostedSurface,
        reason: BrowserHostedSurfaceBlockReason = .unsupportedSurfaceNeedsProof
    ) {
        self.surface = surface
        self.reason = reason
    }

    public var traceReason: String {
        "unsupported-browser-surface"
    }

    public var userFacingReason: String {
        "\(surface.displayName) needs proof first"
    }

    public var traceMetadata: [String: String] {
        [
            "reason": traceReason,
            "browserSurface": surface.rawValue,
            "browserSurfaceDecision": "blocked",
            "browserSurfaceReason": reason.rawValue,
            "browserSurfaceSafetyClass": surface.safetyClass,
            "promptSafetyMetricSurface": surface.safetyClass
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
        if matchesLocalProofFixture(searchableText) {
            return .allowed
        }
        if matchesGoogleDocs(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .googleDocs))
        }
        if matchesNotion(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .notion))
        }
        if matchesChatGPT(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .chatGPT))
        }
        if matchesSlack(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .slack))
        }
        if matchesDiscord(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .discord))
        }

        return .blocked(BrowserHostedSurfaceBlock(surface: .unproven))
    }

    private func matchesLocalProofFixture(_ searchableText: String) -> Bool {
        (searchableText.contains("autocomplete lab chrome")
            || searchableText.contains("steadytype chrome"))
            && searchableText.contains("smoke")
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

    private func matchesChatGPT(_ searchableText: String) -> Bool {
        searchableText.contains("chatgpt.com")
            || searchableText.contains("chat.openai.com")
            || searchableText.contains("chatgpt |")
            || searchableText.contains("| chatgpt")
            || searchableText.contains("chatgpt -")
            || searchableText.contains("- chatgpt")
            || searchableText == "chatgpt"
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
}
