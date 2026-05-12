import Foundation

public enum BrowserHostedSurface: String, Equatable, Sendable {
    case unproven = "unproven-browser-surface"
    case googleDocs = "google-docs"
    case notion = "notion"
    case chatGPT = "chatgpt"
    case slack = "slack"
    case discord = "discord"
    case login = "browser-login"
    case payment = "browser-payment"
    case passwordManager = "browser-password-manager"
    case privateSearch = "browser-private-search"

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
        case .login:
            return "This login page"
        case .payment:
            return "This payment page"
        case .passwordManager:
            return "This password manager page"
        case .privateSearch:
            return "This private search page"
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
        case .login, .payment, .passwordManager, .privateSearch:
            return "browser-sensitive"
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
        if matchesPayment(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .payment))
        }
        if matchesPasswordManager(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .passwordManager))
        }
        if matchesPrivateSearch(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .privateSearch))
        }
        if matchesLogin(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .login))
        }
        if matchesLocalProofFixture(searchableText) {
            return .allowed
        }

        return .blocked(BrowserHostedSurfaceBlock(surface: .unproven))
    }

    private func matchesLocalProofFixture(_ searchableText: String) -> Bool {
        (searchableText.contains("autocomplete lab chrome")
            || searchableText.contains("steadytype chrome"))
            && searchableText.contains("smoke")
            && (
                searchableText.contains("local")
                    || searchableText.contains("fixture")
                    || searchableText.contains("localhost")
                    || searchableText.contains("127.0.0.1")
                    || searchableText.contains("ready=1")
            )
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

    private func matchesPayment(_ searchableText: String) -> Bool {
        searchableText.contains("checkout")
            || searchableText.contains("payment")
            || searchableText.contains("billing")
            || searchableText.contains("credit card")
            || searchableText.contains("card number")
            || searchableText.contains("stripe.com")
    }

    private func matchesPasswordManager(_ searchableText: String) -> Bool {
        searchableText.contains("1password")
            || searchableText.contains("bitwarden")
            || searchableText.contains("dashlane")
            || searchableText.contains("lastpass")
            || searchableText.contains("password manager")
    }

    private func matchesPrivateSearch(_ searchableText: String) -> Bool {
        searchableText.contains("private search")
            || searchableText.contains("incognito search")
            || searchableText.contains("private browsing")
    }

    private func matchesLogin(_ searchableText: String) -> Bool {
        searchableText.contains("login")
            || searchableText.contains("log in")
            || searchableText.contains("sign in")
            || searchableText.contains("signin")
            || searchableText.contains("authentication")
    }
}
