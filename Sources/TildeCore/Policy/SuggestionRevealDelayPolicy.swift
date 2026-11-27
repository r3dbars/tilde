/// Keeps native editors fast while giving Chromium/Electron marked text enough
/// time to avoid moving the visible caret between keystrokes.
public enum SuggestionRevealDelayPolicy {
    public struct Schedule: Equatable, Sendable {
        public let inferenceDelayNanoseconds: UInt64
        public let revealDelayNanoseconds: UInt64

        public init(inferenceDelayNanoseconds: UInt64, revealDelayNanoseconds: UInt64) {
            self.inferenceDelayNanoseconds = inferenceDelayNanoseconds
            self.revealDelayNanoseconds = revealDelayNanoseconds
        }
    }

    private static let chromiumBundlePrefixes = [
        "com.google.Chrome", "com.microsoft.edgemac", "com.brave.Browser",
        "company.thebrowser.Browser", "com.openai.atlas", "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera",
    ]

    public static func requiresCalmMarkedText(
        bundleIdentifier: String,
        hasElectronFramework: Bool
    ) -> Bool {
        hasElectronFramework
            || chromiumBundlePrefixes.contains(where: bundleIdentifier.hasPrefix)
    }

    /// How long a Chromium/Electron host is given after a keystroke before
    /// marked text is set. The production pair is the measured floor that
    /// stopped visible caret ping-pong. The preview pair is the owner's
    /// 2026-09-02 trial: in the daily-driver apps (all Electron) this floor
    /// was the largest fixed delay left on every ghost, and chained
    /// requests had already run at the shorter value without jitter.
    public struct CalmDelays: Equatable, Sendable {
        public let postSpaceNanoseconds: UInt64
        public let midWordNanoseconds: UInt64
        public let chainedNanoseconds: UInt64

        public init(
            postSpaceNanoseconds: UInt64,
            midWordNanoseconds: UInt64,
            chainedNanoseconds: UInt64 = 40_000_000
        ) {
            self.postSpaceNanoseconds = postSpaceNanoseconds
            self.midWordNanoseconds = midWordNanoseconds
            self.chainedNanoseconds = chainedNanoseconds
        }

        public static let production = CalmDelays(
            postSpaceNanoseconds: 120_000_000,
            midWordNanoseconds: 110_000_000,
            chainedNanoseconds: 40_000_000
        )
        public static let preview = CalmDelays(
            postSpaceNanoseconds: 100_000_000,
            midWordNanoseconds: 90_000_000,
            chainedNanoseconds: 40_000_000
        )
    }

    /// `chained` marks a request issued by an accept rather than a
    /// keystroke: no key is being processed, so native editors reveal
    /// immediately (0 ms) and Chromium/Electron hosts use the short chained
    /// floor (40 ms) so Tab-to-Tab flow feels instant while normal typing
    /// waits for a genuine micro-pause instead of flashing mid-stride.
    public static func nanoseconds(
        afterUserTyped grapheme: String,
        calmMarkedText: Bool,
        chained: Bool = false,
        calm: CalmDelays = .production
    ) -> UInt64 {
        if chained {
            return calmMarkedText ? calm.chainedNanoseconds : 0
        }
        let isLetter = grapheme.last?.isLetter == true
        if calmMarkedText {
            return isLetter ? calm.midWordNanoseconds : calm.postSpaceNanoseconds
        }
        return isLetter ? 60_000_000 : 45_000_000
    }

    /// Model work always begins with the keystroke. Chromium/Electron only
    /// defer presentation, so their caret-stability workaround does not add
    /// 120–200ms to inference latency.
    public static func schedule(
        afterUserTyped grapheme: String,
        calmMarkedText: Bool,
        chained: Bool = false,
        calm: CalmDelays = .production
    ) -> Schedule {
        Schedule(
            inferenceDelayNanoseconds: 0,
            revealDelayNanoseconds: nanoseconds(
                afterUserTyped: grapheme,
                calmMarkedText: calmMarkedText,
                chained: chained,
                calm: calm
            )
        )
    }
}
