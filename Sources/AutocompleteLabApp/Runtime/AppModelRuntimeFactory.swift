import Foundation
import AutocompleteLabCore

struct AppModelRuntimeBundle {
    let runtime: any ModelRuntime
    let bootstrapPlan: RuntimeBootstrapPlan
    let modelDirectoryURL: URL
    let lengthConfiguration: CompletionLengthConfiguration

    var activeCandidate: CompletionRuntimeCandidate {
        bootstrapPlan.activeCandidate
    }

    var diagnosticsMetadata: [String: String] {
        var metadata = [
            "preferredCandidate": bootstrapPlan.decision.preferredCandidate.rawValue,
            "fallbackCandidate": bootstrapPlan.decision.fallbackCandidate.rawValue,
            "activeCandidate": bootstrapPlan.activeCandidate.rawValue,
            "model": bootstrapPlan.preferredAsset.model.rawValue,
            "asset": bootstrapPlan.preferredAsset.fileName,
            "assetDirectory": modelDirectoryURL.path,
            "assetState": bootstrapPlan.assetState.statusSummary,
            "assetSourceRepoID": bootstrapPlan.preferredAsset.source?.repoID ?? "",
            "assetSourceRevision": bootstrapPlan.preferredAsset.source?.revision ?? "",
            "maxVisibleWords": String(lengthConfiguration.maxVisibleWords),
            "maxGeneratedTokens": String(lengthConfiguration.maxGeneratedTokens),
            "promptStyle": CompletionPromptBuilder.promptStyleIdentifier,
            "debounceMilliseconds": String(CompletionModelPolicy.mvp.debounceMilliseconds),
            "nativeRuntimeAvailable": String(bootstrapPlan.nativeRuntimeAvailable),
            "allowsUserManagedServer": String(bootstrapPlan.decision.allowsUserManagedServer)
        ]

        if let fallbackReason = bootstrapPlan.fallbackReason {
            metadata["fallbackReason"] = fallbackReason
        }

        return metadata
    }
}

enum AppModelRuntimeFactory {
    #if DEBUG
    static let defaultAllowsEnvironmentOverrides = true
    #else
    static let defaultAllowsEnvironmentOverrides = false
    #endif

    static func makeRuntime(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        allowEnvironmentOverrides: Bool = defaultAllowsEnvironmentOverrides
    ) -> AppModelRuntimeBundle {
        let lengthConfiguration = CompletionLengthConfiguration.default
        let manifest = LocalModelAssetManifest.mlxManifest(named: nil)
        let modelDirectoryURL = modelAssetURL(
            for: manifest,
            fileManager: fileManager,
            environment: environment,
            allowEnvironmentOverrides: allowEnvironmentOverrides
        )
        var integrityValidationCache = ModelAssetIntegrityValidationCache()
        let assetState = modelAssetState(
            for: manifest,
            at: modelDirectoryURL,
            fileManager: fileManager,
            integrityValidationCache: &integrityValidationCache
        )
        let plan = RuntimeBootstrapPlan(
            preferredAsset: manifest,
            assetState: assetState,
            nativeRuntimeAvailable: true
        )
        let runtime: any ModelRuntime

        if plan.canWarmPreferredRuntime {
            runtime = MLXModelRuntime(
                modelDirectoryURL: modelDirectoryURL,
                modelManifest: manifest,
                fileManager: fileManager,
                usesVisionLanguageFactory: manifest.requiresVisionLanguageFactory,
                lengthConfiguration: lengthConfiguration,
                integrityValidationCache: integrityValidationCache
            )
        } else {
            runtime = UnavailableModelRuntime(
                reason: plan.unavailableReason ?? "local model runtime is not ready"
            )
        }

        return AppModelRuntimeBundle(
            runtime: runtime,
            bootstrapPlan: plan,
            modelDirectoryURL: modelDirectoryURL,
            lengthConfiguration: lengthConfiguration
        )
    }

    static func modelAssetState(
        for manifest: LocalModelAssetManifest,
        at modelDirectoryURL: URL,
        fileManager: FileManager
    ) -> LocalModelAssetState {
        var integrityValidationCache = ModelAssetIntegrityValidationCache()
        return modelAssetState(
            for: manifest,
            at: modelDirectoryURL,
            fileManager: fileManager,
            integrityValidationCache: &integrityValidationCache
        )
    }

    static func modelAssetState(
        for manifest: LocalModelAssetManifest,
        at modelDirectoryURL: URL,
        fileManager: FileManager,
        integrityValidationCache: inout ModelAssetIntegrityValidationCache
    ) -> LocalModelAssetState {
        let path = modelDirectoryURL.path
        if let sourceRevisionError = manifest.source?.immutableRevisionError {
            return .invalid(path: path, reason: sourceRevisionError)
        }

        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return .missing(expectedPath: path)
        }

        let childFileNames = Set((try? fileManager.contentsOfDirectory(atPath: path)) ?? [])
        let modelBytes = childFileNames.reduce(Int64(0)) { total, childFileName in
            guard childFileName.lowercased().hasSuffix(".\(manifest.requiredModelFileExtension.lowercased())") else {
                return total
            }

            let childPath = URL(fileURLWithPath: path)
                .appendingPathComponent(childFileName, isDirectory: false)
                .path
            let size = (try? fileManager.attributesOfItem(atPath: childPath)[.size] as? NSNumber)?
                .int64Value ?? 0

            return total + size
        }

        let structureState = manifest.validatedDirectoryState(
            path: path,
            isDirectory: isDirectory.boolValue,
            childFileNames: childFileNames,
            modelBytes: modelBytes
        )

        guard structureState.isUsable else {
            return structureState
        }

        if let integrityError = integrityValidationCache.validate(
            manifest: manifest,
            modelDirectoryURL: modelDirectoryURL,
            fileManager: fileManager
        ) {
            return .invalid(path: path, reason: integrityError)
        }

        return structureState
    }

    private static func modelAssetURL(
        for manifest: LocalModelAssetManifest,
        fileManager: FileManager,
        environment: [String: String],
        allowEnvironmentOverrides: Bool
    ) -> URL {
        let baseDirectory: URL
        if allowEnvironmentOverrides,
           let override = environment["AUTOCOMPLETE_LAB_MODEL_ROOT"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty {
            baseDirectory = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            baseDirectory = (fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? URL(fileURLWithPath: NSTemporaryDirectory()))
                .appendingPathComponent("SteadyType", isDirectory: true)
        }

        return baseDirectory
            .appendingPathComponent(manifest.cacheDirectoryName, isDirectory: true)
            .appendingPathComponent(manifest.fileName, isDirectory: true)
    }
}
