import Foundation

public enum LabSimulatedTypistArmFileError: Error, LocalizedError, Equatable, Sendable {
    case notAbsolutePath(String)
    case unsafePath(String)
    case unreadable(path: String, reason: String)
    case malformed(path: String, reason: String)
    case invalidArm(path: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case let .notAbsolutePath(path):
            "The simulated-typist arm file must be an absolute path: \(path)."
        case let .unsafePath(path):
            "The simulated-typist arm file is not an owner-controlled regular file: \(path)."
        case let .unreadable(path, reason):
            "Could not read the simulated-typist arm file \(path): \(reason)"
        case let .malformed(path, reason):
            "The simulated-typist arm file \(path) is not one campaign arm object: \(reason)"
        case let .invalidArm(path, reason):
            "The simulated-typist arm file \(path) holds an invalid arm: \(reason)"
        }
    }
}

/// Loads the single arm a simulated-typist run is pinned to.
///
/// The file holds exactly one `LabArmConfiguration` object — the same shape a
/// campaign manifest stores in `arms[]`, decoded by the same `Codable` type and
/// checked by the same validation `tilde-lab validate` runs. Nothing else about
/// the run changes: the loaded arm takes the place of the built-in baseline, so
/// its prompt, generation, and judgment settings reach the completion path and
/// the display judge exactly the way a campaign arm's do.
public enum LabSimulatedTypistArmFile {
    /// `path` is an absolute file path — `~` is expanded first, exactly as the
    /// external decision command's path is. An arm file names one frozen
    /// configuration; a relative path would name a different file depending on
    /// where the run was launched from.
    public static func load(atPath path: String) throws -> LabArmConfiguration {
        let expanded = (path as NSString).expandingTildeInPath
        guard expanded.hasPrefix("/") else {
            throw LabSimulatedTypistArmFileError.notAbsolutePath(path)
        }
        return try load(at: URL(fileURLWithPath: expanded).standardizedFileURL)
    }

    public static func load(at url: URL) throws -> LabArmConfiguration {
        let path = url.path
        guard url.isFileURL else { throw LabSimulatedTypistArmFileError.unsafePath(path) }
        let values: URLResourceValues
        do {
            values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        } catch {
            throw LabSimulatedTypistArmFileError.unreadable(
                path: path, reason: error.localizedDescription
            )
        }
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw LabSimulatedTypistArmFileError.unsafePath(path)
        }
        let data: Data
        do {
            data = try Data(contentsOf: url, options: [.mappedIfSafe])
        } catch {
            throw LabSimulatedTypistArmFileError.unreadable(
                path: path, reason: error.localizedDescription
            )
        }
        let arm: LabArmConfiguration
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            arm = try decoder.decode(LabArmConfiguration.self, from: data)
        } catch {
            throw LabSimulatedTypistArmFileError.malformed(
                path: path, reason: error.localizedDescription
            )
        }
        do {
            return try arm.validated()
        } catch {
            throw LabSimulatedTypistArmFileError.invalidArm(
                path: path, reason: error.localizedDescription
            )
        }
    }
}
