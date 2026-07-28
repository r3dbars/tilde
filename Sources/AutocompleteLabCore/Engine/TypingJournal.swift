import Foundation

/// Policy pieces for the full typing journal ("one diary, two readers":
/// the raw stream feeds training/matchmaker; a nightly organizer distills
/// markdown for agents). Pure logic lives here so it is testable; the IME
/// owns only the wiring.
///
/// Privacy invariants (owner decision 2026-07-28):
/// - Secure fields never reach this code (macOS excludes input methods from
///   password entry at the OS level; the IME additionally never journals
///   muted apps).
/// - Everything written passes through `SensitiveTextScrubber` first.
/// - The journal is opt-in (its own flag, separate from suggestion capture)
///   and, for customers, off by default.

/// Redacts high-risk substrings before anything is persisted. Deliberately
/// conservative: better to redact a tracking number than to store a card.
public enum SensitiveTextScrubber {

    /// Runs of 13-19 digits (allowing space/dash separators) — card shaped.
    private static let cardLike = try! NSRegularExpression(
        pattern: #"\b\d(?:[ -]?\d){12,18}\b"#
    )
    /// US SSN shape: 3-2-4 with dashes (bare 9-digit runs are caught by the
    /// long-digit rule below).
    private static let ssnLike = try! NSRegularExpression(
        pattern: #"\b\d{3}-\d{2}-\d{4}\b"#
    )
    /// Any bare digit run of 9+ — account numbers, SSNs without dashes.
    private static let longDigits = try! NSRegularExpression(
        pattern: #"\b\d{9,}\b"#
    )

    public static func scrub(_ text: String) -> String {
        var result = text
        for expression in [cardLike, ssnLike, longDigits] {
            let range = NSRange(result.startIndex..., in: result)
            result = expression.stringByReplacingMatches(
                in: result, range: range, withTemplate: "[redacted]"
            )
        }
        return result
    }
}

/// Accumulates one field's typing into flushable entries. Pure state
/// machine: the IME feeds characters and asks "should I flush?"; the buffer
/// never does I/O.
public struct TypingJournalBuffer: Sendable {

    /// Entries shorter than this are noise (a stray "ok" in a search box),
    /// not writing worth remembering.
    public static let minimumFlushCharacters = 12
    /// Bound per-entry size; long documents flush in chunks.
    public static let maximumBufferCharacters = 2_000
    /// A pause this long ends a thought; the caller flushes on its timer.
    public static let idleFlushSeconds: TimeInterval = 90

    public private(set) var text = ""
    public private(set) var lastActivity: Date?

    public init() {}

    public mutating func append(_ characters: String, at now: Date = Date()) {
        text += characters
        lastActivity = now
        if text.count > Self.maximumBufferCharacters + 500 {
            text = String(text.suffix(Self.maximumBufferCharacters + 500))
        }
    }

    public mutating func backspace(at now: Date = Date()) {
        if !text.isEmpty { text.removeLast() }
        lastActivity = now
    }

    /// True when the buffer holds enough to be worth writing.
    public var isFlushWorthy: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).count >= Self.minimumFlushCharacters
    }

    public var isOverSizeCap: Bool {
        text.count >= Self.maximumBufferCharacters
    }

    public func isIdle(at now: Date = Date()) -> Bool {
        guard let last = lastActivity else { return false }
        return now.timeIntervalSince(last) >= Self.idleFlushSeconds
    }

    /// Takes the scrubbed entry text and resets. Returns nil when the
    /// content wasn't worth keeping.
    public mutating func flush() -> String? {
        defer { text = ""; lastActivity = nil }
        guard isFlushWorthy else { return nil }
        return SensitiveTextScrubber.scrub(
            text.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
