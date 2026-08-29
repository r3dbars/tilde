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
    /// Capability negotiation keeps version-1 peers compatible in both
    /// directions. Older apps ignore this field; older input methods omit it
    /// and therefore receive only the terminal response from a newer app.
    public let streamResponses: Bool?
    /// The IMKit controller that owns this completion. The app combines it
    /// with the current PID/window number so context and response delivery
    /// can be bound to the exact field/window, not merely an app bundle.
    public let fieldSessionIdentifier: String?
    /// H01 block-randomization arm (`a` or `b`) for the input method's current
    /// typing session. Omitted — and therefore ignored by the app — unless the
    /// disabled-by-default Model Preview harness is on. Only the arm identity
    /// travels: the visible-word cap is looked up from `H01Arm` inside the
    /// app, so no wire value can set a length directly.
    public let experimentArm: String?

    public var supportsStreamingResponses: Bool { streamResponses == true }

    public init(
        context: String,
        app: String?,
        fieldSessionIdentifier: String? = nil,
        experimentArm: String? = nil
    ) {
        self.v = Self.version
        self.context = context
        self.app = app
        self.personalHistoryEvents = nil
        self.screenMemoryEvent = nil
        self.streamResponses = true
        self.fieldSessionIdentifier = fieldSessionIdentifier
        self.experimentArm = experimentArm
    }

    public init(personalHistoryEvents: [PersonalHistoryEvent]) {
        self.v = Self.version
        self.context = ""
        self.app = nil
        self.personalHistoryEvents = personalHistoryEvents
        self.screenMemoryEvent = nil
        self.streamResponses = nil
        self.fieldSessionIdentifier = nil
        self.experimentArm = nil
    }

    public init(screenMemoryEvent: ScreenMemoryInputEvent) {
        self.v = Self.version
        self.context = ""
        self.app = nil
        self.personalHistoryEvents = nil
        self.screenMemoryEvent = screenMemoryEvent
        self.streamResponses = nil
        self.fieldSessionIdentifier = nil
        self.experimentArm = nil
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
        /// The text around the caret changed wholesale — a different
        /// conversation in the same window. The old snapshot is now the
        /// wrong conversation and must not be served again.
        case contentReset
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
    /// Every socket line is an event. `final == false` is a stable streamed
    /// prefix; the terminal line always carries `final == true`.
    public let final: Bool

    public init(outcome: Outcome, suggestion: String?, final: Bool = true) {
        self.outcome = outcome
        self.suggestion = suggestion
        self.final = final
    }

    private enum CodingKeys: String, CodingKey {
        case outcome, suggestion, final
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        outcome = try container.decode(Outcome.self, forKey: .outcome)
        suggestion = try container.decodeIfPresent(String.self, forKey: .suggestion)
        // A response from the pre-stream protocol was necessarily terminal.
        final = try container.decodeIfPresent(Bool.self, forKey: .final) ?? true
    }

    public static func suggestion(_ text: String) -> Self {
        text.isEmpty ? .silence : Self(outcome: .suggestion, suggestion: text)
    }

    public static func partial(_ text: String) -> Self {
        Self(outcome: .suggestion, suggestion: text, final: false)
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
