import Foundation
import AutocompleteLabCore
import Hub

struct ModelAssetInstallProgress: Equatable, Sendable {
    let phase: String
    let completedUnitCount: Int64
    let totalUnitCount: Int64
    let throughputBytesPerSecond: Int64?

    var statusText: String {
        let boundedTotal = max(totalUnitCount, 0)
        let boundedCompleted = max(completedUnitCount, 0)
        guard boundedTotal > 0 else {
            return "Model install: \(phase)"
        }

        let percent = min(100, Int((Double(boundedCompleted) / Double(boundedTotal)) * 100))
        if let throughputBytesPerSecond, throughputBytesPerSecond > 0 {
            return "Model install: \(phase) \(percent)% at \(Self.formatBytes(throughputBytesPerSecond))/s"
        }

        return "Model install: \(phase) \(percent)%"
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        let units = ["B", "KiB", "MiB", "GiB"]
        var size = Double(max(bytes, 0))
        for unit in units {
            if size < 1024 || unit == units.last {
                if unit == "B" {
                    return "\(Int(size)) \(unit)"
                }

                return String(format: "%.1f %@", size, unit)
            }
            size /= 1024
        }

        return "\(bytes) B"
    }
}

enum ModelAssetInstallerError: LocalizedError {
    case missingSource(LocalModelID)
    case missingDownloadedSnapshot(String)
    case invalidDownloadedAsset(String)

    var errorDescription: String? {
        switch self {
        case let .missingSource(model):
            return "No download source is configured for \(model.rawValue)."
        case let .missingDownloadedSnapshot(path):
            return "Downloaded model snapshot was not found at \(path)."
        case let .invalidDownloadedAsset(reason):
            return "Downloaded model snapshot is invalid: \(reason)."
        }
    }
}

struct ModelAssetInstaller {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func install(
        manifest: LocalModelAssetManifest,
        targetURL: URL,
        progressHandler: @escaping @Sendable (ModelAssetInstallProgress) -> Void = { _ in }
    ) async throws {
        guard let source = manifest.source else {
            throw ModelAssetInstallerError.missingSource(manifest.model)
        }

        let scratchURL = targetURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(manifest.fileName).download-\(UUID().uuidString)", isDirectory: true)

        try fileManager.createDirectory(at: scratchURL, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: scratchURL)
        }

        progressHandler(ModelAssetInstallProgress(
            phase: "preparing",
            completedUnitCount: 0,
            totalUnitCount: 0,
            throughputBytesPerSecond: nil
        ))

        let hub = HubApi(downloadBase: scratchURL, useBackgroundSession: false)
        let snapshotURL = try await hub.snapshot(
            from: source.repoID,
            revision: source.revision,
            matching: source.allowPatterns
        ) { progress in
            let throughput = (progress.userInfo[.throughputKey] as? Double).map(Int64.init)
            progressHandler(ModelAssetInstallProgress(
                phase: "downloading",
                completedUnitCount: progress.completedUnitCount,
                totalUnitCount: progress.totalUnitCount,
                throughputBytesPerSecond: throughput
            ))
        }

        try Task.checkCancellation()
        try Self.finalizeDownloadedSnapshot(
            manifest: manifest,
            snapshotURL: snapshotURL,
            targetURL: targetURL,
            fileManager: fileManager
        )
        progressHandler(ModelAssetInstallProgress(
            phase: "installed",
            completedUnitCount: 1,
            totalUnitCount: 1,
            throughputBytesPerSecond: nil
        ))
    }

    static func finalizeDownloadedSnapshot(
        manifest: LocalModelAssetManifest,
        snapshotURL: URL,
        targetURL: URL,
        fileManager: FileManager = .default
    ) throws {
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: snapshotURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ModelAssetInstallerError.missingDownloadedSnapshot(snapshotURL.path)
        }

        let childFileNames = Set(try fileManager.contentsOfDirectory(atPath: snapshotURL.path))
        let modelBytes = try childFileNames.reduce(Int64(0)) { total, childFileName in
            guard childFileName.lowercased().hasSuffix(".\(manifest.requiredModelFileExtension.lowercased())") else {
                return total
            }

            let childURL = snapshotURL.appendingPathComponent(childFileName, isDirectory: false)
            let size = try fileManager
                .attributesOfItem(atPath: childURL.path)[.size] as? NSNumber

            return total + (size?.int64Value ?? 0)
        }

        switch manifest.validatedDirectoryState(
            path: snapshotURL.path,
            isDirectory: true,
            childFileNames: childFileNames,
            modelBytes: modelBytes
        ) {
        case .available:
            break
        case let .missing(expectedPath):
            throw ModelAssetInstallerError.invalidDownloadedAsset("missing model asset at \(expectedPath)")
        case let .invalid(_, reason):
            throw ModelAssetInstallerError.invalidDownloadedAsset(reason)
        }

        let parentURL = targetURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true)

        let backupURL = parentURL.appendingPathComponent(
            ".\(targetURL.lastPathComponent).backup-\(UUID().uuidString)",
            isDirectory: true
        )
        let targetExists = fileManager.fileExists(atPath: targetURL.path)
        if targetExists {
            try fileManager.moveItem(at: targetURL, to: backupURL)
        }

        do {
            try fileManager.moveItem(at: snapshotURL, to: targetURL)
            if targetExists {
                try? fileManager.removeItem(at: backupURL)
            }
        } catch {
            if targetExists, fileManager.fileExists(atPath: backupURL.path) {
                try? fileManager.moveItem(at: backupURL, to: targetURL)
            }
            throw error
        }
    }
}
