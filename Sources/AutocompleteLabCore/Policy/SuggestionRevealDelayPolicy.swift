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

    public static func nanoseconds(
        afterUserTyped grapheme: String,
        calmMarkedText: Bool
    ) -> UInt64 {
        let midWord = grapheme.last?.isLetter == true
        if calmMarkedText {
            return midWord ? 120_000_000 : 200_000_000
        }
        return midWord ? 10_000_000 : 50_000_000
    }

    /// Model work always begins with the keystroke. Chromium/Electron only
    /// defer presentation, so their caret-stability workaround does not add
    /// 120–200ms to inference latency.
    public static func schedule(
        afterUserTyped grapheme: String,
        calmMarkedText: Bool
    ) -> Schedule {
        Schedule(
            inferenceDelayNanoseconds: 0,
            revealDelayNanoseconds: nanoseconds(
                afterUserTyped: grapheme,
                calmMarkedText: calmMarkedText
            )
        )
    }
}
