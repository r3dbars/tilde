import TildeCore
import Foundation

public enum LabPersonalHistoryReplayLoaderError: Error, LocalizedError, Equatable, Sendable {
    case unsafePath
    case oversizedInput
    case tooManyEvents
    case oversizedLine
    case invalidJSONLine(Int)
    case unsupportedKey(String)
    case duplicateEventID(String)

    public var errorDescription: String? {
        switch self {
        case .unsafePath:
            "Personal History replay input must be a regular local file, not a symlink."
        case .oversizedInput:
            "Personal History replay input exceeds the 256 MiB local safety bound."
        case .tooManyEvents:
            "Personal History replay input exceeds one million events."
        case .oversizedLine:
            "A Personal History replay event exceeds the 16 KiB line bound."
        case let .invalidJSONLine(line):
            "Personal History replay line \(line) is not a valid bounded event."
        case let .unsupportedKey(key):
            "Personal History replay input contains unsupported key \(key)."
        case let .duplicateEventID(id):
            "Personal History replay contains duplicate event ID \(id)."
        }
    }
}

/// Strict, memory-only JSONL reader for an owner-selected Personal History
/// export. Callers receive validated events; this type never writes, logs, or
/// transforms the raw text into an artifact.
public enum LabPersonalHistoryReplayLoader {
    private static let maximumBytes = 256 * 1_024 * 1_024
    private static let maximumEvents = 1_000_000
    private static let maximumLineBytes = 16 * 1_024
    private static let allowedKeys: Set<String> = [
        "v", "id", "timestampMilliseconds", "historyIdentifier",
        "consentIdentifier", "sessionIdentifier", "appBundleIdentifier",
        "source", "text",
    ]

    public static func loadJSONLines(from url: URL) throws -> [PersonalHistoryEvent] {
        guard url.isFileURL else { throw LabPersonalHistoryReplayLoaderError.unsafePath }
        let values = try url.resourceValues(forKeys: [
            .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
        ])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw LabPersonalHistoryReplayLoaderError.unsafePath
        }
        guard (values.fileSize ?? 0) <= maximumBytes else {
            throw LabPersonalHistoryReplayLoaderError.oversizedInput
        }
        let bytes = try Data(contentsOf: url, options: [.mappedIfSafe])
        let lines = bytes.split(separator: 0x0A, omittingEmptySubsequences: true)
        guard lines.count <= maximumEvents else {
            throw LabPersonalHistoryReplayLoaderError.tooManyEvents
        }
        let decoder = JSONDecoder()
        var result: [PersonalHistoryEvent] = []
        result.reserveCapacity(lines.count)
        var identifiers = Set<String>()
        for (index, line) in lines.enumerated() {
            guard line.count <= maximumLineBytes else {
                throw LabPersonalHistoryReplayLoaderError.oversizedLine
            }
            let data = Data(line)
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw LabPersonalHistoryReplayLoaderError.invalidJSONLine(index + 1)
            }
            if let key = Set(object.keys).subtracting(allowedKeys).sorted().first {
                throw LabPersonalHistoryReplayLoaderError.unsupportedKey(key)
            }
            guard let event = try? decoder.decode(PersonalHistoryEvent.self, from: data) else {
                throw LabPersonalHistoryReplayLoaderError.invalidJSONLine(index + 1)
            }
            guard identifiers.insert(event.id).inserted else {
                throw LabPersonalHistoryReplayLoaderError.duplicateEventID(event.id)
            }
            result.append(event)
        }
        return result
    }
}
