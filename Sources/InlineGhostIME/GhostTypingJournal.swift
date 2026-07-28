import AutocompleteLabCore
import Foundation

/// The full typing journal: everything the owner writes (ghost-assisted or
/// not), accumulated per field and flushed as scrubbed entries — the raw
/// stream that feeds training, the matchmaker's memory, and (later) the
/// daily markdown the agent layer reads.
///
/// Deliberately rides the SAME switch as suggestion capture
/// (GhostUsageCaptureEnabled): one consent, one concept — "Learns from
/// typing" (owner decision 2026-07-28: no separate journal mode).
///
/// PRIVACY: secure fields never reach input methods (macOS structural
/// guarantee); muted apps are excluded by the caller; every entry passes
/// SensitiveTextScrubber before persisting; storage is the owner's own
/// SteadyType-usage folder alongside the existing capture. Purge = delete
/// the folder; stop = flip the toggle.
enum GhostTypingJournal {

    private static let queue = DispatchQueue(label: "com.steadytype.typingJournal", qos: .utility)

    /// One buffer per (app, field) so interleaved windows don't garble each
    /// other. Bounded; stale fields are flushed when the map grows.
    private static var buffers: [String: TypingJournalBuffer] = [:]
    private static var bufferApps: [String: String] = [:]

    /// LOCAL-ONLY by design (2026-07-28): every keyboard re-sign invalidates
    /// its iCloud TCC grant, which silently killed captures for hours. The
    /// keyboard now writes only where it needs no permission; the app (which
    /// holds the user's iCloud consent and is always running) ferries new
    /// bytes to the synced folder. Minimal privileges for the keystroke path.
    private static let logDirectory =
        NSString(string: "~/Library/Application Support/SteadyType/usage").expandingTildeInPath

    private static let logPath: String = {
        let host = Host.current().localizedName?
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-") ?? "mac"
        return logDirectory + "/typing_journal_\(host).jsonl"
    }()

    private static func key(app: String?, field: String?) -> String {
        // Key by app ONLY. IMKit's uniqueClientIdentifierString is NOT stable
        // across callbacks (proven live on macOS 26: every keystroke returned
        // a fresh id, shattering text into 1-char buffers that never reached
        // the flush floor). The field parameter stays in the API for call-site
        // clarity but must not participate in identity.
        _ = field
        return app ?? "-"
    }

    // MARK: - Feeding (called from the keystroke path; hops queues immediately)

    static func typed(_ characters: String, app: String?, field: String?) {
        guard GhostUsageLog.isEnabled else { return }
        queue.async {
            let k = key(app: app, field: field)
            // Sweep ALL idle buffers first — including this field's own: a
            // keystroke after a long gap starts a new thought, so the stale
            // text flushes before the new text lands. This is the safety net
            // that works even when IMKit never delivers a focus callback
            // (deactivateServer is not reliably called on app switch).
            for existing in Array(buffers.keys) {
                if buffers[existing]?.isIdle() == true { flushLocked(existing) }
            }
            buffers[k, default: TypingJournalBuffer()].append(characters)
            bufferApps[k] = app ?? "-"
            if buffers[k]?.isOverSizeCap == true {
                flushLocked(k)
            }
            if buffers.count > 12 { flushAllLocked() }
        }
    }

    static func backspace(app: String?, field: String?) {
        guard GhostUsageLog.isEnabled else { return }
        queue.async {
            buffers[key(app: app, field: field)]?.backspace()
        }
    }

    /// Focus moved (app switch, field switch, deactivate) — every open
    /// thought is over. Flush all buffers rather than trusting IMKit to hand
    /// back the same field identity it gave us at typing time.
    static func focusChanged() {
        guard GhostUsageLog.isEnabled else { return }
        queue.async {
            flushAllLocked()
        }
    }

    // MARK: - Writing (queue-confined)

    private static func flushLocked(_ k: String) {
        guard var buffer = buffers[k], let entry = buffer.flush() else {
            buffers[k] = nil; bufferApps[k] = nil
            return
        }
        buffers[k] = nil
        let record: [String: Any] = [
            "ts": ISO8601DateFormatter().string(from: Date()),
            "app_bundle": bufferApps[k] ?? "-",
            "text": entry,
        ]
        bufferApps[k] = nil
        write(record)
    }

    private static func flushAllLocked() {
        for k in Array(buffers.keys) { flushLocked(k) }
    }

    private static func write(_ record: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: record) else { return }
        try? FileManager.default.createDirectory(
            atPath: logDirectory, withIntermediateDirectories: true
        )
        guard let handle = FileHandle(forWritingAtPath: logPath) ?? {
            FileManager.default.createFile(atPath: logPath, contents: nil)
            return FileHandle(forWritingAtPath: logPath)
        }() else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
        try? handle.write(contentsOf: Data("\n".utf8))
    }
}
