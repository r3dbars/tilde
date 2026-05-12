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
    case insufficientDiskSpace(requiredBytes: Int64, availableBytes: Int64)
    case invalidAfterInstall(String)

    var errorDescription: String? {
        switch self {
        case let .missingSource(model):
            return "This model cannot be installed in the app yet: \(model). Open the model folder or choose the default model."
        case let .invalidRepository(repoID):
            return "The model download address is invalid: \(repoID)."
        case let .insufficientDiskSpace(requiredBytes, availableBytes):
            return "Not enough free space for the local model. Free about \(Self.gigabytes(requiredBytes - availableBytes)) GB and try again."
        case let .invalidAfterInstall(reason):
            return "The downloaded model files still look incomplete: \(reason)."
        }
    }

    private static func gigabytes(_ bytes: Int64) -> Int64 {
        max(1, Int64(ceil(Double(max(0, bytes)) / 1_000_000_000)))
    }
}

struct LocalModelInstallPreflightPolicy: Equatable, Sendable {
    let overheadMultiplier: Double

    init(overheadMultiplier: Double = 1.25) {
        self.overheadMultiplier = max(1, overheadMultiplier)
    }

    func validate(availableBytes: Int64?, expectedMinimumBytes: Int64) throws {
        guard let availableBytes else {
            return
        }

        let requiredBytes = Int64((Double(max(1, expectedMinimumBytes)) * overheadMultiplier).rounded(.up))
        guard availableBytes >= requiredBytes else {
            throw LocalModelAssetInstallerError.insufficientDiskSpace(
                requiredBytes: requiredBytes,
                availableBytes: max(0, availableBytes)
            )
        }
    }
}

struct LocalModelInstallVolumeCapacityResolver: Equatable, Sendable {
    func installVolumeURL(
        for destinationURL: URL,
        fileManager: FileManager = .default
    ) -> URL {
        var candidate = destinationURL.deletingLastPathComponent()
        while !fileManager.fileExists(atPath: candidate.path) {
            let parent = candidate.deletingLastPathComponent()
            guard parent.path != candidate.path else {
                return candidate
            }
            candidate = parent
        }
        return candidate
    }

    func availableBytes(
        for destinationURL: URL,
        fileManager: FileManager = .default
    ) -> Int64? {
        let volumeURL = installVolumeURL(for: destinationURL, fileManager: fileManager)
        let values = try? volumeURL.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ])
        return values?.volumeAvailableCapacityForImportantUsage
            ?? values?.volumeAvailableCapacity.map(Int64.init)
    }
}

struct LocalModelAssetInstaller: Sendable {
    let manifest: LocalModelAssetManifest
    let destinationURL: URL
    let preflightPolicy: LocalModelInstallPreflightPolicy
    let capacityResolver: LocalModelInstallVolumeCapacityResolver

    init(
        manifest: LocalModelAssetManifest,
        destinationURL: URL,
        preflightPolicy: LocalModelInstallPreflightPolicy = LocalModelInstallPreflightPolicy(),
        capacityResolver: LocalModelInstallVolumeCapacityResolver = LocalModelInstallVolumeCapacityResolver()
    ) {
        self.manifest = manifest
        self.destinationURL = destinationURL
        self.preflightPolicy = preflightPolicy
        self.capacityResolver = capacityResolver
    }

    func install(
        progressHandler: (@MainActor @Sendable (LocalModelInstallProgress) -> Void)? = nil
    ) async throws -> URL {
        guard let source = manifest.source else {
            throw LocalModelAssetInstallerError.missingSource(model: manifest.model.rawValue)
        }

        guard let repoID = Repo.ID(rawValue: source.repoID) else {
            throw LocalModelAssetInstallerError.invalidRepository(source.repoID)
        }

        try preflightPolicy.validate(
            availableBytes: availableBytesForInstallVolume(),
            expectedMinimumBytes: manifest.expectedMinimumBytes
        )

        await progressHandler?(.init(phase: .preparing))
        let scratchURL = destinationURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(manifest.fileName).download-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: scratchURL,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: scratchURL)
        }

        let downloadedURL = try await HubClient.default.downloadSnapshot(
            of: repoID,
            kind: .model,
            to: scratchURL,
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
        do {
            try ModelAssetInstaller.finalizeDownloadedSnapshot(
                manifest: manifest,
                snapshotURL: downloadedURL,
                targetURL: destinationURL
            )
        } catch let error as ModelAssetInstallerError {
            throw LocalModelAssetInstallerError.invalidAfterInstall(error.localizedDescription)
        }

        let state = modelAssetState(at: destinationURL)
        guard state.isUsable else {
            throw LocalModelAssetInstallerError.invalidAfterInstall(state.statusSummary)
        }

        await progressHandler?(.init(phase: .installed))
        return destinationURL
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

        let structureState = manifest.validatedDirectoryState(
            path: path,
            isDirectory: isDirectory.boolValue,
            childFileNames: childFileNames,
            modelBytes: modelBytes
        )

        guard structureState.isUsable else {
            return structureState
        }

        if let integrityError = ModelAssetIntegrityReceiptValidator.validate(
            manifest: manifest,
            modelDirectoryURL: url
        ) {
            return .invalid(path: path, reason: integrityError)
        }

        return structureState
    }

    private func availableBytesForInstallVolume() -> Int64? {
        capacityResolver.availableBytes(for: destinationURL)
    }
}
