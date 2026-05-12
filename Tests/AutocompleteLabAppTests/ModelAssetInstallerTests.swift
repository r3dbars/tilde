import Foundation
import Testing
@testable import AutocompleteLabApp
@testable import AutocompleteLabCore

@Suite("Model asset installer")
struct ModelAssetInstallerTests {
    @Test("Finalizing a valid downloaded snapshot replaces the app-owned model folder")
    func finalizeValidSnapshotReplacesTarget() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("AutocompleteLabInstallerTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        let snapshotURL = rootURL.appendingPathComponent("snapshot", isDirectory: true)
        let targetURL = rootURL.appendingPathComponent("target", isDirectory: true)
        try fileManager.createDirectory(at: snapshotURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
        try "old".write(
            to: targetURL.appendingPathComponent("old.txt"),
            atomically: true,
            encoding: .utf8
        )
        try "{}".write(
            to: snapshotURL.appendingPathComponent("config.json"),
            atomically: true,
            encoding: .utf8
        )
        try "weights".write(
            to: snapshotURL.appendingPathComponent("model.safetensors"),
            atomically: true,
            encoding: .utf8
        )

        let manifest = LocalModelAssetManifest(
            model: .qwen35FourB,
            runtimeCandidate: .mlx,
            cacheDirectoryName: "Models/Test/MLX",
            fileName: "test-model",
            expectedMinimumBytes: 1,
            requiredFileNames: ["config.json"]
        )

        try ModelAssetInstaller.finalizeDownloadedSnapshot(
            manifest: manifest,
            snapshotURL: snapshotURL,
            targetURL: targetURL,
            fileManager: fileManager
        )

        #expect(!fileManager.fileExists(atPath: snapshotURL.path))
        #expect(fileManager.fileExists(atPath: targetURL.appendingPathComponent("config.json").path))
        #expect(fileManager.fileExists(atPath: targetURL.appendingPathComponent("model.safetensors").path))
        #expect(!fileManager.fileExists(atPath: targetURL.appendingPathComponent("old.txt").path))
    }

    @Test("Finalizing a source-backed snapshot writes an integrity receipt")
    func finalizeSourceBackedSnapshotWritesIntegrityReceipt() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("AutocompleteLabInstallerTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        let snapshotURL = rootURL.appendingPathComponent("snapshot", isDirectory: true)
        let targetURL = rootURL.appendingPathComponent("target", isDirectory: true)
        try fileManager.createDirectory(at: snapshotURL, withIntermediateDirectories: true)
        try "{}".write(
            to: snapshotURL.appendingPathComponent("config.json"),
            atomically: true,
            encoding: .utf8
        )
        try "weights".write(
            to: snapshotURL.appendingPathComponent("model.safetensors"),
            atomically: true,
            encoding: .utf8
        )

        let manifest = LocalModelAssetManifest(
            model: .qwen35FourB,
            runtimeCandidate: .mlx,
            cacheDirectoryName: "Models/Test/MLX",
            fileName: "test-model",
            source: LocalModelAssetSource(
                repoID: "mlx-community/Test",
                revision: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                allowPatterns: ["*.safetensors", "config.json"]
            ),
            expectedMinimumBytes: 1,
            requiredFileNames: ["config.json"]
        )

        try ModelAssetInstaller.finalizeDownloadedSnapshot(
            manifest: manifest,
            snapshotURL: snapshotURL,
            targetURL: targetURL,
            fileManager: fileManager
        )

        let receiptURL = targetURL.appendingPathComponent(ModelAssetIntegrityReceiptWriter.fileName)
        let receipt = try JSONDecoder().decode(
            ModelAssetIntegrityReceipt.self,
            from: Data(contentsOf: receiptURL)
        )

        #expect(receipt.model == "qwen35-4b")
        #expect(receipt.repoID == "mlx-community/Test")
        #expect(receipt.revision == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
        #expect(receipt.files.map(\.path).sorted() == ["config.json", "model.safetensors"])
        #expect(receipt.files.allSatisfy { $0.sha256.count == 64 })
        #expect(ModelAssetIntegrityReceiptValidator.validate(
            manifest: manifest,
            modelDirectoryURL: targetURL,
            fileManager: fileManager
        ) == nil)

