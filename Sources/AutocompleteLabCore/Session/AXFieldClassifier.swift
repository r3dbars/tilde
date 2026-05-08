import Foundation

public enum AXFieldKind: String, Codable, Equatable, Sendable, CaseIterable {
    case multilineCompose
    case singlelineCompose
    case search
    case form
    case secure
    case url
    case unprovenSurface
    case unknown

    public var suppressesSuggestionsByDefault: Bool {
        switch self {
        case .search, .form, .secure, .url, .unprovenSurface:
            true
        case .multilineCompose, .singlelineCompose, .unknown:
            false
        }
    }
}

public struct AXFieldClassification: Equatable, Sendable {
    public let kind: AXFieldKind
    public let reason: String

    public init(kind: AXFieldKind, reason: String) {
        self.kind = kind
        self.reason = reason
    }

    public var suppressesSuggestionsByDefault: Bool {
        kind.suppressesSuggestionsByDefault
    }

    public var traceMetadata: [String: String] {
        [
            "fieldKind": kind.rawValue,
            "fieldKindReason": reason,
            "fieldKindSuppressed": String(kind.suppressesSuggestionsByDefault)
        ]
    }
}

public struct AXFieldClassifierInput: Equatable, Sendable {
    public let role: String?
    public let subrole: String?
    public let title: String?
    public let placeholder: String?
    public let windowTitle: String?
    public let isSecure: Bool
    public let textBeforeCursorLength: Int
    public let textAfterCursorLength: Int
    public let selectedTextLength: Int
    public let lineCount: Int

    public init(
        role: String? = nil,
        subrole: String? = nil,
        title: String? = nil,
        placeholder: String? = nil,
        windowTitle: String? = nil,
        isSecure: Bool = false,
        textBeforeCursorLength: Int = 0,
        textAfterCursorLength: Int = 0,
        selectedTextLength: Int = 0,
        lineCount: Int = 0
    ) {
        self.role = role
        self.subrole = subrole
        self.title = title
        self.placeholder = placeholder
        self.windowTitle = windowTitle
        self.isSecure = isSecure
        self.textBeforeCursorLength = max(0, textBeforeCursorLength)
        self.textAfterCursorLength = max(0, textAfterCursorLength)
        self.selectedTextLength = max(0, selectedTextLength)
        self.lineCount = max(0, lineCount)
    }
}

public struct AXFieldClassifier: Equatable, Sendable {
    public init() {}

    public func classify(_ input: AXFieldClassifierInput) -> AXFieldKind {
        classification(for: input).kind
    }

    public func classification(for input: AXFieldClassifierInput) -> AXFieldClassification {
        if input.isSecure {
            return AXFieldClassification(kind: .secure, reason: "secureAXFlag")
        }

        if hasRole(input, "AXSecureTextField") {
            return AXFieldClassification(kind: .secure, reason: "secureRole")
        }

        if let match = firstMatch(input, needles: Self.secureNeedles) {
            return AXFieldClassification(kind: .secure, reason: "secureHint:\(match)")
        }

        if hasRole(input, "AXURLField") {
            return AXFieldClassification(kind: .url, reason: "urlRole")
        }

        if let match = firstMatch(input, needles: Self.urlNeedles) {
            return AXFieldClassification(kind: .url, reason: "urlHint:\(match)")
        }

        if hasRole(input, "AXSearchField") {
            return AXFieldClassification(kind: .search, reason: "searchRole")
        }

        if let match = firstMatch(input, needles: Self.searchNeedles) {
            return AXFieldClassification(kind: .search, reason: "searchHint:\(match)")
        }

        if hasRole(input, "AXComboBox") {
            return AXFieldClassification(kind: .form, reason: "comboBoxRole")
        }

        if let match = firstMatch(input, needles: Self.formNeedles) {
            return AXFieldClassification(kind: .form, reason: "formHint:\(match)")
        }

        if let match = firstMatch(input, needles: Self.unprovenSurfaceNeedles) {
            return AXFieldClassification(kind: .unprovenSurface, reason: "unprovenSurface:\(match)")
        }

        if hasRole(input, "AXTextArea") {
            return AXFieldClassification(kind: .multilineCompose, reason: "textAreaRole")
        }

        if input.lineCount > 1 {
            return AXFieldClassification(kind: .multilineCompose, reason: "multipleLines")
        }

        if hasRole(input, "AXWebArea"),
           input.textAfterCursorLength + input.textBeforeCursorLength > 0 || hasComposeHint(input) {
            return AXFieldClassification(kind: .multilineCompose, reason: "webCompose")
        }

        if hasRole(input, "AXTextField") {
            if hasComposeHint(input) {
                return AXFieldClassification(kind: .singlelineCompose, reason: "singlelineComposeHint")
            }

            return AXFieldClassification(kind: .form, reason: "shortTextField")
        }

        return AXFieldClassification(kind: .unknown, reason: "unknown")
    }

    private func hasRole(_ input: AXFieldClassifierInput, _ role: String) -> Bool {
        input.role == role || input.subrole == role
    }

    private func firstMatch(_ input: AXFieldClassifierInput, needles: [String]) -> String? {
        let haystack = normalizedHaystack(input)
        return needles.first { haystack.contains($0) }
    }

    private func hasComposeHint(_ input: AXFieldClassifierInput) -> Bool {
        firstMatch(input, needles: Self.composeNeedles) != nil
    }

    private func normalizedHaystack(_ input: AXFieldClassifierInput) -> String {
        [
            input.role,
            input.subrole,
            input.title,
            input.placeholder,
            input.windowTitle
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()
    }

    private static let secureNeedles: [String] = [
        "password",
        "passcode",
        "one-time code",
        "otp",
        "secret",
        "security code",
        "cvv",
        "cvc"
    ]

    private static let urlNeedles: [String] = [
        "axurlfield",
        "url",
        "address bar",
        "location bar",
        "search or enter address",
        "website",
        "web address"
    ]

    private static let searchNeedles: [String] = [
        "axsearchfield",
        "search",
        "find",
        "filter",
        "query",
        "spotlight"
    ]

    private static let formNeedles: [String] = [
        "address",
        "email",
        "e-mail",
        "phone",
        "telephone",
        "zip",
        "postal",
        "credit card",
        "card number",
        "expiration",
        "expiry",
        "name on card",
        "payment",
        "username",
        "login",
        "account",
        "subject",
        "to:",
        "cc:",
        "bcc:",
        "date"
    ]

    private static let composeNeedles: [String] = [
        "message",
        "comment",
        "reply",
        "post",
        "note",
        "body",
        "description",
        "draft",
        "compose",
        "write"
    ]

    private static let unprovenSurfaceNeedles: [String] = [
        "docs.google",
        "google docs",
        "notion",
        "slack",
        "discord"
    ]
}
