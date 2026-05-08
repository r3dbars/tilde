import Foundation
import AutocompleteLabCore

struct AppModelRuntimeBundle {
    let runtime: any ModelRuntime
    let bootstrapPlan: RuntimeBootstrapPlan
    let modelDirectoryURL: URL
    let modelOverrideName: String?
    let experimentArm: AutocompleteExperimentArm
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
            "modelOverride": modelOverrideName ?? "",
            "experimentArm": experimentArm.rawValue,
            "maxVisibleWords": String(lengthConfiguration.maxVisibleWords),
            "maxGeneratedTokens": String(lengthConfiguration.maxGeneratedTokens),
            "promptStyle": CompletionPromptBuilder.promptStyleIdentifier,
            "debounceMilliseconds": String(CompletionModelPolicy.mvp.debounceMilliseconds),
            "nativeRuntimeAvailable": String(bootstrapPlan.nativeRuntimeAvailable),
            "canAttemptPreferredRuntime": String(bootstrapPlan.canAttemptPreferredRuntime),
            "mockFallbackAllowed": "false",
            "allowsUserManagedServer": String(bootstrapPlan.decision.allowsUserManagedServer)
        ]

        if let fallbackReason = bootstrapPlan.fallbackReason {
            metadata["fallbackReason"] = fallbackReason
        }

        return metadata
    }
}

enum AppModelRuntimeFactory {
    private static let experimentArmDefaultsKey = "AutocompleteLabCurrentExperimentArm"

    static func makeRuntime(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        defaults: UserDefaults = .standard
    ) -> AppModelRuntimeBundle {
        let modelOverrideName = environment["AUTOCOMPLETE_LAB_MODEL"]
        let experimentArm = resolvedExperimentArm(environment: environment, defaults: defaults)
        let lengthEnvironment = environment.merging([
            "AUTOCOMPLETE_LAB_EXPERIMENT_ARM": experimentArm.rawValue
        ]) { current, _ in current }
        let lengthConfiguration = CompletionLengthConfiguration.fromEnvironment(lengthEnvironment)
        let manifest = LocalModelAssetManifest.mlxManifest(named: modelOverrideName)
        let modelDirectoryURL = modelAssetURL(for: manifest, fileManager: fileManager)
        let assetState = modelAssetState(
            for: manifest,
            at: modelDirectoryURL,
            fileManager: fileManager
        )
        let plan = RuntimeBootstrapPlan(
            preferredAsset: manifest,
            assetState: assetState,
            nativeRuntimeAvailable: true
        )
        let runtime: any ModelRuntime

        if plan.canAttemptPreferredRuntime {
            runtime = MLXModelRuntime(
                modelDirectoryURL: modelDirectoryURL,
                usesVisionLanguageFactory: manifest.requiresVisionLanguageFactory,
                lengthConfiguration: lengthConfiguration
            )
        } else {
            runtime = UnavailableModelRuntime(
                candidate: plan.activeCandidate,
                reason: plan.fallbackReason ?? "local model runtime is not ready"
            )
        }

        return AppModelRuntimeBundle(
            runtime: runtime,
            bootstrapPlan: plan,
            modelDirectoryURL: modelDirectoryURL,
            modelOverrideName: modelOverrideName,
            experimentArm: experimentArm,
            lengthConfiguration: lengthConfiguration
        )
    }

    private static func resolvedExperimentArm(
        environment: [String: String],
        defaults: UserDefaults
    ) -> AutocompleteExperimentArm {
        let selection = AutocompleteExperimentArmSelection.current(
            environment: environment,
            persistedRawValue: defaults.string(forKey: experimentArmDefaultsKey)
        )
        if selection.shouldPersist {
            defaults.set(selection.arm.rawValue, forKey: experimentArmDefaultsKey)
        }

        return selection.arm
    }

    private static func modelAssetState(
        for manifest: LocalModelAssetManifest,
        at modelDirectoryURL: URL,
        fileManager: FileManager
    ) -> LocalModelAssetState {
        let path = modelDirectoryURL.path
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

        return manifest.validatedDirectoryState(
            path: path,
            isDirectory: isDirectory.boolValue,
            childFileNames: childFileNames,
            modelBytes: modelBytes,
            sourceRevisions: HuggingFaceModelMetadata.sourceRevisions(
                in: modelDirectoryURL,
                childFileNames: childFileNames,
                fileManager: fileManager
            )
        )
    }

    private static func modelAssetURL(
        for manifest: LocalModelAssetManifest,
        fileManager: FileManager
    ) -> URL {
        let baseDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())

        return baseDirectory
            .appendingPathComponent("AutocompleteLab", isDirectory: true)
            .appendingPathComponent(manifest.cacheDirectoryName, isDirectory: true)
            .appendingPathComponent(manifest.fileName, isDirectory: true)
    }
}
