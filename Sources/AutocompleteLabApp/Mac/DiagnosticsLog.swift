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
            .appendingPathComponent("Library/Logs/SteadyType/diagnostics.log")
    }

    var path: String {
        logURL.path
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

    func recentLines(limit: Int) -> [String] {
        queue.sync { [logURL] in
            guard limit > 0,
                  let contents = try? String(contentsOf: logURL, encoding: .utf8) else {
                return []
            }

            return contents
                .split(separator: "\n", omittingEmptySubsequences: true)
                .suffix(limit)
                .map(String.init)
        }
    }

    func deleteAll() {
        queue.sync { [logURL] in
            try? FileManager.default.removeItem(at: logURL)
        }
    }

    private func format(event: String, metadata: [String: String]) -> String {
        let timestamp = timestampFormatter.string(from: Date())
        let fields = metadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\(RedactionLayer.logSafeValue(forKey: $0.key, value: $0.value))" }
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
