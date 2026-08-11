import Foundation

/// The only messages exchanged between Tilde and its input method.
/// Raw context exists only in the request process memory and is never logged.
public struct GhostBrainRequest: Codable, Equatable, Sendable {
    public static let version = 1

    public let v: Int
    public let context: String
    public let app: String?

    public init(context: String, app: String?) {
        self.v = Self.version
        self.context = context
        self.app = app
    }
}

public struct GhostBrainResponse: Codable, Equatable, Sendable {
    public enum Outcome: String, Codable, Sendable {
        case suggestion
        case silence
        case unavailable
        case error
        case timeout
        case invalidRequest = "invalid_request"
    }

    public let outcome: Outcome
    public let suggestion: String?

    public static func suggestion(_ text: String) -> Self {
        text.isEmpty ? .silence : Self(outcome: .suggestion, suggestion: text)
    }

    public static let silence = Self(outcome: .silence, suggestion: nil)
    public static let unavailable = Self(outcome: .unavailable, suggestion: nil)
    public static let error = Self(outcome: .error, suggestion: nil)
    public static let timeout = Self(outcome: .timeout, suggestion: nil)
    public static let invalidRequest = Self(outcome: .invalidRequest, suggestion: nil)

    /// A response from an authenticated peer that does not match this protocol
    /// is a runtime error, not an unavailable app.
    public static func decode(_ data: Data) -> Self {
        (try? JSONDecoder().decode(Self.self, from: data)) ?? .error
    }
}
