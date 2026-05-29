import Foundation

struct SuggestionDecisionPresentation: Equatable {
    let decision: String

    init(_ decision: String) {
        self.decision = decision
    }

    var menuTitle: String {
        "Why: \(summary)"
    }

    var settingsText: String {
        "Why: \(summary)"
    }

    var diagnosticsText: String {
        summary
    }

    var diagnosticsKind: String {
        switch statusKind {
        case .quiet:
            return "quiet"
        case .waiting:
            return "waiting"
        case .thinking:
            return "thinking"
        case .shown:
            return "shown"
        case .ready:
            return "ready"
        }
    }

    var statusKind: StatusKind {
        let trimmed = normalizedDecision
        if trimmed.hasPrefix("Blocked:")
            || trimmed.hasPrefix("Quiet:")
            || trimmed.hasPrefix("Hidden:")
            || trimmed == "Paused"
            || trimmed.hasPrefix("Paused:") {
            return .quiet
        }
        if trimmed.hasPrefix("Waiting:") {
            return .waiting
        }
        if trimmed.hasPrefix("Queued:") {
            return .thinking
        }
        if trimmed.hasPrefix("Shown:") {
            return .shown
        }
        if trimmed.hasPrefix("Accepted:") {
            return .ready
        }
        return .ready
    }

    var summary: String {
        let trimmed = normalizedDecision
        guard !trimmed.isEmpty else {
            return "no suggestion yet"
        }

        if trimmed.hasPrefix("Shown:") {
            return "Shown"
        }

        if trimmed.hasPrefix("Accepted:") {
            return "Accepted"
        }

        for prefix in ["Blocked:", "Quiet:", "Hidden:", "Waiting:", "Ready:", "Queued:", "Paused:"] where trimmed.hasPrefix(prefix) {
            return Self.oneLine(
                String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines),
                maxLength: 96
            )
        }

        if trimmed == "Paused" {
            return "paused"
        }

        return Self.oneLine(trimmed, maxLength: 96)
    }

    private var normalizedDecision: String {
        decision
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func oneLine(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else {
            return text
        }

        let cutoff = text.index(text.startIndex, offsetBy: max(0, maxLength - 3))
        return String(text[..<cutoff]) + "..."
    }

    enum StatusKind: Equatable {
        case quiet
        case waiting
        case thinking
        case shown
        case ready
    }
}
