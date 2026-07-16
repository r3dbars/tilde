import Foundation
import Testing
import AutocompleteLabCore
@testable import AutocompleteLabApp

@Suite("App model runtime factory")
struct AppModelRuntimeFactoryTests {
    @Test("Migrates old one-word experiment assignment to the longer default")
    func migratesOneWordExperimentAssignment() {
        let defaults = temporaryDefaults()
        defaults.set("length_1_word", forKey: AppModelRuntimeFactory.experimentArmDefaultsKey)

        let bundle = AppModelRuntimeFactory.makeRuntime(environment: [:], defaults: defaults)

        #expect(bundle.experimentArm == .length3Word)
        #expect(bundle.lengthConfiguration.maxVisibleWords == 8)
        #expect(bundle.lengthConfiguration.maxGeneratedTokens == 20)
        #expect(defaults.string(forKey: AppModelRuntimeFactory.experimentArmDefaultsKey) == "length_3_word")
    }

    @Test("Keeps explicit one-word environment override")
    func keepsExplicitOneWordEnvironmentOverride() {
        let defaults = temporaryDefaults()

        let bundle = AppModelRuntimeFactory.makeRuntime(
            environment: ["AUTOCOMPLETE_LAB_EXPERIMENT_ARM": "length_1_word"],
            defaults: defaults
        )

        #expect(bundle.experimentArm == .length1Word)
        #expect(bundle.lengthConfiguration.maxVisibleWords == 1)
        #expect(bundle.lengthConfiguration.maxGeneratedTokens == 4)
        #expect(defaults.string(forKey: AppModelRuntimeFactory.experimentArmDefaultsKey) == "length_1_word")
    }

    @Test("Accepts explicit twenty-word length override")
    func acceptsExplicitTwentyWordLengthOverride() {
        let defaults = temporaryDefaults()

        let bundle = AppModelRuntimeFactory.makeRuntime(
            environment: ["AUTOCOMPLETE_LAB_VISIBLE_WORDS": "20"],
            defaults: defaults
        )

        #expect(bundle.lengthConfiguration.maxVisibleWords == 20)
        #expect(bundle.lengthConfiguration.maxGeneratedTokens == 44)
    }

    @Test("Uses SteadyType model root override and unavailable runtime for missing model")
    func usesModelRootOverrideAndUnavailableRuntimeForMissingModel() async {
        let defaults = temporaryDefaults()
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("steadytype-model-root-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let bundle = AppModelRuntimeFactory.makeRuntime(
            environment: ["AUTOCOMPLETE_LAB_MODEL_ROOT": rootURL.path],
            defaults: defaults
        )

        #expect(bundle.modelDirectoryURL.path.contains("/Models/Qwen35FourB/MLX/Qwen3.5-4B-4bit"))
        #expect(bundle.bootstrapPlan.activeCandidate == .unavailable)
        #expect(bundle.bootstrapPlan.assetState.statusSummary.contains("missing model asset"))
        #expect(await bundle.runtime.state == .unavailable(reason: bundle.bootstrapPlan.unavailableReason ?? ""))
    }

    @Test("MLX model loading resolves compatibility symlink roots")
    func mlxModelLoadingResolvesCompatibilitySymlinkRoots() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("steadytype-symlink-model-root-\(UUID().uuidString)", isDirectory: true)
        let modelURL = rootURL.appendingPathComponent("model", isDirectory: true)
        let compatibilityURL = rootURL.appendingPathComponent("compatibility-model", isDirectory: true)
        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        try fileManager.createDirectory(at: modelURL, withIntermediateDirectories: true)
        try Data("weights".utf8).write(to: modelURL.appendingPathComponent("model.safetensors"))
        try fileManager.createSymbolicLink(at: compatibilityURL, withDestinationURL: modelURL)

