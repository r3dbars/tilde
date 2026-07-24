import Foundation

/// Opt-in capture of ghost outcomes: what the owner accepts, dismisses, or types
/// instead of a suggestion. Ground truth for BOTH acceptance metrics AND future
/// personalization — the (context -> what I actually wrote) pairs and accept/
/// reject labels this produces are the richest training + quiz data available.
///
/// PRIVACY (owner-configured, personal build): this DOES log raw text — the
/// context, the suggestion, and the accepted/typed text — by the owner's explicit
/// choice, for personalizing THEIR own model. It syncs to the owner's own iCloud
/// Drive (their private account) so both their Macs feed one folder. It is never
/// sent anywhere else. Disable anytime by setting the flag to false; purge by
/// deleting the SteadyType-usage folder.
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

    /// Records one ghost outcome with raw text for training/quiz use. A no-op
    /// unless the owner has opted in via `enabledKey`. Crash-proof: every failure
    /// is swallowed — capture must never disrupt typing.
    ///
    /// `context` is the text before the cursor (what the writer had typed — the
    /// "prompt"); `ghostText` is the suggestion shown; `accepted` is the portion
    /// actually taken (for accept events); `typedChar` is the character typed when
    /// a suggestion was passed over. Context is bounded to a recent tail.
    static func record(
        event: Event,
        ghostText: String,
        source: Source,
        appBundle: String?,
        context: String? = nil,
        accepted: String? = nil,
        typedChar: String? = nil
    ) {
        guard isEnabled else { return }
        let boundedContext = context.map { String($0.suffix(280)) }

        queue.async {
            var fields: [String: Any] = [
                "ts": iso8601.string(from: Date()),
                "event": event.rawValue,
                "ghost": ghostText,
                "ghost_len": ghostText.count,
                "source": source.rawValue,
            ]
            if let appBundle { fields["app_bundle"] = appBundle }
            if let boundedContext { fields["context"] = boundedContext }
            if let accepted { fields["accepted"] = accepted }
            if let typedChar { fields["typed"] = typedChar }
            appendLine(fields)
        }
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
