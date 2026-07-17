import Foundation

public enum BrowserHostedSurface: String, Equatable, Sendable {
    case unproven = "unproven-browser-surface"
    case googleDocs = "google-docs"
    case notion = "notion"
    case chatGPT = "chatgpt"
    case slack = "slack"
    case discord = "discord"
    case webmail = "webmail"
    case login = "browser-login"
    case payment = "browser-payment"
    case passwordManager = "browser-password-manager"
    case privateSearch = "browser-private-search"
    case browserSearchOrAddressBar = "browser-search-or-address-bar"
    case browserDeveloperTool = "browser-developer-tool"

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
        case .webmail:
            return "Browser email"
        case .login:
            return "This login page"
        case .payment:
            return "This payment page"
        case .passwordManager:
            return "This password manager page"
        case .privateSearch:
            return "This private search page"
        case .browserSearchOrAddressBar:
            return "This browser search or address bar"
        case .browserDeveloperTool:
            return "This browser developer tool"
        }
    }

    public var safetyClass: String {
        switch self {
        case .chatGPT, .slack, .discord:
            return "browser-chat"
        case .webmail:
            return "browser-webmail"
        case .unproven:
            return "browser-unknown"
        case .googleDocs, .notion:
            return "browser-editor"
        case .login, .payment, .passwordManager, .privateSearch,
             .browserSearchOrAddressBar, .browserDeveloperTool:
            return "browser-sensitive"
        }
    }

    public var requiredProofKind: String {
        switch self {
        case .chatGPT, .slack, .discord:
            return "exact-disposable-real-service-one-word-no-submit-screenshot-insertion"
        case .webmail:
            return "exact-disposable-webmail-reply-safe-tab-screenshot-insertion-undo-latency"
        case .googleDocs, .notion:
            return "exact-disposable-real-service-safe-tab-no-submit-screenshot-insertion-undo"
        case .unproven:
            return "exact-disposable-production-page-screenshot-insertion"
        case .login, .payment, .passwordManager, .privateSearch,
             .browserSearchOrAddressBar, .browserDeveloperTool:
            return "blocked-sensitive-browser-surface"
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
            "browserSurfaceRequiredProof": surface.requiredProofKind,
            "localFixtureProofCountsForProduction": "false",
            "promptSafetyMetricSurface": surface.safetyClass
        ]
    }

    public func redactedTraceMetadata(
        textBeforeCursorLength: Int,
        textAfterCursorLength: Int
    ) -> [String: String] {
        var metadata = traceMetadata
        metadata["blockedSurfaceTextRedacted"] = "true"
        metadata["textBeforeCursorChars"] = "\(textBeforeCursorLength)"
        metadata["textAfterCursorChars"] = "\(textAfterCursorLength)"
        return metadata
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
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.brave.Browser",
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "company.thebrowser.Browser",
        "org.chromium.Chromium",
        "org.mozilla.firefox"
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
        if matchesPayment(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .payment))
        }
        if matchesPasswordManager(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .passwordManager))
        }
        if matchesPrivateSearch(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .privateSearch))
        }
        if matchesBrowserSearchOrAddressBar(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .browserSearchOrAddressBar))
        }
        if matchesBrowserDeveloperTool(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .browserDeveloperTool))
        }
        if matchesLogin(searchableText) {
            return .blocked(BrowserHostedSurfaceBlock(surface: .login))
        }
        return .allowed
    }

    /// Personal writing capture remains separately privacy-gated even though
    /// suggestions are allowed on ordinary hosted writing surfaces.
    public func personalCaptureDecision(
        bundleIdentifier: String,
        fingerprint: FocusedElementFingerprint
    ) -> BrowserHostedSurfaceDecision {
        let suggestionDecision = decision(
            bundleIdentifier: bundleIdentifier,
            fingerprint: fingerprint
        )
        if case .blocked = suggestionDecision {
            return suggestionDecision
        }
        guard Self.browserBundleIdentifiers.contains(bundleIdentifier) else {
            return .allowed
        }

        let searchableText = fingerprint.searchableText
        let surface: BrowserHostedSurface
        if matchesGoogleDocs(searchableText) {
            surface = .googleDocs
        } else if matchesNotion(searchableText) {
            surface = .notion
        } else if matchesChatGPT(searchableText) {
            surface = .chatGPT
        } else if matchesSlack(searchableText) {
            surface = .slack
        } else if matchesDiscord(searchableText) {
            surface = .discord
        } else if matchesWebmail(searchableText) {
            surface = .webmail
        } else {
            surface = .unproven
        }
        return .blocked(BrowserHostedSurfaceBlock(surface: surface))
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
            || containsStandaloneWord("notion", in: searchableText)
            || searchableText == "notion"
    }

    private func matchesChatGPT(_ searchableText: String) -> Bool {
        searchableText.contains("chatgpt.com")
            || searchableText.contains("chat.openai.com")
            || searchableText.contains("chatgpt |")
            || searchableText.contains("| chatgpt")
            || searchableText.contains("chatgpt -")
            || searchableText.contains("- chatgpt")
            || containsStandaloneWord("chatgpt", in: searchableText)
            || searchableText == "chatgpt"
    }

    private func matchesSlack(_ searchableText: String) -> Bool {
        searchableText.contains("app.slack.com")
            || searchableText.contains("slack.com")
            || searchableText.contains("slack |")
            || searchableText.contains("| slack")
            || searchableText.contains("slack -")
            || searchableText.contains("- slack")
            || containsStandaloneWord("slack", in: searchableText)
            || searchableText == "slack"
    }

    private func matchesDiscord(_ searchableText: String) -> Bool {
        searchableText.contains("discord.com")
            || searchableText.contains("discordapp.com")
            || searchableText.contains("discord |")
            || searchableText.contains("| discord")
            || searchableText.contains("discord -")
            || searchableText.contains("- discord")
            || containsStandaloneWord("discord", in: searchableText)
            || searchableText == "discord"
    }

    private func matchesWebmail(_ searchableText: String) -> Bool {
        searchableText.contains("outlook.office.com")
            || searchableText.contains("outlook.live.com")
            || searchableText.contains("outlook.office365.com")
            || searchableText.contains("office.com/mail")
            || searchableText.contains("mail.google.com")
            || searchableText.contains("gmail.com")
            || searchableText.contains("mail.yahoo.com")
            || searchableText.contains("fastmail.com")
            || searchableText.contains("app.fastmail.com")
            || searchableText.contains("proton.me/mail")
            || searchableText.contains("mail.proton.me")
            || searchableText.contains("icloud.com/mail")
            || searchableText.contains("gmail -")
            || searchableText.contains("- gmail")
            || searchableText.contains("yahoo mail")
            || searchableText.contains("fastmail")
            || searchableText.contains("proton mail")
            || searchableText.contains("icloud mail")
            || searchableText.contains("outlook -")
            || searchableText.contains("- outlook")
            || searchableText.contains("microsoft outlook")
            || searchableText.contains("office 365 mail")
            || searchableText.contains("outlook web access")
            || searchableText.contains("owa.")
            || searchableText.contains("/owa")
            || searchableText.contains("owa/")
            || searchableText.contains("new message")
            || searchableText.contains("email reply")
    }

    private func containsStandaloneWord(_ word: String, in searchableText: String) -> Bool {
        searchableText
            .split { character in
                !(character.isLetter || character.isNumber)
            }
            .contains { $0 == word }
    }

    private func matchesPayment(_ searchableText: String) -> Bool {
        searchableText.contains("checkout")
            || searchableText.contains("payment")
            || searchableText.contains("billing")
            || searchableText.contains("apple pay")
            || searchableText.contains("credit card")
            || searchableText.contains("card number")
            || searchableText.contains("card security code")
            || searchableText.contains("cvv")
            || searchableText.contains("cvc")
            || searchableText.contains("paypal")
            || searchableText.contains("iban")
            || searchableText.contains("routing number")
            || searchableText.contains("bank account")
            || searchableText.contains("stripe.com")
    }

    private func matchesPasswordManager(_ searchableText: String) -> Bool {
        searchableText.contains("1password")
            || searchableText.contains("bitwarden")
            || searchableText.contains("dashlane")
            || searchableText.contains("lastpass")
            || searchableText.contains("password manager")
            || searchableText.contains("autofill")
    }

    private func matchesPrivateSearch(_ searchableText: String) -> Bool {
        searchableText.contains("private search")
            || searchableText.contains("incognito search")
            || searchableText.contains("private browsing")
    }

    private func matchesBrowserSearchOrAddressBar(_ searchableText: String) -> Bool {
        searchableText.contains("address bar")
            || searchableText.contains("location bar")
            || searchableText.contains("omnibox")
            || searchableText.contains("search or type web address")
            || searchableText.contains("search google or type a url")
            || searchableText.contains("search or enter address")
    }

    private func matchesBrowserDeveloperTool(_ searchableText: String) -> Bool {
        searchableText.contains("dev terminal")
            || searchableText.contains("web terminal")
            || searchableText.contains("terminal command")
            || searchableText.contains("shell prompt")
            || searchableText.contains("console input")
            || searchableText.contains("console prompt")
            || searchableText.contains("developer console")
            || searchableText.contains("devtools console")
            || searchableText.contains("browser console")
            || searchableText.contains("bash prompt")
            || searchableText.contains("zsh prompt")
            || searchableText.contains("powershell prompt")
            || searchableText.contains("sudo command")
            || searchableText.contains("codespaces")
            || searchableText.contains("github.dev")
            || searchableText.contains("github dev")
            || searchableText.contains("replit")
            || searchableText.contains("stackblitz")
    }

    private func matchesLogin(_ searchableText: String) -> Bool {
        searchableText.contains("login")
            || searchableText.contains("log in")
            || searchableText.contains("sign in")
            || searchableText.contains("sign-in")
            || searchableText.contains("signin")
            || searchableText.contains("passkey")
            || searchableText.contains("sign in with")
            || searchableText.contains("oauth")
            || searchableText.contains("sso")
            || searchableText.contains("one-time code")
            || searchableText.contains("one time code")
            || searchableText.contains("authentication")
    }
}
