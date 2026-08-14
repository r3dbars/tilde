/// Hosts where inline marked text is unsafe because Blink can commit an active
/// composition renderer-side on focus changes without calling the input method.
/// These hosts must render suggestions outside the document.
public enum CommitUnsafeHostPolicy {
    public static let chromiumBrowserPrefixes = [
        "com.google.Chrome", "com.microsoft.edgemac", "com.brave.Browser",
        "company.thebrowser.Browser", "com.openai.atlas",
        "com.vivaldi.Vivaldi", "com.operasoftware.Opera",
        "org.chromium.Chromium",
    ]

    public static func requiresExternalSurface(
        bundleIdentifier: String,
        hasElectronFramework: Bool
    ) -> Bool {
        hasElectronFramework
            || chromiumBrowserPrefixes.contains(where: bundleIdentifier.hasPrefix)
    }
}
