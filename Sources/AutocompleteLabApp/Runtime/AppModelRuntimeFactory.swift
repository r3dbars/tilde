import Foundation
import AutocompleteLabCore

struct AppModelRuntimeBundle {
    let runtime: any ModelRuntime
    let bootstrapPlan: RuntimeBootstrapPlan
    let modelDirectoryURL: URL

    var activeCandidate: CompletionRuntimeCandidate {
        bootstrapPlan.activeCandidate
    }

    var diagnosticsMetadata: [String: String] {
        var metadata = [
            "preferredCandidate": bootstrapPlan.decision.preferredCandidate.rawValue,
            "fallbackCandidate": bootstrapPlan.decision.fallbackCandidate.rawValue,
            "activeCandidate": bootstrapPlan.activeCandidate.rawValue,
            "asset": bootstrapPlan.preferredAsset.fileName,
            "assetDirectory": modelDirectoryURL.path,
            "assetState": bootstrapPlan.assetState.statusSummary,
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
    static func makeRuntime(
        fileManager: FileManager = .default
    ) -> AppModelRuntimeBundle {
        let manifest = LocalModelAssetManifest.qwen3MediumMLX
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

        if plan.activeCandidate == .mlx {
            runtime = MLXModelRuntime(modelDirectoryURL: modelDirectoryURL)
        } else {
            runtime = MockModelRuntime(candidate: plan.activeCandidate)
        }

        return AppModelRuntimeBundle(
            runtime: runtime,
            bootstrapPlan: plan,
            modelDirectoryURL: modelDirectoryURL
        )
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
            modelBytes: modelBytes
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
