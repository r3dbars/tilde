import Foundation

/// The only messages exchanged between Tilde and its input method.
/// Completion context remains memory-only. Personal History events are the
/// explicit local-persistence payload and are never sent off-device.
public struct GhostBrainRequest: Codable, Equatable, Sendable {
    public static let version = 1
    public static let maximumWireBytes = 16_384

    public let v: Int
    public let context: String
    public let app: String?
    public let personalHistoryEvents: [PersonalHistoryEvent]?
    public let screenMemoryEvent: ScreenMemoryInputEvent?

    public init(context: String, app: String?) {
        self.v = Self.version
        self.context = context
        self.app = app
        self.personalHistoryEvents = nil
        self.screenMemoryEvent = nil
    }

    public init(personalHistoryEvents: [PersonalHistoryEvent]) {
        self.v = Self.version
        self.context = ""
        self.app = nil
        self.personalHistoryEvents = personalHistoryEvents
        self.screenMemoryEvent = nil
    }

    public init(screenMemoryEvent: ScreenMemoryInputEvent) {
        self.v = Self.version
        self.context = ""
        self.app = nil
        self.personalHistoryEvents = nil
        self.screenMemoryEvent = screenMemoryEvent
    }
}

/// A content-free lifecycle pulse from the input method to Screen Memory.
/// The session identifier prevents a late blur from an old IMKit controller
/// from cancelling capture for the newly focused field. No typed or screen
/// text crosses this message boundary.
public struct ScreenMemoryInputEvent: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case textFieldFocused
        case typingPaused
        case textFieldBlurred
    }

    public let kind: Kind
    public let sessionIdentifier: String

    public init(kind: Kind, sessionIdentifier: String) {
        self.kind = kind
        self.sessionIdentifier = sessionIdentifier
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
        case recorded
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
    public static let recorded = Self(outcome: .recorded, suggestion: nil)

    /// A response from an authenticated peer that does not match this protocol
    /// is a runtime error, not an unavailable app.
    public static func decode(_ data: Data) -> Self {
        (try? JSONDecoder().decode(Self.self, from: data)) ?? .error
    }
}
