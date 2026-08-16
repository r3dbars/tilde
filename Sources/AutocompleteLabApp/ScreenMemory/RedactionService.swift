import AutocompleteLabCore
import Foundation

/// The redaction gate the Screen Memory covenant requires before ANY
/// captured screen text crosses into persistence or a completion prompt:
/// `SecretRules` (Core, pure, in-process) runs first over the whole text,
/// then GLiNER spans (model layer, confidence >= `spanConfidenceThreshold`)
/// run over what `SecretRules` left behind. Fail-closed end to end: if the
/// model layer is unavailable for ANY reason, `redact` returns `.dropped`,
/// never a rules-only partial result — the plan is explicit that a
/// redactor error drops the capture rather than storing it raw, and
/// "redactor unavailable" is exactly that error, not a degraded mode.
actor RedactionService {
    enum Outcome: Sendable, Equatable {
        case redacted(RedactedText)
        case dropped(DropReason)
    }

    enum DropReason: Sendable, Equatable {
        /// The model layer never answered — missing assets, launch
        /// failure, timeout, or a malformed/error reply. Every one of
        /// these collapses to the same case here on purpose: a caller
        /// deciding "drop the capture" never needs to distinguish them,
        /// and `GLiNERRedactionHelperHost` already logs the specific
        /// reason to diagnostics (count-only, no text) before this point.
        case modelUnavailable
    }

    struct RedactedText: Sendable, Equatable {
        let text: String
        /// Rule-layer finding types only (never the matched text) — safe
        /// to log or report as counts.
        let ruleFindings: [SecretRules.Finding]
        /// How many model-layer spans were redacted, and nothing else
        /// about them — no labels, no offsets, no score, no text. This
        /// count is the only thing about the model layer's findings that
        /// is ever allowed to leave this type.
        let modelSpanCount: Int
    }

    static let defaultSpanConfidenceThreshold = 0.5

    private let spanDetector: any GLiNERSpanDetecting
    private let scrubConfig: SecretRules.ScrubConfig
    private let spanConfidenceThreshold: Double

    init(
        spanDetector: any GLiNERSpanDetecting,
        scrubConfig: SecretRules.ScrubConfig = .forPersistence,
        spanConfidenceThreshold: Double = RedactionService.defaultSpanConfidenceThreshold
    ) {
        self.spanDetector = spanDetector
        self.scrubConfig = scrubConfig
        self.spanConfidenceThreshold = spanConfidenceThreshold
    }

    func redact(_ text: String) async -> Outcome {
        let (ruleClean, ruleFindings) = SecretRules.scrub(text, config: scrubConfig)

        guard let rawSpans = await spanDetector.detectSpans(in: ruleClean) else {
            return .dropped(.modelUnavailable)
        }

        let accepted = Self.resolveOverlaps(
            rawSpans.filter { $0.score >= spanConfidenceThreshold }
        )
        let (modelClean, appliedCount) = Self.applySpans(accepted, to: ruleClean)

        return .redacted(RedactedText(text: modelClean, ruleFindings: ruleFindings, modelSpanCount: appliedCount))
    }

    /// Same "earliest, then longest, then first" tie-break `SecretRules`
    /// uses for its own overlaps — kept identical on purpose so two
    /// redaction layers don't disagree about which of two overlapping
    /// claims wins when this method is read side by side with
    /// `SecretRules.scrub`.
    private static func resolveOverlaps(_ spans: [GLiNERSpan]) -> [GLiNERSpan] {
        let sorted = spans.sorted { lhs, rhs in
            if lhs.unicodeScalarStart != rhs.unicodeScalarStart {
                return lhs.unicodeScalarStart < rhs.unicodeScalarStart
            }
            let lhsLength = lhs.unicodeScalarEnd - lhs.unicodeScalarStart
            let rhsLength = rhs.unicodeScalarEnd - rhs.unicodeScalarStart
            return lhsLength > rhsLength
        }
        var accepted: [GLiNERSpan] = []
        var cursor = 0
        for span in sorted where span.unicodeScalarStart >= cursor && span.unicodeScalarEnd > span.unicodeScalarStart {
            accepted.append(span)
            cursor = span.unicodeScalarEnd
        }
        return accepted
    }

    /// Applies non-overlapping, already-sorted spans as `⟨redacted:label⟩`
    /// replacements. Offsets are Unicode-scalar counts (see `GLiNERSpan`),
    /// so this walks `text.unicodeScalars`, never UTF-16 or byte offsets —
    /// mixing units here would silently redact the wrong slice of text.
    private static func applySpans(_ spans: [GLiNERSpan], to text: String) -> (String, Int) {
        guard !spans.isEmpty else { return (text, 0) }
        let scalars = text.unicodeScalars
        var result = String.UnicodeScalarView()
        var cursor = scalars.startIndex
        var applied = 0
        for span in spans {
            guard let start = scalars.index(scalars.startIndex, offsetBy: span.unicodeScalarStart, limitedBy: scalars.endIndex),
                  let end = scalars.index(scalars.startIndex, offsetBy: span.unicodeScalarEnd, limitedBy: scalars.endIndex),
                  start >= cursor, end <= scalars.endIndex, start < end else { continue }
            result.append(contentsOf: scalars[cursor..<start])
            result.append(contentsOf: "\u{27E8}redacted:\(span.label)\u{27E9}".unicodeScalars)
            cursor = end
            applied += 1
        }
        result.append(contentsOf: scalars[cursor...])
        return (String(result), applied)
    }
}
