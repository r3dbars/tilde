import Foundation

/// Creates and tightens Tilde's local on-disk artifacts to owner-only permissions
/// (directories `0700`, files `0600`).
///
/// Tilde writes its privacy-safe diagnostic log under `~/Library`. The file must
/// not depend on a parent directory's mode to stay private, so this helper makes
/// owner-only permissions explicit.
///
/// Opening also tightens existing artifacts, so the first write after upgrading
/// migrates files that were created world-readable by an earlier build.
enum SecureLocalStorage {
    /// Creates and validates the owner-only parent, then opens the exact owner-only regular file.
    /// The parent remains open while `openat` resolves the leaf, so replacing it with a symlink
    /// cannot redirect the write.
    static func openFileForAppending(at file: URL) -> FileHandle? {
        openOwnerOnlyFile(
            at: file,
            flags: O_WRONLY | O_APPEND | O_CREAT | O_NONBLOCK
        )
    }

    static func openFileForReadingAndAppending(at file: URL) -> FileHandle? {
        openOwnerOnlyFile(at: file, flags: O_RDWR | O_APPEND | O_CREAT)
    }

    static func openExistingFileForReading(at file: URL) -> FileHandle? {
        openOwnerOnlyFile(at: file, flags: O_RDONLY)
    }

    /// Removes only an owner-owned regular file reached through a validated,
    /// non-symlink parent path. Missing files count as already removed.
    static func removeOwnerOnlyFile(at file: URL) -> Bool {
        let directory = file.deletingLastPathComponent()
        guard let directoryDescriptor = secureDirectoryDescriptor(at: directory),
              !file.lastPathComponent.isEmpty else { return false }
        defer { close(directoryDescriptor) }

        let descriptor = openat(
            directoryDescriptor,
            file.lastPathComponent,
            O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK
        )
        if descriptor < 0 { return errno == ENOENT }
        defer { close(descriptor) }

        var info = stat()
        guard fstat(descriptor, &info) == 0,
              info.st_mode & S_IFMT == S_IFREG,
              info.st_uid == getuid() else { return false }
        return unlinkat(directoryDescriptor, file.lastPathComponent, 0) == 0
    }

    private static func openOwnerOnlyFile(at file: URL, flags: Int32) -> FileHandle? {
        let directory = file.deletingLastPathComponent()
        guard let directoryDescriptor = secureDirectoryDescriptor(at: directory),
              !file.lastPathComponent.isEmpty else { return nil }
        defer { close(directoryDescriptor) }

        let descriptor = openat(
            directoryDescriptor,
            file.lastPathComponent,
            flags | O_NOFOLLOW | O_CLOEXEC,
            0o600
        )
        guard descriptor >= 0 else { return nil }

        var info = stat()
        guard fstat(descriptor, &info) == 0,
              info.st_mode & S_IFMT == S_IFREG,
              info.st_uid == getuid(),
              fchmod(descriptor, 0o600) == 0,
              fstat(descriptor, &info) == 0,
              info.st_mode & S_IFMT == S_IFREG,
              info.st_uid == getuid(),
              info.st_mode & 0o7777 == 0o600 else {
            close(descriptor)
            return nil
        }
        return FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    }

    private static func secureDirectoryDescriptor(at directory: URL) -> Int32? {
        let components = directory.path.split(separator: "/").map(String.init)
        guard directory.isFileURL, !components.isEmpty,
              !components.contains(where: { $0 == "." || $0 == ".." }) else { return nil }

        var parent = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard parent >= 0 else { return nil }

        for (index, component) in components.enumerated() {
            var child = openat(parent, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            var wasMissing = false
            if child < 0, errno == ENOENT {
                wasMissing = true
                guard mkdirat(parent, component, 0o700) == 0 || errno == EEXIST else {
                    close(parent)
                    return nil
                }
                child = openat(parent, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            }
            close(parent)
            guard child >= 0 else { return nil }

            let isLeaf = index == components.count - 1
            let mustTighten = wasMissing || isLeaf
            var info = stat()
            guard fstat(child, &info) == 0,
                  info.st_mode & S_IFMT == S_IFDIR,
                  !mustTighten || tightenDirectory(child, info: &info) else {
                close(child)
                return nil
            }
            parent = child
        }
        return parent
    }

    private static func tightenDirectory(_ descriptor: Int32, info: inout stat) -> Bool {
        guard info.st_uid == getuid(),
              fchmod(descriptor, 0o700) == 0,
              fstat(descriptor, &info) == 0 else { return false }
        return info.st_mode & S_IFMT == S_IFDIR
            && info.st_uid == getuid()
            && info.st_mode & 0o7777 == 0o700
    }
}
