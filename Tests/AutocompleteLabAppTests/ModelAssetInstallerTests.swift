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
}
