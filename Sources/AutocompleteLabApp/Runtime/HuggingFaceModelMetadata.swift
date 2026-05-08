import Foundation

struct HuggingFaceModelMetadata {
    static func sourceRevisions(
        in modelDirectoryURL: URL,
        childFileNames: Set<String>,
        fileManager: FileManager = .default
    ) -> [String: String] {
        let metadataDirectoryURL = modelDirectoryURL
            .appendingPathComponent(".cache", isDirectory: true)
            .appendingPathComponent("huggingface", isDirectory: true)
            .appendingPathComponent("download", isDirectory: true)

        return childFileNames.reduce(into: [:]) { revisions, fileName in
            let metadataURL = metadataDirectoryURL.appendingPathComponent("\(fileName).metadata")
            guard fileManager.fileExists(atPath: metadataURL.path),
                  let contents = try? String(contentsOf: metadataURL, encoding: .utf8),
                  let revision = contents
                      .split(whereSeparator: \.isNewline)
                      .first?
                      .trimmingCharacters(in: .whitespacesAndNewlines),
                  !revision.isEmpty else {
                return
            }

            revisions[fileName] = revision
        }
    }
}
