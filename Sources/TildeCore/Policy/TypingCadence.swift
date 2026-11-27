import Foundation

/// Text-free typing speed label written on every ledger event. Raw values
/// are the Lab schema's (`LabTypingSpeedBucket`), so ingest reads them as is.
public enum TextFreeTypingSpeedBucket: String, Codable, CaseIterable, Sendable {
    case slow
    case medium
    case fast
    case unknown

    /// Median inter-keystroke interval below this is a fast typist
    /// (about 80 wpm at five characters a word).
    public static let fastCeilingMilliseconds = 150
    /// Median below this and at or above the fast ceiling is medium
    /// (about 43 to 80 wpm). Anything slower is slow.
    public static let mediumCeilingMilliseconds = 280

    public static func from(medianStrideMilliseconds: Int?) -> TextFreeTypingSpeedBucket {
        guard let median = medianStrideMilliseconds else { return .unknown }
        if median < fastCeilingMilliseconds { return .fast }
        if median < mediumCeilingMilliseconds { return .medium }
        return .slow
    }
}

/// Rolling inter-keystroke interval (IKI) for one keyboard process.
///
/// Times only: no characters, no keys. An interval longer than
/// `strideCeilingMilliseconds` is a hesitation or a pause, not a stride, and
/// stays out of the window so a coffee break cannot make a fast typist look
/// slow. Key auto-repeat should not be fed in; the caller filters it.
public struct TypingCadenceTracker: Equatable, Sendable {
    public static let capacity = 24
    public static let minimumStrides = 4
    public static let strideCeilingMilliseconds = 600

    public private(set) var strides: [Int] = []
    public private(set) var lastKeystrokeUptime: TimeInterval?
    /// The interval that ended at the most recent keystroke, or `nil` after
    /// `breakRun()` or before a second keystroke.
    public private(set) var lastIntervalMilliseconds: Int?

    public init() {}

    public mutating func noteKeystroke(atUptime uptime: TimeInterval) {
        defer { lastKeystrokeUptime = uptime }
        guard let previous = lastKeystrokeUptime, uptime >= previous else {
            lastIntervalMilliseconds = nil
            return
        }
        let interval = Int(((uptime - previous) * 1_000).rounded())
        lastIntervalMilliseconds = interval
        guard interval <= Self.strideCeilingMilliseconds else { return }
        strides.append(interval)
        if strides.count > Self.capacity {
            strides.removeFirst(strides.count - Self.capacity)
        }
    }

    /// Focus moved or the field changed under the writer: the next interval
    /// is not a stride. History is the typist's, so it stays.
    public mutating func breakRun() {
        lastKeystrokeUptime = nil
        lastIntervalMilliseconds = nil
    }

    public var medianStrideMilliseconds: Int? {
        guard strides.count >= Self.minimumStrides else { return nil }
        let sorted = strides.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    /// The 90th-percentile stride: the gap this typist rarely exceeds
    /// mid-burst. The reveal gate scales this, not the median, because a
    /// median-based gate still flashes on the slow tail of a burst.
    public var upperStrideMilliseconds: Int? {
        guard strides.count >= Self.minimumStrides else { return nil }
        let sorted = strides.sorted()
        return sorted[min(sorted.count - 1, sorted.count * 9 / 10)]
    }

    public var speedBucket: TextFreeTypingSpeedBucket {
        .from(medianStrideMilliseconds: medianStrideMilliseconds)
    }

    public func idleMilliseconds(atUptime uptime: TimeInterval) -> Int? {
        guard let last = lastKeystrokeUptime, uptime >= last else { return nil }
        return Int(((uptime - last) * 1_000).rounded())
    }
}

/// H04 refractory cooldown. Consecutive rapid rejects (a ghost typed past
/// before it could be read) or Escape dismissals raise the reveal gate for
/// a bounded number of keystrokes. Accept, a sentence end, or a genuine
/// pause release it at once.
public struct FlowRefractoryState: Equatable, Sendable {
    public enum GhostClose: Equatable, Sendable {
        case accepted
        case dismissed
        /// Hidden by typing that did not follow it.
        case typedPast(visibleMilliseconds: Int)
    }

