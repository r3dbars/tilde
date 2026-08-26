import Foundation

public actor LabCorpusCertificateStore {
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
                .appendingPathComponent("Corpus Certificates", isDirectory: true)
        }
    }

    public func save(_ certificate: LabCorpusModelCertificate) throws {
        try ensureDirectory()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let destination = file(for: certificate.corpusDigestSHA256)
        try encoder.encode(certificate).write(to: destination, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: destination.path
        )
    }

    public func load(corpusDigestSHA256: String) -> LabCorpusModelCertificate? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: file(for: corpusDigestSHA256)),
              let certificate = try? decoder.decode(LabCorpusModelCertificate.self, from: data),
              certificate.schema == LabCorpusModelCertificate.currentSchema,
              certificate.corpusDigestSHA256 == corpusDigestSHA256 else { return nil }
        return certificate
    }

    private func file(for digest: String) -> URL {
        directory.appendingPathComponent("\(digest).json")
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
