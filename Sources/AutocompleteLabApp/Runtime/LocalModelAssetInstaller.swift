import Foundation
import AutocompleteLabCore
import HuggingFace

struct LocalModelInstallProgress: Equatable, Sendable {
    enum Phase: String, Sendable {
        case preparing
        case downloading
        case validating
        case installed
    }

    let phase: Phase
    let completedUnitCount: Int64
    let totalUnitCount: Int64
    let detail: String?

    init(
        phase: Phase,
        completedUnitCount: Int64 = 0,
        totalUnitCount: Int64 = 1,
        detail: String? = nil
    ) {
        self.phase = phase
        self.completedUnitCount = max(0, completedUnitCount)
        self.totalUnitCount = max(1, totalUnitCount)
        self.detail = detail
    }

    var fractionCompleted: Double {
        min(1, Double(completedUnitCount) / Double(totalUnitCount))
    }

    var userFacingText: String {
        switch phase {
        case .preparing:
            return "Model install: preparing download"
        case .downloading:
            return "Model install: \(Int((fractionCompleted * 100).rounded()))% downloaded"
        case .validating:
            return "Model install: validating files"
        case .installed:
            return "Model install: ready to warm"
        }
    }
}

enum LocalModelAssetInstallerError: LocalizedError, Equatable {
    case missingSource(model: String)
    case invalidRepository(String)
    case invalidAfterInstall(String)

    var errorDescription: String? {
        switch self {
        case let .missingSource(model):
            return "No in-app download source is configured for \(model)."
        case let .invalidRepository(repoID):
            return "Invalid model repository: \(repoID)."
        case let .invalidAfterInstall(reason):
            return "Downloaded model is still invalid: \(reason)."
        }
    }
}

struct LocalModelAssetInstaller: Sendable {
    let manifest: LocalModelAssetManifest
    let destinationURL: URL

    func install(
        progressHandler: (@MainActor @Sendable (LocalModelInstallProgress) -> Void)? = nil
    ) async throws -> URL {
        guard let source = manifest.source else {
            throw LocalModelAssetInstallerError.missingSource(model: manifest.model.rawValue)
        }

        guard let repoID = Repo.ID(rawValue: source.repoID) else {
            throw LocalModelAssetInstallerError.invalidRepository(source.repoID)
        }

        await progressHandler?(.init(phase: .preparing))
        try FileManager.default.createDirectory(
            at: destinationURL,
            withIntermediateDirectories: true
        )

        let downloadedURL = try await HubClient.default.downloadSnapshot(
            of: repoID,
            kind: .model,
            to: destinationURL,
            revision: source.revision,
            matching: source.allowPatterns,
            maxConcurrentDownloads: 4
        ) { progress in
            progressHandler?(
                .init(
                    phase: .downloading,
                    completedUnitCount: progress.completedUnitCount,
                    totalUnitCount: progress.totalUnitCount
                )
            )
        }

        await progressHandler?(.init(phase: .validating))
        let state = modelAssetState(at: destinationURL)
        guard state.isUsable else {
            throw LocalModelAssetInstallerError.invalidAfterInstall(state.statusSummary)
        }

        await progressHandler?(.init(phase: .installed))
        return downloadedURL
    }

    private func modelAssetState(at url: URL) -> LocalModelAssetState {
        let path = url.path
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return .missing(expectedPath: path)
        }

        let childFileNames = Set((try? FileManager.default.contentsOfDirectory(atPath: path)) ?? [])
        let modelBytes = childFileNames.reduce(Int64(0)) { total, childFileName in
            guard childFileName.lowercased().hasSuffix(".\(manifest.requiredModelFileExtension.lowercased())") else {
                return total
            }

            let childURL = url.appendingPathComponent(childFileName, isDirectory: false)
            let size = (try? FileManager.default.attributesOfItem(atPath: childURL.path)[.size] as? NSNumber)?
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
}
