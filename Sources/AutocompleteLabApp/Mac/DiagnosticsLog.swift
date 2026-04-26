import Foundation

final class DiagnosticsLog: @unchecked Sendable {
    static let shared = DiagnosticsLog()

    private let queue = DispatchQueue(label: "app.transcripted.autocomplete.diagnostics-log")
    private let logURL: URL

    private init() {
        logURL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/AutocompleteLab/diagnostics.log")
    }

    func record(_ event: String, metadata: [String: String] = [:]) {
        let line = format(event: event, metadata: metadata)

        queue.async { [logURL] in
            do {
                let fileManager = FileManager.default
                try fileManager.createDirectory(
                    at: logURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )

                if !fileManager.fileExists(atPath: logURL.path) {
                    fileManager.createFile(atPath: logURL.path, contents: nil)
                }

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

    private func format(event: String, metadata: [String: String]) -> String {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let fields = metadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\(sanitize($0.value))" }
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
