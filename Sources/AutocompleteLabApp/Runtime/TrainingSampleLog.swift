import Foundation

/// Owner-opt-in training capture on the BRAIN side: for every suggestion the
/// engine produces, record the full situation it saw — typed context AND the
/// screen text attached to the prompt — plus what it guessed. Joined with the
/// keyboard's accept/typed-instead events (by timestamp + app), this yields
/// training examples with inference-identical context: (screen + typed) -> what
/// the owner actually wrote.
///
/// PRIVACY: raw text, by the owner's explicit choice, written only to the
/// owner's own iCloud Drive (same folder as the keyboard's capture). Gated by
/// the same flag as the keyboard capture; disable either by setting
/// GhostUsageCaptureEnabled=false in the IME's defaults domain.
enum TrainingSampleLog {

    private static var enabled: Bool {
        UserDefaults(suiteName: "bar.r3d.inputmethod.InlineGhost")?
            .bool(forKey: "GhostUsageCaptureEnabled") ?? false
    }

    private static let logURL: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let icloud = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        let directory = FileManager.default.fileExists(atPath: icloud.path)
            ? icloud.appendingPathComponent("SteadyType-usage", isDirectory: true)
            : home.appendingPathComponent("Library/Application Support/SteadyType/usage", isDirectory: true)
        let host = (Host.current().localizedName ?? "mac")
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        return directory.appendingPathComponent("brain_samples_\(host).jsonl")
    }()

    private static let queue = DispatchQueue(label: "com.steadytype.trainingSampleLog", qos: .utility)

    /// Touched only from `queue` — serial confinement stands in for Sendable.
    nonisolated(unsafe) private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Best-effort, never blocks the suggestion path, silently drops on failure.
    static func record(
        appBundle: String?,
        mode: String,
        typedContext: String,
        screenContext: String?,
        suggestion: String,
        firstTokenProbability: Double?
    ) {
        guard enabled, !suggestion.isEmpty else { return }
        let now = Date()
        let context = String(typedContext.suffix(400))
        let screen = screenContext.map { String($0.suffix(700)) } ?? ""
        let probability = firstTokenProbability.map { String(format: "%.3f", $0) } ?? ""
        let bundle = appBundle ?? ""
        queue.async {
            let entry: [String: Any] = [
                "ts": iso8601.string(from: now),
                "app_bundle": bundle,
                "mode": mode,
                "context": context,
                "screen": screen,
                "suggestion": suggestion,
                "p_first": probability,
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: entry) else { return }
            var line = data
            line.append(0x0A)
            try? FileManager.default.createDirectory(
                at: logURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if let handle = FileHandle(forWritingAtPath: logURL.path) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: line)
            } else {
                _ = FileManager.default.createFile(atPath: logURL.path, contents: line)
            }
        }
    }
}
