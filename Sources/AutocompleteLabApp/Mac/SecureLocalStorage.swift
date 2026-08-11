import Foundation

/// Creates and tightens Tilde's local on-disk artifacts to owner-only permissions
/// (directories `0700`, files `0600`).
///
/// Tilde writes its privacy-safe diagnostic log under `~/Library`. The file must
/// not depend on a parent directory's mode to stay private, so this helper makes
/// owner-only permissions explicit.
///
/// The create helpers also *tighten existing* artifacts, so the first write after upgrading
/// migrates files that were created world-readable by an earlier build.
enum SecureLocalStorage {
    /// Owner-only directory permissions (`rwx------`).
    static let directoryPermissions = NSNumber(value: Int16(0o700))
    /// Owner-only file permissions (`rw-------`).
    static let filePermissions = NSNumber(value: Int16(0o600))

    /// Create `directory` (and any missing intermediates) owner-only, tightening it if it
    /// already exists. Returns `true` when the directory exists with the intended mode.
    @discardableResult
    static func createDirectory(at directory: URL, fileManager: FileManager = .default) -> Bool {
        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: directoryPermissions]
            )
            // `createDirectory` only applies `attributes` to directories it actually creates;
            // tighten an already-existing leaf directory defensively (best effort).
            try? fileManager.setAttributes(
                [.posixPermissions: directoryPermissions],
                ofItemAtPath: directory.path
            )
            return true
        } catch {
            return false
        }
    }

    /// Ensure an empty owner-only file exists at `file` (creating it if needed), tightening an
    /// existing file's permissions. Returns `true` when the file exists with the intended mode.
    @discardableResult
    static func ensureFile(at file: URL, fileManager: FileManager = .default) -> Bool {
        if fileManager.fileExists(atPath: file.path) {
            try? fileManager.setAttributes(
                [.posixPermissions: filePermissions],
                ofItemAtPath: file.path
            )
            return true
        }

        return fileManager.createFile(
            atPath: file.path,
            contents: nil,
            attributes: [.posixPermissions: filePermissions]
        )
    }

}