        let loadURL = MLXModelRuntime.modelLoadDirectoryURL(for: compatibilityURL)
        var shardCount = 0
        let enumerator = try #require(fileManager.enumerator(
            at: loadURL,
            includingPropertiesForKeys: nil
        ))
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "safetensors" {
            shardCount += 1
        }

        #expect(loadURL == modelURL.resolvingSymlinksInPath())
        #expect(shardCount == 1)
    }

    @Test("Uses unavailable runtime and repair state for invalid model folder")
    func usesUnavailableRuntimeAndRepairStateForInvalidModelFolder() async throws {
        let defaults = temporaryDefaults()
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("steadytype-invalid-model-root-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let initialBundle = AppModelRuntimeFactory.makeRuntime(
            environment: ["AUTOCOMPLETE_LAB_MODEL_ROOT": rootURL.path],
            defaults: defaults
        )
        try FileManager.default.createDirectory(
            at: initialBundle.modelDirectoryURL,
            withIntermediateDirectories: true
        )
        try Data("{}".utf8).write(to: initialBundle.modelDirectoryURL.appendingPathComponent("config.json"))

        let bundle = AppModelRuntimeFactory.makeRuntime(
            environment: ["AUTOCOMPLETE_LAB_MODEL_ROOT": rootURL.path],
            defaults: defaults
        )
        let state = await bundle.runtime.state
        let report = bundle.bootstrapPlan.readinessReport(for: state)

        #expect(bundle.bootstrapPlan.activeCandidate == .unavailable)
        #expect(report.stage == .repairNeeded)
        #expect(report.action == .repairModel)
        #expect(bundle.bootstrapPlan.assetState.statusSummary.contains("model asset invalid"))
        #expect(state == .unavailable(reason: bundle.bootstrapPlan.unavailableReason ?? ""))
    }

    @Test("Production runtime ignores mutable model environment overrides")
    func productionRuntimeIgnoresMutableModelEnvironmentOverrides() {
        let defaults = temporaryDefaults()
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("steadytype-production-model-root-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let bundle = AppModelRuntimeFactory.makeRuntime(
            environment: [
                "AUTOCOMPLETE_LAB_MODEL": "qwen35-9b",
                "AUTOCOMPLETE_LAB_MODEL_ROOT": rootURL.path
            ],
            defaults: defaults,
            allowEnvironmentOverrides: false
        )

        #expect(bundle.modelOverrideName == nil)
        #expect(bundle.bootstrapPlan.preferredAsset == .qwen35FourBMLX)
        #expect(bundle.bootstrapPlan.preferredAsset.source != nil)
        #expect(!bundle.modelDirectoryURL.path.hasPrefix(rootURL.path))
    }

    @Test("Rejects source-backed model folders without a valid integrity receipt")
    func rejectsSourceBackedModelFoldersWithoutValidIntegrityReceipt() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("steadytype-runtime-integrity-\(UUID().uuidString)", isDirectory: true)
        let modelURL = rootURL.appendingPathComponent("model", isDirectory: true)
        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        try fileManager.createDirectory(at: modelURL, withIntermediateDirectories: true)
        try "{}".write(
            to: modelURL.appendingPathComponent("config.json"),
            atomically: true,
            encoding: .utf8
        )
        try "weights".write(
            to: modelURL.appendingPathComponent("model.safetensors"),
            atomically: true,
            encoding: .utf8
        )

        let manifest = smallSourceBackedManifest()
        let missingReceiptState = AppModelRuntimeFactory.modelAssetState(
            for: manifest,
            at: modelURL,
            fileManager: fileManager
        )
        #expect(missingReceiptState == .invalid(
            path: modelURL.path,
            reason: "missing integrity receipt .steadytype-model-integrity.json"
        ))

        _ = try ModelAssetIntegrityReceiptWriter.write(
            manifest: manifest,
            modelDirectoryURL: modelURL,
            fileManager: fileManager
        )

        let validState = AppModelRuntimeFactory.modelAssetState(
            for: manifest,
            at: modelURL,
            fileManager: fileManager
        )
        #expect(validState == .available(path: modelURL.path))

        try "WEIGHTS".write(
            to: modelURL.appendingPathComponent("model.safetensors"),
            atomically: true,
            encoding: .utf8
        )

        let tamperedState = AppModelRuntimeFactory.modelAssetState(
            for: manifest,
            at: modelURL,
            fileManager: fileManager
        )
        #expect(tamperedState == .invalid(
            path: modelURL.path,
            reason: "integrity receipt checksum mismatch for model.safetensors"
        ))
    }

    @Test("Rejects mutable source revisions before model lookup")
    func rejectsMutableSourceRevisionsBeforeModelLookup() {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("steadytype-runtime-mutable-revision-\(UUID().uuidString)", isDirectory: true)
        let modelURL = rootURL.appendingPathComponent("model", isDirectory: true)
        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        let manifest = LocalModelAssetManifest(
            model: .qwen35FourB,
            runtimeCandidate: .mlx,
            cacheDirectoryName: "Models/Test/MLX",
            fileName: "test-model",
            source: LocalModelAssetSource(
                repoID: "mlx-community/Test",
                revision: "main",
                allowPatterns: ["*.safetensors", "config.json"]
            ),
            expectedMinimumBytes: 1,
            requiredFileNames: ["config.json"]
        )

        let state = AppModelRuntimeFactory.modelAssetState(
            for: manifest,
            at: modelURL,
            fileManager: fileManager
        )

        #expect(state == .invalid(
            path: modelURL.path,
            reason: LocalModelAssetSource.immutableRevisionRequirement
        ))
    }

    @Test("MLX warm revalidates source-backed integrity before loading")
    func mlxWarmRevalidatesSourceBackedIntegrityBeforeLoading() async throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("steadytype-runtime-warm-integrity-\(UUID().uuidString)", isDirectory: true)
        let modelURL = rootURL.appendingPathComponent("model", isDirectory: true)
        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        try fileManager.createDirectory(at: modelURL, withIntermediateDirectories: true)
        try "{}".write(
            to: modelURL.appendingPathComponent("config.json"),
            atomically: true,
            encoding: .utf8
        )
        try "weights".write(
            to: modelURL.appendingPathComponent("model.safetensors"),
            atomically: true,
            encoding: .utf8
        )

        let manifest = smallSourceBackedManifest()
        _ = try ModelAssetIntegrityReceiptWriter.write(
            manifest: manifest,
            modelDirectoryURL: modelURL,
            fileManager: fileManager
        )
        try "tamper!".write(
            to: modelURL.appendingPathComponent("model.safetensors"),
            atomically: true,
            encoding: .utf8
        )

        let runtime = MLXModelRuntime(
            modelDirectoryURL: modelURL,
            modelManifest: manifest,
            fileManager: fileManager
        )
        let reason = "integrity receipt checksum mismatch for model.safetensors"

        await #expect(throws: MLXModelRuntimeError.modelAssetIntegrityFailed(reason: reason)) {
            try await runtime.warm()
        }
        #expect(await runtime.state == .failed(
            candidate: .mlx,
            reason: "Model asset integrity failed: \(reason)"
        ))
    }

    @Test("MLX integrity failures expose safe structured diagnostics")
    func mlxIntegrityFailuresExposeSafeStructuredDiagnostics() {
        let checksumReason = "integrity receipt checksum mismatch for model.safetensors"
        #expect(MLXModelRuntime.integrityFailureCode(for: checksumReason) == "checksum-mismatch")
        #expect(MLXModelRuntime.integrityFailureFile(for: checksumReason) == "model.safetensors")

        let missingReason = "integrity receipt missing expected file tokenizer.json"
        #expect(MLXModelRuntime.integrityFailureCode(for: missingReason) == "missing-file")
        #expect(MLXModelRuntime.integrityFailureFile(for: missingReason) == "tokenizer.json")

        let mutableRevisionReason = LocalModelAssetSource.immutableRevisionRequirement
        #expect(MLXModelRuntime.integrityFailureCode(for: mutableRevisionReason) == "mutable-revision")

        #expect(MLXModelRuntime.integrityFailureCode(for: "some new integrity failure") == "unknown")
        #expect(MLXModelRuntime.integrityFailureFile(for: "some new integrity failure") == nil)
    }

    @Test("Integrity validation cache skips unchanged duplicate checks and invalidates edits")
    func integrityValidationCacheSkipsUnchangedDuplicateChecksAndInvalidatesEdits() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("steadytype-runtime-integrity-cache-\(UUID().uuidString)", isDirectory: true)
        let modelURL = rootURL.appendingPathComponent("model", isDirectory: true)
        let weightsURL = modelURL.appendingPathComponent("model.safetensors")
        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        try fileManager.createDirectory(at: modelURL, withIntermediateDirectories: true)
        try "{}".write(
            to: modelURL.appendingPathComponent("config.json"),
            atomically: true,
            encoding: .utf8
        )
        try "weights".write(
            to: weightsURL,
            atomically: true,
            encoding: .utf8
        )

        let manifest = smallSourceBackedManifest()
        _ = try ModelAssetIntegrityReceiptWriter.write(
            manifest: manifest,
            modelDirectoryURL: modelURL,
            fileManager: fileManager
        )

        var cache = ModelAssetIntegrityValidationCache()
        var checksummedFiles: [String] = []
        let countingChecksum: (URL) throws -> String = { url in
            checksummedFiles.append(url.lastPathComponent)
            return try ModelAssetIntegrityReceiptWriter.sha256(url)
        }

        #expect(cache.validate(
            manifest: manifest,
            modelDirectoryURL: modelURL,
            fileManager: fileManager,
            checksum: countingChecksum
        ) == nil)
        #expect(checksummedFiles.contains("model.safetensors"))

        checksummedFiles = []
        #expect(cache.validate(
            manifest: manifest,
            modelDirectoryURL: modelURL,
            fileManager: fileManager,
            checksum: countingChecksum
        ) == nil)
        #expect(checksummedFiles.isEmpty)

        try "WEIGHTS".write(to: weightsURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: 5)],
            ofItemAtPath: weightsURL.path
        )

        checksummedFiles = []
        #expect(cache.validate(
            manifest: manifest,
            modelDirectoryURL: modelURL,
            fileManager: fileManager,
            checksum: countingChecksum
        ) == "integrity receipt checksum mismatch for model.safetensors")
        #expect(checksummedFiles.contains("model.safetensors"))
    }

    @Test("Factory readiness validation seeds the shared integrity cache")
    func factoryReadinessValidationSeedsSharedIntegrityCache() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("steadytype-runtime-factory-integrity-cache-\(UUID().uuidString)", isDirectory: true)
        let modelURL = rootURL.appendingPathComponent("model", isDirectory: true)
        let weightsURL = modelURL.appendingPathComponent("model.safetensors")
        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        try fileManager.createDirectory(at: modelURL, withIntermediateDirectories: true)
        try "{}".write(
            to: modelURL.appendingPathComponent("config.json"),
            atomically: true,
            encoding: .utf8
        )
        try "weights".write(
            to: weightsURL,
            atomically: true,
            encoding: .utf8
        )

        let manifest = smallSourceBackedManifest()
        _ = try ModelAssetIntegrityReceiptWriter.write(
            manifest: manifest,
            modelDirectoryURL: modelURL,
            fileManager: fileManager
        )

        var integrityValidationCache = ModelAssetIntegrityValidationCache()
        let state = AppModelRuntimeFactory.modelAssetState(
            for: manifest,
            at: modelURL,
            fileManager: fileManager,
            integrityValidationCache: &integrityValidationCache
        )
        #expect(state == .available(path: modelURL.path))

        var checksummedFiles: [String] = []
        let countingChecksum: (URL) throws -> String = { url in
            checksummedFiles.append(url.lastPathComponent)
            return try ModelAssetIntegrityReceiptWriter.sha256(url)
        }
        #expect(integrityValidationCache.validate(
            manifest: manifest,
            modelDirectoryURL: modelURL,
            fileManager: fileManager,
            checksum: countingChecksum
        ) == nil)
        #expect(checksummedFiles.isEmpty)

        try "WEIGHTS".write(to: weightsURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: 5)],
            ofItemAtPath: weightsURL.path
        )

        #expect(integrityValidationCache.validate(
            manifest: manifest,
            modelDirectoryURL: modelURL,
            fileManager: fileManager,
            checksum: countingChecksum
        ) == "integrity receipt checksum mismatch for model.safetensors")
        #expect(checksummedFiles.contains("model.safetensors"))
    }

    private func temporaryDefaults() -> UserDefaults {
        let suiteName = "autocomplete-app-model-runtime-factory-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func smallSourceBackedManifest() -> LocalModelAssetManifest {
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
}
