/// Keeps native editors fast while giving Chromium/Electron suggestion surfaces
/// enough time to avoid moving the visible caret between keystrokes.
public enum SuggestionRevealDelayPolicy {
    public static func requiresCalmMarkedText(
        bundleIdentifier: String,
        hasElectronFramework: Bool
    ) -> Bool {
        CommitUnsafeHostPolicy.requiresExternalSurface(
            bundleIdentifier: bundleIdentifier,
            hasElectronFramework: hasElectronFramework
        )
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
}
