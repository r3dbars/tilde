import Foundation
import AutocompleteLabCore

struct AppModelRuntimeBundle {
    let runtime: any ModelRuntime
    let bootstrapPlan: RuntimeBootstrapPlan

    var activeCandidate: CompletionRuntimeCandidate {
        bootstrapPlan.activeCandidate
    }

    var diagnosticsMetadata: [String: String] {
        var metadata = [
            "preferredCandidate": bootstrapPlan.decision.preferredCandidate.rawValue,
            "fallbackCandidate": bootstrapPlan.decision.fallbackCandidate.rawValue,
            "activeCandidate": bootstrapPlan.activeCandidate.rawValue,
            "asset": bootstrapPlan.preferredAsset.fileName,
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
        fileManager: FileManager = .default,
        nativeRuntimeAvailable: Bool = false
    ) -> AppModelRuntimeBundle {
        let manifest = LocalModelAssetManifest.gemma4E2BMLX
        let assetState = modelAssetState(for: manifest, fileManager: fileManager)
        let plan = RuntimeBootstrapPlan(
            preferredAsset: manifest,
            assetState: assetState,
            nativeRuntimeAvailable: nativeRuntimeAvailable
        )

        // Until the MLX bridge is linked, keep the app functional through the
        // deterministic runtime while reporting the real bootstrap state.
        return AppModelRuntimeBundle(
            runtime: MockModelRuntime(candidate: plan.activeCandidate),
            bootstrapPlan: plan
        )
    }

    private static func modelAssetState(
        for manifest: LocalModelAssetManifest,
        fileManager: FileManager
    ) -> LocalModelAssetState {
        let path = modelAssetPath(for: manifest, fileManager: fileManager)
        guard fileManager.fileExists(atPath: path) else {
            return .missing(expectedPath: path)
        }

        guard let attributes = try? fileManager.attributesOfItem(atPath: path),
              let size = attributes[.size] as? NSNumber,
              size.int64Value >= manifest.expectedMinimumBytes else {
            return .invalid(path: path, reason: "file is too small")
        }

        return .available(path: path)
    }

    private static func modelAssetPath(
        for manifest: LocalModelAssetManifest,
        fileManager: FileManager
    ) -> String {
        let baseDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())

        return baseDirectory
            .appendingPathComponent("AutocompleteLab", isDirectory: true)
            .appendingPathComponent(manifest.cacheDirectoryName, isDirectory: true)
            .appendingPathComponent(manifest.fileName, isDirectory: false)
            .path
    }
}
