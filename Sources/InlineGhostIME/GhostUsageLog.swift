import Foundation

/// Opt-in, OFF BY DEFAULT, local-only capture of ghost outcomes: what the owner
/// accepts, dismisses, or types instead of a suggestion. This is ground truth for
/// tuning acceptance-rate metrics against real usage — not a telemetry pipeline.
///
/// Enable with:
///   defaults write com.steadytype.InlineGhostIME GhostUsageCaptureEnabled -bool true
///
/// Privacy: NEVER logs raw typed text or raw ghost text. Only counts, lengths,
/// and (for the one case where the user's own keystroke matters) a coarse
/// redacted character class. Writes go to a local file only — nothing is
/// transmitted anywhere.
enum GhostUsageLog {

    private static let enabledKey = "GhostUsageCaptureEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    enum Event: String {
        case shown
        case acceptWord = "accept_word"
        case acceptAll = "accept_all"
        case dismiss
        case typedInstead = "typed_instead"
    }

    enum Source: String {
        case fast
        case model
    }

    /// Log to iCloud Drive when available so multiple Macs feed one folder the
    /// owner (and their tools) can read; per-host filename keeps machines'
    /// streams separate. Falls back to local Application Support if iCloud is
    /// absent. Redacted events only — never raw text — so this is safe to sync.
    private static let logDirectory: String = {
        let icloud = NSString(string: "~/Library/Mobile Documents/com~apple~CloudDocs/SteadyType-usage")
            .expandingTildeInPath
        let icloudRoot = NSString(string: "~/Library/Mobile Documents/com~apple~CloudDocs")
            .expandingTildeInPath
        if FileManager.default.fileExists(atPath: icloudRoot) { return icloud }
        return NSString(string: "~/Library/Application Support/SteadyType/usage").expandingTildeInPath
    }()

    private static let logPath: String = {
        let host = Host.current().localizedName?
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-") ?? "mac"
        return logDirectory + "/ghost_events_\(host).jsonl"
    }()

    /// Serial + background: file I/O never runs on the keystroke-handling thread,
    /// and concurrent events stay ordered instead of interleaving mid-line.
    private static let queue = DispatchQueue(label: "com.steadytype.ghostUsageLog", qos: .utility)

    /// Touched only from `queue` — safe without a lock.
    private static var didEnsureDirectory = false

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Records one ghost outcome. A no-op unless the owner has explicitly opted
    /// in via `enabledKey`. Crash-proof: every failure along the way is
    /// swallowed — usage capture must never be able to disrupt typing.
    ///
    /// `typedChar`, when present, is reduced to a coarse class (letter / digit /
    /// space / punct / other) BEFORE it ever leaves this call frame. The raw
    /// character is never written to disk, logged, or retained.
    static func record(
        event: Event,
        ghostLen: Int,
        source: Source,
        appBundle: String?,
        typedChar: String? = nil
    ) {
        guard isEnabled else { return }
        let redactedSignal = typedChar.map(redactedClass(for:))

        queue.async {
            var fields: [String: Any] = [
                "ts": iso8601.string(from: Date()),
                "event": event.rawValue,
                "ghost_len": ghostLen,
                "source": source.rawValue,
            ]
            if let appBundle { fields["app_bundle"] = appBundle }
            if let redactedSignal { fields["typed_signal"] = redactedSignal }
            appendLine(fields)
        }
    }

    /// Coarse character class only — the character itself is discarded here and
    /// never touches this type's stored state or the log file.
    private static func redactedClass(for chars: String) -> String {
        guard let scalar = chars.unicodeScalars.first else { return "other" }
        if CharacterSet.whitespacesAndNewlines.contains(scalar) { return "space" }
        if CharacterSet.decimalDigits.contains(scalar) { return "digit" }
        if CharacterSet.letters.contains(scalar) { return "letter" }
        if CharacterSet.punctuationCharacters.contains(scalar) || CharacterSet.symbols.contains(scalar) {
            return "punct"
        }
        return "other"
    }

    /// Runs on `queue` only. Best-effort append; any failure is silently
    /// dropped rather than surfaced, by design.
    private static func appendLine(_ fields: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: fields) else { return }
        var line = data
        line.append(0x0A)

        if !didEnsureDirectory {
            try? FileManager.default.createDirectory(
                atPath: logDirectory,
                withIntermediateDirectories: true
            )
            didEnsureDirectory = true
        }

        guard let handle = FileHandle(forWritingAtPath: logPath) else {
            _ = FileManager.default.createFile(atPath: logPath, contents: line)
            return
        }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: line)
    }
}