    public private(set) var rejectStreak = 0
    public private(set) var remainingKeystrokes = 0

    public init() {}

    public var isEngaged: Bool { remainingKeystrokes > 0 }

    public mutating func noteGhostClosed(_ close: GhostClose, policy: FlowRevealPolicy) {
        switch close {
        case .accepted:
            reset()
            return
        case .dismissed:
            rejectStreak += 1
        case let .typedPast(visible):
            if visible < SettledVisibility.minimumReadMilliseconds {
                rejectStreak += 1
            } else {
                // Read, then rejected on purpose: a judgment, not friction.
                rejectStreak = 0
            }
        }
        guard policy.refractoryRejectStreak > 0,
              rejectStreak >= policy.refractoryRejectStreak else { return }
        remainingKeystrokes = max(0, policy.refractoryMaximumKeystrokes)
        rejectStreak = 0
    }

    /// One typed key. `idleBeforeMilliseconds` is the gap since the previous
    /// key, `nil` when unknown.
    public mutating func noteKeystroke(
        endsSentence: Bool,
        idleBeforeMilliseconds: Int?,
        policy: FlowRevealPolicy
    ) {
        if endsSentence {
            reset()
            return
        }
        if let idle = idleBeforeMilliseconds,
           policy.pauseResetMilliseconds > 0,
           idle >= policy.pauseResetMilliseconds {
            reset()
            return
        }
        if remainingKeystrokes > 0 { remainingKeystrokes -= 1 }
    }

    public mutating func reset() {
        rejectStreak = 0
        remainingKeystrokes = 0
    }

    public static func endsSentence(_ grapheme: String) -> Bool {
        guard let last = grapheme.last else { return false }
        return ".!?".contains(last) || last.isNewline
    }
}

/// Flow-aware reveal and mid-word request gate.
///
/// Inference still starts with the keystroke; only presentation waits. A
/// ghost is revealed only once the gap after the latest key outlasts the
/// typist's own rolling stride, so a burst never flashes text between
/// letters, and the reveal is the burst-versus-pause test: the next key of a
/// burst cancels it, a genuine pause lets it through. That holds for the
/// first key after a long pause too, since it usually opens another burst.
/// A chained Tab-to-Tab reveal never waits on cadence. `off` reproduces the
/// fixed calm/native delays exactly.
public struct FlowRevealPolicy: Codable, Equatable, Sendable {
    /// Reveal gate as a percentage of the upper (90th-percentile) stride.
    /// `0` turns cadence gating off.
    public let strideRevealPercent: Int
    public let maximumStrideRevealMilliseconds: Int
    /// Mid-word model request wait as a percentage of the upper stride.
    public let midWordStridePercent: Int
    public let maximumMidWordRequestMilliseconds: Int
    /// Rapid rejects in a row that engage the cooldown. `0` turns H04 off.
    public let refractoryRejectStreak: Int
    public let refractoryRevealMilliseconds: Int
    public let refractoryMaximumKeystrokes: Int
    /// A gap this long ends a cooldown.
    public let pauseResetMilliseconds: Int

    public init(
        strideRevealPercent: Int,
        maximumStrideRevealMilliseconds: Int,
        midWordStridePercent: Int,
        maximumMidWordRequestMilliseconds: Int,
        refractoryRejectStreak: Int,
        refractoryRevealMilliseconds: Int,
        refractoryMaximumKeystrokes: Int,
        pauseResetMilliseconds: Int
    ) {
        self.strideRevealPercent = strideRevealPercent
        self.maximumStrideRevealMilliseconds = maximumStrideRevealMilliseconds
        self.midWordStridePercent = midWordStridePercent
        self.maximumMidWordRequestMilliseconds = maximumMidWordRequestMilliseconds
        self.refractoryRejectStreak = refractoryRejectStreak
        self.refractoryRevealMilliseconds = refractoryRevealMilliseconds
        self.refractoryMaximumKeystrokes = refractoryMaximumKeystrokes
        self.pauseResetMilliseconds = pauseResetMilliseconds
    }

