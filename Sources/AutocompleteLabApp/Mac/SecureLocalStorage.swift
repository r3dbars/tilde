import Foundation

/// Creates and tightens SteadyType's local on-disk artifacts to owner-only permissions
/// (directories `0700`, files `0600`).
///
/// SteadyType writes derived-from-user data under `~/Library` — diagnostic traces (which can
/// hold raw text while raw-content dogfood tracing is opted in), the Personal Capture journal
/// (verbatim typed text), caret-region screenshots, and the downloaded model asset. macOS
/// currently keeps `~/Library` itself at `0700`, but these files must not *depend* on a parent
/// directory's mode to stay private: they are copied into backups, synced folders, and support
/// bundles, and the privacy guarantee should travel with the file. Default `FileManager`
/// creation honors the process umask (typically `022`), producing world-readable `0644` files
/// and `0755` directories — see `docs/security/threat-model.md` (F2). This helper makes the
/// permissions explicit instead.
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

    /// Ensure an owner-only file exists at `file` seeded with `contents` when it does not yet
    /// exist; tighten an existing file's permissions without overwriting its contents.
    @discardableResult
    static func ensureFile(
        at file: URL,
        seededWith contents: Data,
        fileManager: FileManager = .default
    ) -> Bool {
        if fileManager.fileExists(atPath: file.path) {
            try? fileManager.setAttributes(
                [.posixPermissions: filePermissions],
                ofItemAtPath: file.path
            )
            return true
        }

        return fileManager.createFile(
            atPath: file.path,
            contents: contents,
            attributes: [.posixPermissions: filePermissions]
        )
    }

    /// Tighten an existing file's permissions to owner-only. Used after an external writer
    /// (e.g. `/usr/sbin/screencapture`, atomic `Data.write`) creates the file with default mode.
    static func restrictFile(at file: URL, fileManager: FileManager = .default) {
        try? fileManager.setAttributes(
            [.posixPermissions: filePermissions],
            ofItemAtPath: file.path
        )
    }
}
