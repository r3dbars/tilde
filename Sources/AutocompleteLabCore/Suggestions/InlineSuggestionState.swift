public struct InlineSuggestionTicket: Equatable, Sendable {
    public let clientIdentifier: String
    public let bundleIdentifier: String
    public let contextFingerprint: UInt64
    public let selectionLocation: Int
    public let selectionLength: Int
    public let requestIdentifier: Int

    public init(
        clientIdentifier: String,
        bundleIdentifier: String,
        contextFingerprint: UInt64,
        selectionLocation: Int,
        selectionLength: Int,
        requestIdentifier: Int = 0
    ) {
        self.clientIdentifier = clientIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.contextFingerprint = contextFingerprint
        self.selectionLocation = selectionLocation
        self.selectionLength = selectionLength
        self.requestIdentifier = requestIdentifier
    }

    public static func fingerprint(_ text: String) -> UInt64 {
        text.utf8.reduce(14_695_981_039_346_656_037) { value, byte in
            (value ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }

    public func advancing(with text: String) -> Self {
        let fingerprint = text.utf8.reduce(contextFingerprint) { value, byte in
            (value ^ UInt64(byte)) &* 1_099_511_628_211
        }
        let utf16Count = text.utf16.count
        return Self(
            clientIdentifier: clientIdentifier,
            bundleIdentifier: bundleIdentifier,
            contextFingerprint: fingerprint,
            selectionLocation: selectionLocation < 0 ? selectionLocation : selectionLocation + utf16Count,
            selectionLength: 0,
            requestIdentifier: requestIdentifier
        )
    }

    /// A visible suggestion keeps its original request identity while the user
    /// types through it. Only the live field state must still match.
    public func matchesFieldState(of other: Self) -> Bool {
        clientIdentifier == other.clientIdentifier
            && bundleIdentifier == other.bundleIdentifier
            && contextFingerprint == other.contextFingerprint
            && selectionLocation == other.selectionLocation
            && selectionLength == other.selectionLength
    }
}

public struct InlineSuggestionState: Equatable, Sendable {
    public enum Event: Equatable, Sendable {
        case awaitSuggestion(InlineSuggestionTicket)
        case present(String, InlineSuggestionTicket)
        case type(String, current: InlineSuggestionTicket?, advanced: InlineSuggestionTicket?)
        case accept(InlineSuggestionTicket?)
        case dismiss
    }

    public enum Effect: Equatable, Sendable {
        case hide
        case insert(String)
        case show(String)
        case schedule(afterTyping: String)
    }

    public private(set) var visibleText = ""
    public private(set) var visibleTicket: InlineSuggestionTicket?
    public private(set) var pendingTicket: InlineSuggestionTicket?

    public init() {}

    public var isVisible: Bool { !visibleText.isEmpty }

    public mutating func reduce(_ event: Event) -> [Effect] {
        switch event {
        case let .awaitSuggestion(ticket):
            let effects: [Effect] = isVisible ? [.hide] : []
            visibleText = ""
            visibleTicket = nil
            pendingTicket = ticket
            return effects

        case let .present(text, ticket):
            guard !text.isEmpty, pendingTicket == ticket else { return [] }
            pendingTicket = nil
            visibleText = text
            visibleTicket = ticket
            return [.show(text)]

        case let .type(grapheme, current, advanced):
            pendingTicket = nil
            guard
                visibleTicket == current,
                let advanced,
                let first = visibleText.first,
                String(first) == grapheme
            else {
                let effects: [Effect] = isVisible
                    ? [.hide, .insert(grapheme), .schedule(afterTyping: grapheme)]
                    : [.insert(grapheme), .schedule(afterTyping: grapheme)]
                visibleText = ""
                visibleTicket = nil
                return effects
            }

            let remainder = String(visibleText.dropFirst())
            visibleText = remainder
            visibleTicket = remainder.isEmpty ? nil : advanced
            return remainder.isEmpty
                ? [.hide, .insert(grapheme)]
                : [.hide, .insert(grapheme), .show(remainder)]

        case let .accept(current):
            pendingTicket = nil
            guard isVisible, visibleTicket == current else {
                let effects: [Effect] = isVisible ? [.hide] : []
                visibleText = ""
                visibleTicket = nil
                return effects
            }
            let accepted = visibleText
            visibleText = ""
            visibleTicket = nil
            return [.hide, .insert(accepted)]

        case .dismiss:
            pendingTicket = nil
            let effects: [Effect] = isVisible ? [.hide] : []
            visibleText = ""
            visibleTicket = nil
            return effects
        }
    }
}