    /// Fixed delays only: what every build did before cadence existed, and
    /// what a keyboard assumes when an older app serves no flow object.
    public static let off = FlowRevealPolicy(
        strideRevealPercent: 0,
        maximumStrideRevealMilliseconds: 0,
        midWordStridePercent: 0,
        maximumMidWordRequestMilliseconds: 0,
        refractoryRejectStreak: 0,
        refractoryRevealMilliseconds: 0,
        refractoryMaximumKeystrokes: 0,
        pauseResetMilliseconds: 0
    )

    /// Reveal after 1.2x the upper stride (at most 300 ms), wait 1.5x it
    /// (at most 360 ms) before a mid-word request, and after two rapid
    /// rejects in a row hold reveals to a 450 ms pause for up to 12 keys.
    public static let production = FlowRevealPolicy(
        strideRevealPercent: 120,
        maximumStrideRevealMilliseconds: 300,
        midWordStridePercent: 150,
        maximumMidWordRequestMilliseconds: 360,
        refractoryRejectStreak: 2,
        refractoryRevealMilliseconds: 450,
        refractoryMaximumKeystrokes: 12,
        pauseResetMilliseconds: 900
    )

    public var isOff: Bool {
        strideRevealPercent <= 0 && midWordStridePercent <= 0 && refractoryRejectStreak <= 0
    }

    /// The reveal delay for one scheduled request. Never shorter than
    /// `baseMilliseconds` (the calm/native floor), and exactly that floor
    /// for a chained accept.
    public func revealMilliseconds(
        baseMilliseconds: Int,
        chained: Bool,
        cadence: TypingCadenceTracker,
        refractory: FlowRefractoryState
    ) -> Int {
        let base = max(0, baseMilliseconds)
        guard !chained else { return base }
        var gate = base
        if strideRevealPercent > 0, let upper = cadence.upperStrideMilliseconds {
            let stride = upper * strideRevealPercent / 100
            gate = max(gate, min(max(base, maximumStrideRevealMilliseconds), stride))
        }
        if refractory.isEngaged, refractoryRevealMilliseconds > 0 {
            gate = max(gate, refractoryRevealMilliseconds)
        }
        return gate
    }

    /// How long a mid-word model request waits before it leaves. Never
    /// shorter than the served throttle.
    public func midWordThrottleMilliseconds(
        baseMilliseconds: Int,
        cadence: TypingCadenceTracker
    ) -> Int {
        let base = max(0, baseMilliseconds)
        guard midWordStridePercent > 0,
              let upper = cadence.upperStrideMilliseconds else { return base }
        let stride = upper * midWordStridePercent / 100
        return max(base, min(max(base, maximumMidWordRequestMilliseconds), stride))
    }
}

/// Chat composers clear the field when Return sends. The span the writer
/// sent is kept, not deleted, so the segment closes on the text as it stood
/// just before the send. Only a field that was non-empty before the commit
/// and is empty (or no longer extends the pre-commit text) after it counts;
/// a Return that adds a newline leaves the pre-commit text in place, and a
/// deletion never goes through this path.
public enum CommitClearRule {
    public enum Verdict: Equatable, Sendable {
        /// The commit sent and cleared the field: close on the pre-commit text.
        case sentAndCleared
        /// The pre-commit text is still there (a newline): keep watching.
        case stillPresent
        /// Cannot tell: no pre-commit text, or no readable field after.
        case unknown
    }

    /// How long after Return to read the field. Electron composers clear
    /// asynchronously, so the first read can still see the old text.
    public static let checkDelaysMilliseconds = [150, 600]

    public static func classify(preCommitWindow: String?, postCommitWindow: String?) -> Verdict {
        guard let before = preCommitWindow, !before.isEmpty,
              let after = postCommitWindow else { return .unknown }
        if after.isEmpty { return .sentAndCleared }
        // A newline in place keeps the pre-commit text as a prefix of what
        // is before the caret now (bounded windows may trim the front).
        let probe = String(before.suffix(64))
        if after.contains(probe) { return .stillPresent }
        return after.count < before.count ? .sentAndCleared : .unknown
    }
}
