import Foundation
import AutocompleteLabCore
import HuggingFace

struct LocalModelInstallProgress: Equatable, Sendable {
    let completedUnitCount: Int64
    let totalUnitCount: Int64

    init(completedUnitCount: Int64, totalUnitCount: Int64) {
        self.completedUnitCount = max(0, completedUnitCount)
        self.totalUnitCount = max(0, totalUnitCount)
    }

    init(progress: Progress) {
        self.init(
            completedUnitCount: progress.completedUnitCount,
            totalUnitCount: progress.totalUnitCount
        )
    }

    var percentageText: String {
        guard totalUnitCount > 0 else {
            return "starting"
        }

        let percentage = min(100, max(0, Int((Double(completedUnitCount) / Double(totalUnitCount)) * 100)))
        return "\(percentage)%"
    }
}

enum LocalModelInstallerError: LocalizedError, Equatable {
    case missingSource(LocalModelID)
    case invalidRepository(String)

    var errorDescription: String? {
        switch self {
        case let .missingSource(model):
            return "\(model.rawValue) does not have an app-owned download source."
        case let .invalidRepository(repoID):
            return "Invalid model repository: \(repoID)"
        }
    }
}

final class LocalModelInstaller: @unchecked Sendable {
    private let hubClient: HubClient
    private let fileManager: FileManager

    init(
        hubClient: HubClient = .default,
        fileManager: FileManager = .default
    ) {
        self.hubClient = hubClient
        self.fileManager = fileManager
    }

    func install(
        manifest: LocalModelAssetManifest,
        to destination: URL,
        progressHandler: (@MainActor @Sendable (LocalModelInstallProgress) -> Void)? = nil
    ) async throws -> URL {
        guard let source = manifest.source else {
            throw LocalModelInstallerError.missingSource(manifest.model)
        }

        guard let repoID = Repo.ID(rawValue: source.repoID) else {
            throw LocalModelInstallerError.invalidRepository(source.repoID)
        }

        try Task.checkCancellation()
        try fileManager.createDirectory(
            at: destination,
            withIntermediateDirectories: true
        )

        return try await hubClient.downloadSnapshot(
            of: repoID,
            to: destination,
            revision: source.revision,
            matching: source.allowPatterns,
            maxConcurrentDownloads: 4,
            progressHandler: { progress in
                progressHandler?(LocalModelInstallProgress(progress: progress))
            }
        )
    }
}
