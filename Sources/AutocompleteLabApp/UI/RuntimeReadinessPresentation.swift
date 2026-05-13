import Foundation
import AutocompleteLabCore

struct RuntimeReadinessPresentation: Equatable {
    let report: RuntimeReadinessReport

    var settingsDetailText: String {
        appendingRuntimeDetail(to: RuntimeReadinessGuidance(report: report).message)
    }

    var modelText: String {
        appendingRuntimeDetail(to: "Local model: \(report.summary)")
    }

    var requestBlockedReason: String {
        appendingRuntimeDetail(to: "Local model is \(report.summary).")
    }

    private func appendingRuntimeDetail(to text: String) -> String {
        guard let detail = normalizedDetail else {
            return text
        }

        return "\(text) Runtime detail: \(detail)"
    }

    private var normalizedDetail: String? {
        let detail = (report.detail ?? "")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return detail.isEmpty ? nil : detail
    }
}
