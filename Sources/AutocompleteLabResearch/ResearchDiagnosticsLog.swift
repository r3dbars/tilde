import Foundation

final class ResearchDiagnosticsLog: @unchecked Sendable {
    static let shared = ResearchDiagnosticsLog()

    private init() {}

    func record(_ event: String, metadata: [String: String]) {
        let fields = metadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        FileHandle.standardError.write(Data("[research] \(event) \(fields)\n".utf8))
    }
}
