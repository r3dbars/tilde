import AutocompleteLabCore
import CryptoKit
import Foundation

enum ModelAssetIntegrityReceiptError: LocalizedError, Equatable {
    case sourceRevisionNotImmutable(String)

    var errorDescription: String? {
        switch self {
        case let .sourceRevisionNotImmutable(reason):
            return reason
        }
    }
}

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
        if let sourceRevisionError = source.immutableRevisionError {
            throw ModelAssetIntegrityReceiptError.sourceRevisionNotImmutable(sourceRevisionError)
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

    static func modelFiles(
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

    static func sha256(_ url: URL) throws -> String {
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

    static func canonicalModelAlias(for model: LocalModelID) -> String {
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

enum ModelAssetIntegrityReceiptValidator {
    static func validate(
        manifest: LocalModelAssetManifest,
        modelDirectoryURL: URL,
        fileManager: FileManager = .default
    ) -> String? {
        guard let source = manifest.source else {
            return nil
        }
        if let sourceRevisionError = source.immutableRevisionError {
            return sourceRevisionError
        }

        let receiptURL = modelDirectoryURL.appendingPathComponent(
            ModelAssetIntegrityReceiptWriter.fileName,
            isDirectory: false
        )
        guard fileManager.fileExists(atPath: receiptURL.path) else {
            return "missing integrity receipt \(ModelAssetIntegrityReceiptWriter.fileName)"
        }

        let receipt: ModelAssetIntegrityReceipt
        do {
            receipt = try JSONDecoder().decode(
                ModelAssetIntegrityReceipt.self,
                from: Data(contentsOf: receiptURL)
            )
        } catch {
            return "invalid integrity receipt: \(error.localizedDescription)"
        }

        guard receipt.schemaVersion == 1 else {
            return "unsupported integrity receipt schema \(receipt.schemaVersion)"
        }

        let expectedModel = ModelAssetIntegrityReceiptWriter.canonicalModelAlias(for: manifest.model)
        guard receipt.model == expectedModel else {
            return "integrity receipt model mismatch"
        }

        guard receipt.repoID == source.repoID else {
            return "integrity receipt repo mismatch"
        }

        guard receipt.revision == source.revision else {
            return "integrity receipt revision mismatch"
        }

        let entriesByPath = Dictionary(grouping: receipt.files, by: \.path)
        if let duplicate = entriesByPath.first(where: { $0.value.count > 1 })?.key {
            return "integrity receipt has duplicate file \(duplicate)"
        }

        let receiptPaths = Set(entriesByPath.keys)
        if let unsafePath = receiptPaths.first(where: isUnsafeReceiptPath) {
            return "integrity receipt has unsafe file path \(unsafePath)"
        }

        if let expectedFilesError = validateExpectedFiles(
            source.expectedFiles,
            receiptPaths: receiptPaths,
            entriesByPath: entriesByPath
        ) {
            return expectedFilesError
        }

        let fileURLs: [URL]
        do {
            fileURLs = try ModelAssetIntegrityReceiptWriter.modelFiles(
                in: modelDirectoryURL,
                fileManager: fileManager
            )
        } catch {
            return "could not inspect model files: \(error.localizedDescription)"
        }

        let fileNames = Set(fileURLs.map(\.lastPathComponent))
        let extraFiles = fileNames.subtracting(receiptPaths).sorted()
        if let extraFile = extraFiles.first {
            return "model file is not in integrity receipt: \(extraFile)"
        }

        let missingFiles = receiptPaths.subtracting(fileNames).sorted()
        if let missingFile = missingFiles.first {
            return "integrity receipt references missing model file: \(missingFile)"
        }

        for fileURL in fileURLs {
            guard let entry = entriesByPath[fileURL.lastPathComponent]?.first else {
                return "model file is not in integrity receipt: \(fileURL.lastPathComponent)"
            }

            let size = (try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?
                .int64Value ?? -1
            guard size == entry.byteCount else {
                return "integrity receipt byte count mismatch for \(entry.path)"
            }

            let digest: String
            do {
                digest = try ModelAssetIntegrityReceiptWriter.sha256(fileURL)
            } catch {
                return "could not checksum \(entry.path): \(error.localizedDescription)"
            }

            guard digest == entry.sha256 else {
                return "integrity receipt checksum mismatch for \(entry.path)"
            }
        }

        return nil
    }

    private static func validateExpectedFiles(
        _ expectedFiles: [LocalModelAssetSource.ExpectedFile],
        receiptPaths: Set<String>,
        entriesByPath: [String: [ModelAssetIntegrityReceipt.FileEntry]]
    ) -> String? {
        guard !expectedFiles.isEmpty else {
            return nil
        }

        let expectedEntriesByPath = Dictionary(uniqueKeysWithValues: expectedFiles.map { ($0.path, $0) })
        let expectedPaths = Set(expectedEntriesByPath.keys)

        if let missingPath = expectedPaths.subtracting(receiptPaths).sorted().first {
            return "integrity receipt missing expected file \(missingPath)"
        }

        if let unexpectedPath = receiptPaths.subtracting(expectedPaths).sorted().first {
            return "integrity receipt has unexpected file \(unexpectedPath)"
        }

        for path in expectedPaths.sorted() {
            guard let expected = expectedEntriesByPath[path],
                  let actual = entriesByPath[path]?.first else {
                return "integrity receipt missing expected file \(path)"
            }

            guard actual.byteCount == expected.byteCount else {
                return "known-good byte count mismatch for \(path)"
            }

            guard actual.sha256.lowercased() == expected.sha256 else {
                return "known-good checksum mismatch for \(path)"
            }
        }

        return nil
    }

    private static func isUnsafeReceiptPath(_ path: String) -> Bool {
        path.isEmpty
            || path.contains("/")
            || path.contains("\\")
            || path == "."
            || path == ".."
    }
}
