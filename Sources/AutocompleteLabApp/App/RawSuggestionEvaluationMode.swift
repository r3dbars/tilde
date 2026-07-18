import Foundation

struct RawSuggestionEvaluationMode: Equatable, Sendable {
    static let environmentKey = "STEADYTYPE_RAW_SUGGESTIONS"

    let isEnabled: Bool

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        let value = environment[Self.environmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        isEnabled = ["1", "true", "yes", "on"].contains(value)
    }
}