        try "WEIGHTS".write(
            to: targetURL.appendingPathComponent("model.safetensors"),
            atomically: true,
            encoding: .utf8
        )
        #expect(ModelAssetIntegrityReceiptValidator.validate(
            manifest: manifest,
            modelDirectoryURL: targetURL,
            fileManager: fileManager
        ) == "integrity receipt checksum mismatch for model.safetensors")
    }

    @Test("Integrity receipt validator rejects mismatched or unsafe receipts")
    func integrityReceiptValidatorRejectsMismatchedOrUnsafeReceipts() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("AutocompleteLabInstallerTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        let targetURL = rootURL.appendingPathComponent("target", isDirectory: true)
        try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
        try "{}".write(
            to: targetURL.appendingPathComponent("config.json"),
            atomically: true,
            encoding: .utf8
        )
        try "weights".write(
            to: targetURL.appendingPathComponent("model.safetensors"),
            atomically: true,
            encoding: .utf8
        )

        let manifest = sourceBackedManifest()
        let receiptURL = try ModelAssetIntegrityReceiptWriter.write(
            manifest: manifest,
            modelDirectoryURL: targetURL,
            fileManager: fileManager
        )
        let validReceipt = try JSONDecoder().decode(
            ModelAssetIntegrityReceipt.self,
            from: Data(contentsOf: receiptURL!)
        )

        func validate(_ receipt: ModelAssetIntegrityReceipt) throws -> String? {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(receipt).write(to: receiptURL!, options: .atomic)
            return ModelAssetIntegrityReceiptValidator.validate(
                manifest: manifest,
                modelDirectoryURL: targetURL,
                fileManager: fileManager
            )
        }

        #expect(try validate(receipt(from: validReceipt, model: "wrong-model")) == "integrity receipt model mismatch")
        #expect(try validate(receipt(from: validReceipt, repoID: "mlx-community/Other")) == "integrity receipt repo mismatch")
        #expect(try validate(receipt(from: validReceipt, revision: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")) == "integrity receipt revision mismatch")
        #expect(try validate(receipt(from: validReceipt, files: validReceipt.files + [validReceipt.files[0]])) == "integrity receipt has duplicate file config.json")
        #expect(try validate(receipt(from: validReceipt, files: [
            .init(path: "../model.safetensors", byteCount: 7, sha256: String(repeating: "0", count: 64))
        ])) == "integrity receipt has unsafe file path ../model.safetensors")
        #expect(try validate(receipt(from: validReceipt, files: validReceipt.files + [
            .init(path: "missing.safetensors", byteCount: 7, sha256: String(repeating: "0", count: 64))
        ])) == "integrity receipt references missing model file: missing.safetensors")

        var byteCountMismatchFiles = validReceipt.files
        byteCountMismatchFiles[0] = .init(
            path: byteCountMismatchFiles[0].path,
            byteCount: byteCountMismatchFiles[0].byteCount + 1,
            sha256: byteCountMismatchFiles[0].sha256
        )
        #expect(try validate(receipt(from: validReceipt, files: byteCountMismatchFiles)) == "integrity receipt byte count mismatch for config.json")

        try "extra".write(
            to: targetURL.appendingPathComponent("extra.txt"),
            atomically: true,
            encoding: .utf8
        )
        #expect(try validate(validReceipt) == "model file is not in integrity receipt: extra.txt")
    }

    @Test("Finalizing an invalid downloaded snapshot keeps the previous model folder")
    func finalizeInvalidSnapshotKeepsTarget() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("AutocompleteLabInstallerTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        let snapshotURL = rootURL.appendingPathComponent("snapshot", isDirectory: true)
        let targetURL = rootURL.appendingPathComponent("target", isDirectory: true)
        try fileManager.createDirectory(at: snapshotURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
        try "old".write(
            to: targetURL.appendingPathComponent("old.txt"),
            atomically: true,
            encoding: .utf8
        )

        let manifest = LocalModelAssetManifest(
            model: .qwen35FourB,
            runtimeCandidate: .mlx,
            cacheDirectoryName: "Models/Test/MLX",
            fileName: "test-model",
            expectedMinimumBytes: 1,
            requiredFileNames: ["config.json"]
        )

        #expect(throws: ModelAssetInstallerError.self) {
            try ModelAssetInstaller.finalizeDownloadedSnapshot(
                manifest: manifest,
                snapshotURL: snapshotURL,
                targetURL: targetURL,
                fileManager: fileManager
            )
        }
        #expect(fileManager.fileExists(atPath: snapshotURL.path))
        #expect(fileManager.fileExists(atPath: targetURL.appendingPathComponent("old.txt").path))
    }

    @Test("Install progress formats percentage and speed")
    func installProgressFormatsStatusText() {
        let progress = ModelAssetInstallProgress(
            phase: "downloading",
            completedUnitCount: 2,
            totalUnitCount: 4,
            throughputBytesPerSecond: 2 * 1024 * 1024
        )

        #expect(progress.statusText == "Model install: downloading 50% at 2.0 MiB/s")
    }

    private func sourceBackedManifest() -> LocalModelAssetManifest {
        LocalModelAssetManifest(
            model: .qwen35FourB,
            runtimeCandidate: .mlx,
            cacheDirectoryName: "Models/Test/MLX",
            fileName: "test-model",
            source: LocalModelAssetSource(
                repoID: "mlx-community/Test",
                revision: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                allowPatterns: ["*.safetensors", "config.json"]
            ),
            expectedMinimumBytes: 1,
            requiredFileNames: ["config.json"]
        )
    }

    private func receipt(
        from base: ModelAssetIntegrityReceipt,
        schemaVersion: Int? = nil,
        model: String? = nil,
        repoID: String? = nil,
        revision: String? = nil,
        files: [ModelAssetIntegrityReceipt.FileEntry]? = nil
    ) -> ModelAssetIntegrityReceipt {
        ModelAssetIntegrityReceipt(
            schemaVersion: schemaVersion ?? base.schemaVersion,
            generatedAtUTC: base.generatedAtUTC,
            model: model ?? base.model,
            displayName: base.displayName,
            repoID: repoID ?? base.repoID,
            revision: revision ?? base.revision,
            files: files ?? base.files
        )
    }
}
