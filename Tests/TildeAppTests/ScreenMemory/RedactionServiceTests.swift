import Foundation
import Testing
@testable import TildeApp
import TildeCore

private final class LockedBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value

    init(_ initial: Value) { storage = initial }

    var value: Value {
        get { lock.lock(); defer { lock.unlock() }; return storage }
        set { lock.lock(); storage = newValue; lock.unlock() }
    }
}

private struct FakeSpanDetector: GLiNERSpanDetecting {
    enum Behavior: Sendable {
        case spans([GLiNERSpan])
        case unavailable
    }

    let behavior: Behavior
    let onDetect: (@Sendable (String) -> Void)?

    init(_ behavior: Behavior, onDetect: (@Sendable (String) -> Void)? = nil) {
        self.behavior = behavior
        self.onDetect = onDetect
    }

    func detectSpans(in text: String) async -> [GLiNERSpan]? {
        onDetect?(text)
        switch behavior {
        case let .spans(spans): return spans
        case .unavailable: return nil
        }
    }
}

@Suite("Redaction service")
struct RedactionServiceTests {
    @Test("Model layer unavailable drops the capture, even when rules already found nothing")
    func modelUnavailableAlwaysDrops() async {
        let service = RedactionService(spanDetector: FakeSpanDetector(.unavailable))
        let outcome = await service.redact("just some ordinary text, nothing sensitive here")
        #expect(outcome == .dropped(.modelUnavailable))
    }

    @Test("Model layer unavailable drops even when rules already redacted a structured secret — never a rules-only partial result")
    func modelUnavailableDropsEvenWithRuleFindings() async {
        let service = RedactionService(spanDetector: FakeSpanDetector(.unavailable))
        let outcome = await service.redact("my SSN is 219-09-9999, call me back")
        #expect(outcome == .dropped(.modelUnavailable))
    }

    @Test("Rules run first: a structured secret is gone before the model layer ever sees it")
    func rulesRunBeforeModelSees() async {
        let seenText = LockedBox<String?>(nil)
        let detector = FakeSpanDetector(.spans([]), onDetect: { text in seenText.value = text })
        let service = RedactionService(spanDetector: detector)
        let outcome = await service.redact("card 4539 1488 0343 6467 please charge it")
        guard case let .redacted(result) = outcome else { Issue.record("expected redacted"); return }
        #expect(!result.text.contains("4539 1488 0343 6467"))
        #expect(result.ruleFindings.map(\.type) == [.creditCard])
        #expect(seenText.value?.contains("4539 1488 0343 6467") == false)
    }

    @Test("Model spans below the confidence threshold are ignored")
    func belowThresholdSpansAreIgnored() async {
        let text = "hi Priya, see you Friday"
        let lowConfidence = GLiNERSpan(unicodeScalarStart: 3, unicodeScalarEnd: 8, label: "person_name", score: 0.2)
        let service = RedactionService(spanDetector: FakeSpanDetector(.spans([lowConfidence])))
        let outcome = await service.redact(text)
        guard case let .redacted(result) = outcome else { Issue.record("expected redacted"); return }
        #expect(result.text == text)
        #expect(result.modelSpanCount == 0)
    }

    @Test("A span at exactly the threshold is redacted (>=, not >)")
    func atThresholdSpanIsRedacted() async {
        let text = "hi Priya, see you Friday"
        let scalars = Array(text.unicodeScalars)
        let start = 3
        let end = 8
        #expect(String(String.UnicodeScalarView(scalars[start..<end])) == "Priya")
        let atThreshold = GLiNERSpan(unicodeScalarStart: start, unicodeScalarEnd: end, label: "person_name", score: 0.5)
        let service = RedactionService(spanDetector: FakeSpanDetector(.spans([atThreshold])))
        let outcome = await service.redact(text)
        guard case let .redacted(result) = outcome else { Issue.record("expected redacted"); return }
        #expect(!result.text.contains("Priya"))
        #expect(result.text.contains("\u{27E8}redacted:person_name\u{27E9}"))
        #expect(result.modelSpanCount == 1)
    }

