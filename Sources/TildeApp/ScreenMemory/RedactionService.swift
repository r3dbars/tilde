import TildeCore
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
        /// failure, timeout, or a malformed/error reply — OR it answered
        /// but handed back a span this text cannot possibly contain
        /// (offsets outside the text, or otherwise structurally invalid;
        /// see `applySpans`). Every one of these collapses to the same
        /// case here on purpose: a caller deciding "drop the capture"
        /// never needs to distinguish them, and a structurally invalid
        /// span is just as much "the model layer cannot be trusted for
        /// this call" as a timeout is — applying every OTHER span while
        /// silently skipping the bad one would be a rules-only-style
        /// partial redaction wearing a `.redacted` label, which the
        /// covenant's fail-closed requirement forbids just as much as it
        /// forbids trusting an unavailable model layer.
        /// `GLiNERRedactionHelperHost` already logs the specific
        /// unavailable reason to diagnostics (count-only, no text) before
        /// this point.
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

        guard !ruleClean.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // Nothing left to scan after the rules layer — either the
            // caller passed empty/whitespace-only text, or `SecretRules`
            // already scrubbed the whole capture clean. Either way there
            // is nothing for the model layer to look at, so this is a
            // normal "trivially clean" result. Short-circuiting here (the
            // redaction HOST, before ever reaching the helper process)
            // means an empty/blank capture can never trigger the model
            // layer's "missing-text" reply in the first place — see
            // `GLiNERRedactionHelperHost.detectSpans` for the matching
            // defense-in-depth on that reply, kept in case some other
            // caller of the model layer skips this guard.
            return .redacted(RedactedText(text: ruleClean, ruleFindings: ruleFindings, modelSpanCount: 0))
        }

        guard let rawSpans = await spanDetector.detectSpans(in: ruleClean) else {
            return .dropped(.modelUnavailable)
        }

        let accepted = Self.resolveOverlaps(
            rawSpans.filter { $0.score >= spanConfidenceThreshold }
        )
        guard let (modelClean, appliedCount) = Self.applySpans(accepted, to: ruleClean) else {
            // A structurally invalid span (offsets outside `ruleClean`,
            // or otherwise unrepresentable) means the model layer's
            // reply cannot be trusted for this call. Fail the WHOLE
            // capture closed — never apply the other, valid-looking
            // spans and ship a partial redaction under a `.redacted`
            // label.
            return .dropped(.modelUnavailable)
        }

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
    ///
    /// Returns `nil` — never a partial result — the moment ANY span turns
    /// out to be structurally invalid for `text` (offsets past the end,
    /// non-monotonic, zero/negative width, or overlapping a span already
    /// applied). `resolveOverlaps` already screens out same-batch overlaps
    /// and empty spans using the offsets the model reported, but it cannot
    /// know whether those offsets actually fit `text` — only this loop,
    /// which walks the real scalar view, can catch an out-of-range span.
    /// Silently `continue`-ing past a bad span here would apply every
    /// OTHER span and return `.redacted` anyway: a partial redaction with
    /// the bad span's text left in the clear, indistinguishable from a
    /// fully-clean result to any caller that doesn't inspect
    /// `modelSpanCount`. The covenant requires fail-closed, so the caller
    /// (`redact`) treats `nil` here exactly like a model-unavailable
    /// reply: drop the whole capture.
    private static func applySpans(_ spans: [GLiNERSpan], to text: String) -> (String, Int)? {
        guard !spans.isEmpty else { return (text, 0) }
        let scalars = text.unicodeScalars
        var result = String.UnicodeScalarView()
        var cursor = scalars.startIndex
        var applied = 0
        for span in spans {
            guard let start = scalars.index(scalars.startIndex, offsetBy: span.unicodeScalarStart, limitedBy: scalars.endIndex),
                  let end = scalars.index(scalars.startIndex, offsetBy: span.unicodeScalarEnd, limitedBy: scalars.endIndex),
                  start >= cursor, end <= scalars.endIndex, start < end else {
                return nil
            }
            result.append(contentsOf: scalars[cursor..<start])
            result.append(contentsOf: "\u{27E8}redacted:\(span.label)\u{27E9}".unicodeScalars)
            cursor = end
            applied += 1
        }
        result.append(contentsOf: scalars[cursor...])
        return (String(result), applied)
    }
}
