import Foundation

public actor LabReportStore {
    public nonisolated let directory: URL

    public init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let support = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
            self.directory = support
                .appendingPathComponent("Tilde Lab", isDirectory: true)
                .appendingPathComponent("Runs", isDirectory: true)
        }
    }

    public func save(_ report: LabRunReport) throws {
        try report.validatedForPersistence()
        try ensureDirectory()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        let destination = directory.appendingPathComponent("\(report.id.uuidString).json")
        try data.write(to: destination, options: [.atomic])
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: destination.path
        )
    }

    public func loadAll() -> [LabRunReport] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return urls
            .filter { $0.pathExtension == "json" }
            .compactMap { try? Data(contentsOf: $0) }
            .compactMap { try? decoder.decode(LabRunReport.self, from: $0) }
            .filter { (try? $0.validatedForPersistence()) != nil }
            .sorted { $0.finishedAt > $1.finishedAt }
    }

    public func delete(_ report: LabRunReport) throws {
        let destination = directory.appendingPathComponent("\(report.id.uuidString).json")
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: directory.path
        )
    }
}