    @Test("Overlapping model spans: earliest-then-longest wins, matching SecretRules' own tie-break")
    func overlappingSpansResolveEarliestThenLongest() async {
        let text = "contact John Smith today"
        // "John" (5-9) and "John Smith" (5-15) overlap; the longer one
        // starting at the same offset should win.
        let short = GLiNERSpan(unicodeScalarStart: 8, unicodeScalarEnd: 12, label: "person_name", score: 0.9)
        let long = GLiNERSpan(unicodeScalarStart: 8, unicodeScalarEnd: 18, label: "person_name", score: 0.9)
        let service = RedactionService(spanDetector: FakeSpanDetector(.spans([short, long])))
        let outcome = await service.redact(text)
        guard case let .redacted(result) = outcome else { Issue.record("expected redacted"); return }
        #expect(result.modelSpanCount == 1)
        #expect(!result.text.contains("Smith"))
    }

    @Test("Empty text short-circuits to a trivially-clean result and never reaches the model layer")
    func emptyTextShortCircuitsWithoutCallingModelLayer() async {
        let called = LockedBox(false)
        let detector = FakeSpanDetector(.spans([]), onDetect: { _ in called.value = true })
        let service = RedactionService(spanDetector: detector)
        let outcome = await service.redact("")
        guard case let .redacted(result) = outcome else { Issue.record("expected redacted, not dropped"); return }
        #expect(result.text.isEmpty)
        #expect(result.modelSpanCount == 0)
        #expect(!called.value, "empty text must never reach the model layer — a well-formed missing-text reply must not be able to markBroken() the whole session")
    }

    @Test("Whitespace-only text short-circuits to a trivially-clean result and never reaches the model layer")
    func whitespaceOnlyTextShortCircuitsWithoutCallingModelLayer() async {
        let called = LockedBox(false)
        let detector = FakeSpanDetector(.spans([]), onDetect: { _ in called.value = true })
        let service = RedactionService(spanDetector: detector)
        let outcome = await service.redact("   \n\t  ")
        guard case .redacted = outcome else { Issue.record("expected redacted, not dropped"); return }
        #expect(!called.value)
    }

    @Test("A structurally invalid span (offsets past the end of the text) drops the WHOLE capture, never a partial redaction")
    func malformedSpanDropsWholeCapture() async {
        let text = "hi Priya, see you Friday"
        // Way past the end of `text` — a malformed/out-of-range reply from
        // the model layer, as if the helper mis-scored offsets for a
        // different (longer) input than the one it was actually given.
        let outOfRange = GLiNERSpan(unicodeScalarStart: 500, unicodeScalarEnd: 900, label: "person_name", score: 0.9)
        let service = RedactionService(spanDetector: FakeSpanDetector(.spans([outOfRange])))
        let outcome = await service.redact(text)
        #expect(outcome == .dropped(.modelUnavailable))
    }

    @Test("One malformed span drops the capture even alongside other well-formed, valid spans — no partial redaction")
    func malformedSpanDropsCaptureEvenWithOtherValidSpans() async {
        let text = "hi Priya, see you Friday"
        let scalars = Array(text.unicodeScalars)
        let validStart = 3
        let validEnd = 8
        #expect(String(String.UnicodeScalarView(scalars[validStart..<validEnd])) == "Priya")
        let valid = GLiNERSpan(unicodeScalarStart: validStart, unicodeScalarEnd: validEnd, label: "person_name", score: 0.9)
        let malformed = GLiNERSpan(unicodeScalarStart: 500, unicodeScalarEnd: 900, label: "person_name", score: 0.9)
        let service = RedactionService(spanDetector: FakeSpanDetector(.spans([valid, malformed])))
        let outcome = await service.redact(text)
        #expect(outcome == .dropped(.modelUnavailable))
    }

    @Test("Redaction result never contains the raw scrubbed secret substring in any field")
    func redactionResultCarriesNoRawSecret() async {
        let service = RedactionService(spanDetector: FakeSpanDetector(.spans([])))
        let outcome = await service.redact("email me at real.person@example.com or call 415-555-0199")
        guard case let .redacted(result) = outcome else { Issue.record("expected redacted"); return }
        #expect(!result.text.contains("real.person@example.com"))
        #expect(!result.text.contains("415-555-0199"))
    }
}
