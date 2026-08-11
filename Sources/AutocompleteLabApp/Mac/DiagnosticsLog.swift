import Foundation
import AutocompleteLabCore

final class DiagnosticsLog: @unchecked Sendable {
    static let shared = DiagnosticsLog()

    private let queue = DispatchQueue(label: "app.transcripted.autocomplete.diagnostics-log")
    private let logURL: URL
    private let timestampFormatter = ISO8601DateFormatter()

    private init() {
        logURL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Tilde/diagnostics.log")
    }

    func record(_ event: String, metadata: [String: String] = [:]) {
        queue.async { [self, logURL] in
            do {
                let line = format(event: event, metadata: metadata)
                // Owner-only (0700 dir / 0600 file). See docs/security/threat-model.md (F2).
                SecureLocalStorage.createDirectory(at: logURL.deletingLastPathComponent())
                SecureLocalStorage.ensureFile(at: logURL)

                let handle = try FileHandle(forWritingTo: logURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
                try handle.close()
            } catch {
                // Logging must never affect typing.
            }
        }
    }

    /// Blocks until every already-recorded event has reached disk. For
    /// shutdown paths only: an exit racing the async queue would drop the
    /// final events — exactly the crash-vs-quit ambiguity they exist to solve.
    func flush() {
        queue.sync {}
    }

    private func format(event: String, metadata: [String: String]) -> String {
        let timestamp = timestampFormatter.string(from: Date())
        let fields = metadata
            .sorted { $0.key < $1.key }
            .map {
                "\($0.key)=\(DiagnosticsMetadataRedactor.logSafeValue(forKey: $0.key, value: $0.value))"
            }
            .joined(separator: " ")

        if fields.isEmpty {
            return "\(timestamp) \(sanitize(event))\n"
        }

        return "\(timestamp) \(sanitize(event)) \(fields)\n"
    }

    private func sanitize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
    }
}
