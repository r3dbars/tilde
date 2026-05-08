import Foundation

public enum BrowserHostedSurface: String, Equatable, Sendable {
    case googleDocs = "google-docs"
    case notion = "notion"
    case slack = "slack"
    case discord = "discord"

    public var displayName: String {
        switch self {
        case .googleDocs:
            return "Google Docs"
        case .notion:
            return "Notion"
        case .slack:
            return "Slack"
        case .discord:
            return "Discord"
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
        if matchesSlack(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .slack))
        }
        if matchesDiscord(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .discord))
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
