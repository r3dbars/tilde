/// Keeps native editors fast while giving Chromium/Electron marked text enough
/// time to avoid moving the visible caret between keystrokes.
public enum SuggestionRevealDelayPolicy {
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
}
