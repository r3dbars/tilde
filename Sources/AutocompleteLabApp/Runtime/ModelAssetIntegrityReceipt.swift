import AutocompleteLabCore
import CryptoKit
import Foundation

struct ModelAssetIntegrityReceipt: Codable, Equatable {
    struct FileEntry: Codable, Equatable {
        let path: String
        let byteCount: Int64
        let sha256: String

        enum CodingKeys: String, CodingKey {
            case path
            case byteCount = "byte_count"
            case sha256
        }
    }

    let schemaVersion: Int
    let generatedAtUTC: String
    let model: String
    let displayName: String
    let repoID: String
    let revision: String
    let files: [FileEntry]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case generatedAtUTC = "generated_at_utc"
        case model
        case displayName = "display_name"
        case repoID = "repo_id"
        case revision
        case files
    }
}

enum ModelAssetIntegrityReceiptWriter {
    static let fileName = ".steadytype-model-integrity.json"

    static func write(
        manifest: LocalModelAssetManifest,
        modelDirectoryURL: URL,
        fileManager: FileManager = .default,
        generatedAt: Date = Date()
    ) throws -> URL? {
        guard let source = manifest.source else {
            return nil
        }

        let entries = try modelFiles(in: modelDirectoryURL, fileManager: fileManager).map { url in
            let size = try fileManager.attributesOfItem(atPath: url.path)[.size] as? NSNumber
            return ModelAssetIntegrityReceipt.FileEntry(
                path: url.lastPathComponent,
                byteCount: size?.int64Value ?? 0,
                sha256: try sha256(url)
            )
        }
        let receipt = ModelAssetIntegrityReceipt(
            schemaVersion: 1,
            generatedAtUTC: iso8601String(generatedAt),
            model: canonicalModelAlias(for: manifest.model),
            displayName: manifest.model.rawValue,
            repoID: source.repoID,
            revision: source.revision,
            files: entries
        )
        let receiptURL = modelDirectoryURL.appendingPathComponent(fileName, isDirectory: false)
        let tempURL = modelDirectoryURL.appendingPathComponent(".\(fileName).tmp", isDirectory: false)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(receipt).write(to: tempURL, options: .atomic)
        if fileManager.fileExists(atPath: receiptURL.path) {
            try fileManager.removeItem(at: receiptURL)
        }
        try fileManager.moveItem(at: tempURL, to: receiptURL)
        return receiptURL
    }

    private static func modelFiles(
        in directoryURL: URL,
        fileManager: FileManager
    ) throws -> [URL] {
        try fileManager
            .contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            .filter { url in
                url.lastPathComponent != fileName
            }
            .filter { url in
                (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func sha256(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            try? handle.close()
        }

        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: 1024 * 1024) ?? Data()
            if data.isEmpty {
                break
            }
            hasher.update(data: data)
        }

        return hasher.finalize()
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func iso8601String(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private static func canonicalModelAlias(for model: LocalModelID) -> String {
        switch model {
        case .qwen35FourB:
            return "qwen35-4b"
        case .qwen35NineB:
            return "qwen35-9b"
        case .qwen3Medium:
            return "qwen3-1.7b"
        case .qwen3Small:
            return "qwen3-0.6b"
        case .gemma4E2B:
            return "gemma-4-e2b"
        case .gemma4E4B:
            return "gemma-4-e4b"
        case .gemma4E4BItOptiQ:
            return "gemma-4-e4b-it-optiq"
        case .gemma4A4B:
            return "gemma-4-26b"
        }
    }
}
