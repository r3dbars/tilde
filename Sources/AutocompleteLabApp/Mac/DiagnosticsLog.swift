import Foundation
import AutocompleteLabCore

final class DiagnosticsLog: @unchecked Sendable {
    static let shared = DiagnosticsLog()

    private let queue = DispatchQueue(label: "bar.r3d.tilde.diagnostics")
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
                // Owner-only directory and file.
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
            .map(DiagnosticsMetadataRedactor.logSafeField)
            .joined(separator: " ")
        let safeEvent = DiagnosticsMetadataRedactor.logSafeEvent(event)

        if fields.isEmpty {
            return "\(timestamp) \(safeEvent)\n"
        }

        return "\(timestamp) \(safeEvent) \(fields)\n"
    }
}
