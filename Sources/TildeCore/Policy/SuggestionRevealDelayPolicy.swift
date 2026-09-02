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

    /// `chained` marks a request issued by an accept rather than a
    /// keystroke: no key is being processed, so the shorter mid-word wait is
    /// enough to keep a Chromium caret still, and every millisecond here is
    /// dead air between one Tab and the next ghost.
    public static func nanoseconds(
        afterUserTyped grapheme: String,
        calmMarkedText: Bool,
        chained: Bool = false
    ) -> UInt64 {
        let short = chained || grapheme.last?.isLetter == true
        if calmMarkedText {
            return short ? 120_000_000 : 200_000_000
        }
        return short ? 10_000_000 : 50_000_000
    }

    /// Model work always begins with the keystroke. Chromium/Electron only
    /// defer presentation, so their caret-stability workaround does not add
    /// 120–200ms to inference latency.
    public static func schedule(
        afterUserTyped grapheme: String,
        calmMarkedText: Bool,
        chained: Bool = false
    ) -> Schedule {
        Schedule(
            inferenceDelayNanoseconds: 0,
            revealDelayNanoseconds: nanoseconds(
                afterUserTyped: grapheme,
                calmMarkedText: calmMarkedText,
                chained: chained
            )
        )
    }
}
