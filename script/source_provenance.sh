#!/usr/bin/env bash
# Shared, fail-closed source identity for decision-grade packaged builds.
# Preview builders source this file; direct execution is limited to --selftest.

TILDE_BUILD_SOURCE_ROOT=""
TILDE_BUILD_SOURCE_TEMP=""
TILDE_BUILD_SCRATCH_PATH=""
TILDE_DEVELOPER_DIR=""
TILDE_SWIFT_EXECUTABLE=""
TILDE_SWIFT_EXECUTABLE_SHA256=""
TILDE_XCODE_VERSION=""
TILDE_XCODE_BUILD=""
TILDE_XCODE_CDHASH=""
TILDE_SWIFT_VERSION_SHA256=""
TILDE_MACOS_SDK_VERSION=""
TILDE_MACOS_SDK_BUILD=""
TILDE_MACOS_SDK_PATH=""
TILDE_MACOS_SDK_SETTINGS_SHA256=""
TILDE_APPLE_TOOLCHAIN_SHA256=""
TILDE_SWIFT_BUILD_EXECUTABLE_SHA256=""
TILDE_SWIFT_DRIVER_EXECUTABLE_SHA256=""
TILDE_CLANG_EXECUTABLE_SHA256=""
TILDE_LINKER_EXECUTABLE_SHA256=""
TILDE_LIBTOOL_EXECUTABLE_SHA256=""
TILDE_ARCHIVER_EXECUTABLE_SHA256=""
TILDE_HELPER_INPUT_SHA256=""
TILDE_HELPER_APPROVED_TEAM=""
TILDE_HELPER_STAGED_IDENTITY=""
TILDE_F03_RUNNER_SHA256=""

# Git source identity must not inherit caller-selected repositories, indexes,
# object stores, replacement objects, global attributes, or optional caches.
# Repository-local configuration remains available, but the controls that can
# suppress worktree inspection are overridden below.
tilde_git_raw() {
  local root="$1"
  shift
  /usr/bin/env -i \
    HOME=/var/empty \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin \
    LC_ALL=C \
    GIT_NO_REPLACE_OBJECTS=1 \
    GIT_CONFIG_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL=/dev/null \
    GIT_ATTR_NOSYSTEM=1 \
    /usr/bin/git --no-optional-locks \
      -c core.fsmonitor=false \
      -c core.untrackedCache=false \
      -c core.attributesFile=/dev/null \
      -C "$root" "$@"
}

# macOS /usr/bin/python3 may itself resolve through the active developer tools.
# A fully empty caller environment prevents DEVELOPER_DIR, PYTHONPATH, user-site,
# and dynamic-loader poisoning before isolated mode even starts.
tilde_python_isolated() {
  /usr/bin/env -i \
    HOME=/var/empty \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin \
    LC_ALL=C \
    /usr/bin/python3 -I -S "$@"
}

tilde_reject_unsafe_git_metadata() {
  local root="$1" grafts
  [[ -z "$(tilde_git_raw "$root" replace -l)" ]] || {
    echo "decision-grade source may not use Git replacement objects" >&2
    return 1
  }
  grafts="$(tilde_git_raw "$root" rev-parse --path-format=absolute --git-path info/grafts)"
  [[ ! -e "$grafts" && ! -L "$grafts" ]] || {
    echo "decision-grade source may not use legacy Git grafts" >&2
    return 1
  }
  if ! tilde_git_raw "$root" ls-files -v -z \
      | tilde_python_isolated -c '
import sys
for record in sys.stdin.buffer.read().split(b"\0"):
    if not record:
        continue
    tag = record[:1]
    if tag == b"S" or (b"a" <= tag <= b"z"):
        raise SystemExit(1)
'; then
    echo "decision-grade source may not use assume-unchanged or skip-worktree index flags" >&2
    return 1
  fi
}

tilde_cleanup_build_source() {
  local temporary="${TILDE_BUILD_SOURCE_TEMP:-}"
  [[ -n "$temporary" ]] || return 0
  case "${temporary##*/}" in
    tilde-build-source.*) ;;
    *) echo "refusing to remove an unrecognized build-source directory" >&2; return 1 ;;
  esac
  [[ -d "$temporary" && ! -L "$temporary" \
      && "$(/usr/bin/stat -f '%u' "$temporary")" == "$(/usr/bin/id -u)" ]] \
    || { echo "refusing to remove an unsafe build-source directory" >&2; return 1; }
  if [[ -d "$temporary/source" && ! -L "$temporary/source" ]]; then
    /usr/bin/find "$temporary/source" -type d -exec /bin/chmod u+rwx {} +
    /usr/bin/find "$temporary/source" -type f -exec /bin/chmod u+rw {} +
  fi
  if [[ -d "$temporary/scratch" && ! -L "$temporary/scratch" ]]; then
    /usr/bin/find "$temporary/scratch" -type d -exec /bin/chmod u+rwx {} +
  fi
  /bin/rm -rf -- "$temporary"
  TILDE_BUILD_SOURCE_ROOT=""
  TILDE_BUILD_SOURCE_TEMP=""
  TILDE_BUILD_SCRATCH_PATH=""
  export TILDE_BUILD_SOURCE_ROOT TILDE_BUILD_SOURCE_TEMP TILDE_BUILD_SCRATCH_PATH
}

tilde_make_build_source_read_only() {
  local source="$1"
  tilde_python_isolated - "$source" <<'PY'
import os
import stat
import sys

root = sys.argv[1]
directories = []
for directory, names, files in os.walk(root, topdown=True, followlinks=False):
    directories.append(directory)
    for name in names:
        path = os.path.join(directory, name)
        info = os.lstat(path)
        if not stat.S_ISDIR(info.st_mode):
            raise SystemExit("decision-grade source archives may not contain links or special entries")
    for name in files:
        path = os.path.join(directory, name)
        info = os.lstat(path)
        if not stat.S_ISREG(info.st_mode):
            raise SystemExit("decision-grade source archives may not contain links or special entries")
        os.chmod(path, 0o500 if info.st_mode & 0o111 else 0o400)
for directory in reversed(directories):
    os.chmod(directory, 0o500)
PY
}

# A canonical digest of the bytes the compiler can read. The archive has
# already canonicalized Git's 100644/100755 modes to 0400/0500 and directories
# to 0500, so the manifest binds paths, entry types, modes, lengths, and bytes.
tilde_source_tree_manifest_sha256() {
  local source="$1"
  tilde_python_isolated - "$source" <<'PY'
import hashlib
import os
import stat
import sys

root = os.fsencode(os.path.abspath(sys.argv[1]))
root_info = os.lstat(root)
if (
    not stat.S_ISDIR(root_info.st_mode)
    or root_info.st_uid != os.getuid()
    or stat.S_IMODE(root_info.st_mode) != 0o500
):
    raise SystemExit("sealed source root is unsafe")

entries = []
for directory, names, files in os.walk(root, topdown=True, followlinks=False):
    names.sort()
    files.sort()
    for name in names:
        path = os.path.join(directory, name)
        info = os.lstat(path)
        if not stat.S_ISDIR(info.st_mode):
            raise SystemExit("sealed source contains a link or special entry")
        entries.append((os.path.relpath(path, root), b"D", info))
    for name in files:
        path = os.path.join(directory, name)
        info = os.lstat(path)
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
            raise SystemExit("sealed source contains a link or special entry")
        entries.append((os.path.relpath(path, root), b"F", info))

entries.sort(key=lambda entry: entry[0])
digest = hashlib.sha256()
digest.update(b"tilde-source-tree-manifest-v1\0")
for relative, kind, info in entries:
    path = os.path.join(root, relative)
    expected_mode = 0o500 if kind == b"D" or info.st_mode & 0o111 else 0o400
    if (
        info.st_uid != os.getuid()
        or stat.S_IMODE(info.st_mode) != expected_mode
    ):
        raise SystemExit("sealed source entry permissions changed")
    digest.update(kind)
    digest.update(len(relative).to_bytes(8, "big"))
    digest.update(relative)
    digest.update(expected_mode.to_bytes(4, "big"))
    if kind == b"F":
        digest.update(info.st_size.to_bytes(8, "big"))
        descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
        try:
            held = os.fstat(descriptor)
            if (
                not stat.S_ISREG(held.st_mode)
                or held.st_uid != info.st_uid
                or held.st_nlink != 1
                or (held.st_dev, held.st_ino) != (info.st_dev, info.st_ino)
                or held.st_size != info.st_size
                or stat.S_IMODE(held.st_mode) != expected_mode
            ):
                raise SystemExit("sealed source entry changed during hashing")
            remaining = held.st_size
            while remaining:
                chunk = os.read(descriptor, min(1024 * 1024, remaining))
                if not chunk:
                    raise SystemExit("sealed source entry was truncated")
                digest.update(chunk)
                remaining -= len(chunk)
            if os.read(descriptor, 1):
                raise SystemExit("sealed source entry grew during hashing")
            visible = os.lstat(path)
            if (visible.st_dev, visible.st_ino) != (held.st_dev, held.st_ino):
                raise SystemExit("sealed source entry was path-replaced")
        finally:
            os.close(descriptor)

print(digest.hexdigest())
PY
}

tilde_remove_private_source_tree() {
  local temporary="$1" expected_prefix="$2"
  [[ -n "$temporary" && "${temporary##*/}" == "$expected_prefix".* \
      && -d "$temporary" && ! -L "$temporary" \
      && "$(/usr/bin/stat -f '%u' "$temporary")" == "$(/usr/bin/id -u)" ]] \
    || { echo "refusing to remove an unsafe source-manifest directory" >&2; return 1; }
  /usr/bin/find "$temporary" -type d -exec /bin/chmod u+rwx {} +
  /usr/bin/find "$temporary" -type f -exec /bin/chmod u+rw {} +
  /bin/rm -rf -- "$temporary"
}

# Independently materialize the raw commit so callers such as the F03 runner can
# reproduce exactly the same manifest without retaining a build-source tree.
tilde_clean_commit_manifest_sha256() (
  set -euo pipefail
  local root="$1" commit="$2" temporary archive source digest
  temporary="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/tilde-source-manifest.XXXXXX")"
  /bin/chmod 700 "$temporary"
  trap 'tilde_remove_private_source_tree "$temporary" tilde-source-manifest' EXIT
  archive="$temporary/source.tar"
  source="$temporary/source"
  /bin/mkdir -m 700 "$source"
  tilde_git_raw "$root" archive --format=tar --output="$archive" "$commit"
  /usr/bin/tar -xf "$archive" -C "$source"
  /bin/rm -f -- "$archive"
  tilde_make_build_source_read_only "$source"
  digest="$(tilde_source_tree_manifest_sha256 "$source")"
  [[ "$digest" =~ ^[0-9a-f]{64}$ ]]
  printf '%s\n' "$digest"
)

# Materializes the exact clean commit for decision-grade compilation. Dirty
# diagnostic builds intentionally keep using the live worktree they describe.
tilde_prepare_build_source() {
  local root="$1" evidence_class="${2:-decision-grade}" unexpected_entry archive manifest
  if [[ -n "${TILDE_BUILD_SOURCE_TEMP:-}" ]]; then
    tilde_cleanup_build_source || return
  fi
  tilde_capture_source_provenance "$root" "$evidence_class" || return

  if [[ "$evidence_class" == "diagnostic" ]]; then
    TILDE_BUILD_SOURCE_ROOT="$(cd "$root" && pwd -P)"
    TILDE_BUILD_SOURCE_TEMP=""
    TILDE_BUILD_SCRATCH_PATH="$TILDE_BUILD_SOURCE_ROOT/.build"
    export TILDE_BUILD_SOURCE_ROOT TILDE_BUILD_SOURCE_TEMP TILDE_BUILD_SCRATCH_PATH
    return 0
  fi

  [[ "$TILDE_SOURCE_STATE" == "clean" ]] \
    || { echo "decision-grade build source must be clean" >&2; return 1; }
  unexpected_entry="$(
    tilde_git_raw "$root" ls-tree -r "$TILDE_SOURCE_COMMIT" \
      | /usr/bin/awk '$1 != "100644" && $1 != "100755" { print; exit }'
  )"
  [[ -z "$unexpected_entry" ]] || {
    echo "decision-grade source archive contains a link, submodule, or special entry" >&2
    return 1
  }

  TILDE_BUILD_SOURCE_TEMP="$(
    /usr/bin/mktemp -d "${TMPDIR:-/tmp}/tilde-build-source.XXXXXX"
  )"
  /bin/chmod 700 "$TILDE_BUILD_SOURCE_TEMP"
  TILDE_BUILD_SOURCE_ROOT="$TILDE_BUILD_SOURCE_TEMP/source"
  TILDE_BUILD_SCRATCH_PATH="$TILDE_BUILD_SOURCE_TEMP/scratch"
  /bin/mkdir -m 700 "$TILDE_BUILD_SOURCE_ROOT" "$TILDE_BUILD_SCRATCH_PATH"
  export TILDE_BUILD_SOURCE_ROOT TILDE_BUILD_SOURCE_TEMP TILDE_BUILD_SCRATCH_PATH

  archive="$TILDE_BUILD_SOURCE_TEMP/source.tar"
  if ! tilde_git_raw "$root" archive --format=tar \
      --output="$archive" "$TILDE_SOURCE_COMMIT"; then
    tilde_cleanup_build_source
    return 1
  fi
  if ! /usr/bin/tar -xf "$archive" -C "$TILDE_BUILD_SOURCE_ROOT"; then
    tilde_cleanup_build_source
    return 1
  fi
  /bin/rm -f -- "$archive"
  if ! tilde_make_build_source_read_only "$TILDE_BUILD_SOURCE_ROOT"; then
    tilde_cleanup_build_source
    return 1
  fi
  manifest="$(tilde_source_tree_manifest_sha256 "$TILDE_BUILD_SOURCE_ROOT")" || {
    tilde_cleanup_build_source
    return 1
  }
  [[ "$manifest" == "$TILDE_SOURCE_SNAPSHOT_SHA256" ]] || {
    echo "materialized source does not match the captured commit manifest" >&2
    tilde_cleanup_build_source
    return 1
  }
}

tilde_verify_model_file() {
  local path="$1" expected_bytes="$2" expected_sha="$3" label="$4"
  local selftest_mode="${5:-}"
  tilde_python_isolated - \
    "$path" "$expected_bytes" "$expected_sha" "$label" "$selftest_mode" <<'PY'
import hashlib
import fcntl
import os
import stat
import sys

path, expected_bytes, expected_sha, label, selftest_mode = sys.argv[1:]
try:
    expected_size = int(expected_bytes)
    if expected_size <= 0 or len(expected_sha) != 64:
        raise ValueError
    if selftest_mode not in ("", "selftest-inplace-touch"):
        raise ValueError
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    try:
        fcntl.flock(descriptor, fcntl.LOCK_SH)
        info = os.fstat(descriptor)
        if (
            not stat.S_ISREG(info.st_mode)
            or info.st_uid != os.getuid()
            or info.st_nlink != 1
            or stat.S_IMODE(info.st_mode) & 0o022
            or info.st_size != expected_size
        ):
            raise ValueError
        flags = fcntl.fcntl(descriptor, fcntl.F_GETFL)
        fcntl.fcntl(descriptor, fcntl.F_SETFL, flags & ~os.O_NONBLOCK)
        digest = hashlib.sha256()
        prefix = b""
        touched = False
        while chunk := os.read(descriptor, 1024 * 1024):
            if len(prefix) < 4:
                prefix += chunk[: 4 - len(prefix)]
            digest.update(chunk)
            if selftest_mode == "selftest-inplace-touch" and not touched:
                writer = os.open(path, os.O_WRONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
                try:
                    os.pwrite(writer, chunk[:1], 0)
                    os.fsync(writer)
                finally:
                    os.close(writer)
                touched = True
        final_info = os.fstat(descriptor)
        if (
            prefix != b"GGUF"
            or digest.hexdigest() != expected_sha
            or (
                info.st_dev,
                info.st_ino,
                info.st_mode,
                info.st_uid,
                info.st_nlink,
                info.st_size,
                info.st_mtime_ns,
                info.st_ctime_ns,
            )
            != (
                final_info.st_dev,
                final_info.st_ino,
                final_info.st_mode,
                final_info.st_uid,
                final_info.st_nlink,
                final_info.st_size,
                final_info.st_mtime_ns,
                final_info.st_ctime_ns,
            )
        ):
            raise ValueError
    finally:
        os.close(descriptor)
except (OSError, ValueError):
    print(f"{label} model identity is unsafe or mismatched", file=sys.stderr)
    raise SystemExit(1)
PY
}

# Bind every signed preview to the exact F03 maintenance runner contained in
# the same captured source tree. F03 closeout later requires the receipt's
# sealed-runner digest to match this signed plist value in both app and IME.
tilde_capture_f03_runner_identity() {
  local path="$1"
  TILDE_F03_RUNNER_SHA256="$(
    tilde_python_isolated - "$path" <<'PY'
import fcntl
import hashlib
import os
import stat
import sys

path = os.path.abspath(sys.argv[1])
descriptor = os.open(
    path,
    os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC,
)
try:
    before = os.fstat(descriptor)
    visible = os.lstat(path)
    mode = stat.S_IMODE(before.st_mode)
    if (
        not stat.S_ISREG(before.st_mode)
        or not stat.S_ISREG(visible.st_mode)
        or before.st_uid != os.getuid()
        or visible.st_uid != os.getuid()
        or before.st_nlink != 1
        or visible.st_nlink != 1
        or not (mode & 0o100)
        or mode & 0o022
        or before.st_size <= 0
        or before.st_size > 2 * 1024 * 1024
        or (before.st_dev, before.st_ino) != (visible.st_dev, visible.st_ino)
    ):
        raise RuntimeError("F03 runner has unsafe source identity")
    flags = fcntl.fcntl(descriptor, fcntl.F_GETFL)
    fcntl.fcntl(descriptor, fcntl.F_SETFL, flags & ~os.O_NONBLOCK)
    digest = hashlib.sha256()
    size = 0
    while chunk := os.read(descriptor, 1024 * 1024):
        digest.update(chunk)
        size += len(chunk)
    after = os.fstat(descriptor)
    final_visible = os.lstat(path)
    if (
        size != before.st_size
        or (before.st_dev, before.st_ino, before.st_size, before.st_nlink, mode)
            != (
                after.st_dev,
                after.st_ino,
                after.st_size,
                after.st_nlink,
                stat.S_IMODE(after.st_mode),
            )
        or (before.st_dev, before.st_ino)
            != (final_visible.st_dev, final_visible.st_ino)
    ):
        raise RuntimeError("F03 runner changed while its identity was captured")
    print(digest.hexdigest())
finally:
    os.close(descriptor)
PY
  )" || return
  [[ "$TILDE_F03_RUNNER_SHA256" =~ ^[0-9a-f]{64}$ ]] \
    || { echo "F03 runner identity is malformed" >&2; return 1; }
  export TILDE_F03_RUNNER_SHA256
}

tilde_remove_exact_regular_file() {
  local path="$1" identity="$2"
  tilde_python_isolated - "$path" "$identity" <<'PY'
import os
import stat
import sys

path, identity = sys.argv[1:]
try:
    expected_device, expected_inode = (int(value) for value in identity.split(":", 1))
    parent_path, leaf = os.path.split(os.path.abspath(path))
    parent = os.open(
        parent_path,
        os.O_RDONLY
        | os.O_DIRECTORY
        | getattr(os, "O_NOFOLLOW_ANY", 0x20000000)
        | os.O_CLOEXEC,
    )
    try:
        visible = os.stat(leaf, dir_fd=parent, follow_symlinks=False)
        if (
            not stat.S_ISREG(visible.st_mode)
            or (visible.st_dev, visible.st_ino) != (expected_device, expected_inode)
        ):
            raise ValueError
        os.unlink(leaf, dir_fd=parent)
        os.fsync(parent)
    finally:
        os.close(parent)
except (OSError, ValueError):
    print("refusing to unlink a path-replaced staged file", file=sys.stderr)
    raise SystemExit(1)
PY
}

# Copy an authenticated helper candidate from the exact descriptor whose digest
# was checked. The returned device:inode identity is used for safe cleanup if a
# later signature/team check fails.
tilde_stage_helper_bytes_by_fd() {
  local source="$1" destination="$2" expected_sha="$3"
  # The optional mode is a fail-only deterministic selftest hook: it corrupts
  # the private destination, never the approved source, and must be rejected.
  local selftest_mode="${4:-}"
  tilde_python_isolated - \
    "$source" "$destination" "$expected_sha" "$selftest_mode" <<'PY'
import fcntl
import hashlib
import os
import stat
import string
import sys

source, destination, expected_sha, selftest_mode = sys.argv[1:]
expected_sha = expected_sha.lower()
if len(expected_sha) != 64 or any(character not in string.hexdigits for character in expected_sha):
    raise SystemExit("helper SHA-256 is malformed")
if selftest_mode not in ("", "selftest-corrupt-copy"):
    raise SystemExit("helper staging selftest mode is malformed")

source_descriptor = None
destination_descriptor = None
parent = None
created_identity = None
success = False
try:
    source_descriptor = os.open(
        source,
        os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC,
    )
    source_info = os.fstat(source_descriptor)
    if (
        not stat.S_ISREG(source_info.st_mode)
        or source_info.st_uid not in (0, os.getuid())
        or source_info.st_nlink != 1
        or stat.S_IMODE(source_info.st_mode) & 0o022
        or not stat.S_IMODE(source_info.st_mode) & 0o111
        or source_info.st_size <= 0
        or source_info.st_size > 2 * 1024 * 1024 * 1024
    ):
        raise ValueError
    flags = fcntl.fcntl(source_descriptor, fcntl.F_GETFL)
    fcntl.fcntl(source_descriptor, fcntl.F_SETFL, flags & ~os.O_NONBLOCK)
    fcntl.flock(source_descriptor, fcntl.LOCK_SH)
    digest = hashlib.sha256()
    remaining = source_info.st_size
    while remaining:
        chunk = os.read(source_descriptor, min(1024 * 1024, remaining))
        if not chunk:
            raise ValueError
        digest.update(chunk)
        remaining -= len(chunk)
    if os.read(source_descriptor, 1) or digest.hexdigest() != expected_sha:
        raise ValueError
    os.lseek(source_descriptor, 0, os.SEEK_SET)

    destination = os.path.abspath(destination)
    parent_path, leaf = os.path.split(destination)
    if not leaf or os.path.realpath(parent_path) != parent_path:
        raise ValueError
    parent = os.open(
        parent_path,
        os.O_RDONLY
        | os.O_DIRECTORY
        | getattr(os, "O_NOFOLLOW_ANY", 0x20000000)
        | os.O_CLOEXEC,
    )
    parent_info = os.fstat(parent)
    if (
        not stat.S_ISDIR(parent_info.st_mode)
        or parent_info.st_uid != os.getuid()
        or stat.S_IMODE(parent_info.st_mode) & 0o022
    ):
        raise ValueError
    destination_descriptor = os.open(
        leaf,
        os.O_RDWR
        | os.O_CREAT
        | os.O_EXCL
        | os.O_NOFOLLOW
        | os.O_CLOEXEC,
        0o500,
        dir_fd=parent,
    )
    destination_info = os.fstat(destination_descriptor)
    created_identity = (destination_info.st_dev, destination_info.st_ino)
    remaining = source_info.st_size
    corrupt_copy = selftest_mode == "selftest-corrupt-copy"
    while remaining:
        chunk = os.read(source_descriptor, min(1024 * 1024, remaining))
        if not chunk:
            raise ValueError
        if corrupt_copy:
            changed = bytearray(chunk)
            changed[0] ^= 0x01
            chunk = bytes(changed)
            corrupt_copy = False
        view = memoryview(chunk)
        while view:
            count = os.write(destination_descriptor, view)
            if count <= 0:
                raise ValueError
            view = view[count:]
        remaining -= len(chunk)
    os.fchmod(destination_descriptor, 0o500)
    os.fsync(destination_descriptor)
    os.lseek(destination_descriptor, 0, os.SEEK_SET)
    staged_digest = hashlib.sha256()
    remaining = source_info.st_size
    while remaining:
        chunk = os.read(destination_descriptor, min(1024 * 1024, remaining))
        if not chunk:
            raise ValueError
        staged_digest.update(chunk)
        remaining -= len(chunk)
    if os.read(destination_descriptor, 1) or staged_digest.hexdigest() != expected_sha:
        raise ValueError
    held = os.fstat(destination_descriptor)
    visible = os.stat(leaf, dir_fd=parent, follow_symlinks=False)
    if (
        (held.st_dev, held.st_ino) != created_identity
        or (visible.st_dev, visible.st_ino) != created_identity
        or held.st_size != source_info.st_size
        or held.st_nlink != 1
        or held.st_uid != os.getuid()
        or stat.S_IMODE(held.st_mode) != 0o500
    ):
        raise ValueError
    os.fsync(parent)
    success = True
    print(f"{created_identity[0]}:{created_identity[1]}")
except (OSError, ValueError):
    print("helper input is unsafe, raced, or does not match its approved SHA-256", file=sys.stderr)
    raise SystemExit(1)
finally:
    if destination_descriptor is not None:
        try:
            os.close(destination_descriptor)
        except OSError:
            pass
    if not success and created_identity is not None and parent is not None:
        try:
            visible = os.stat(
                os.path.basename(os.path.abspath(destination)),
                dir_fd=parent,
                follow_symlinks=False,
            )
            if (visible.st_dev, visible.st_ino) == created_identity:
                os.unlink(
                    os.path.basename(os.path.abspath(destination)),
                    dir_fd=parent,
                )
                os.fsync(parent)
            else:
                print("refusing to unlink a path-replaced staged helper", file=sys.stderr)
        except OSError:
            pass
    if parent is not None:
        try:
            os.close(parent)
        except OSError:
            pass
    if source_descriptor is not None:
        try:
            os.close(source_descriptor)
        except OSError:
            pass
PY
}

tilde_codesign_team_from_details() {
  local details="$1" identifiers count identifier
  identifiers="$(
    printf '%s\n' "$details" \
      | /usr/bin/awk -F= '/^TeamIdentifier=/ { print $2 }'
  )"
  count="$(
    printf '%s\n' "$identifiers" \
      | /usr/bin/awk 'NF { count += 1 } END { print count + 0 }'
  )"
  identifier="$(printf '%s\n' "$identifiers" | /usr/bin/awk 'NF { print; exit }')"
  [[ "$count" == "1" && "$identifier" =~ ^[A-Z0-9]{10}$ ]] \
    || { echo "helper has an absent or ambiguous TeamIdentifier" >&2; return 1; }
  printf '%s\n' "$identifier"
}

# API for preview builders:
#   tilde_stage_authenticated_helper SOURCE DEST EXPECTED_INPUT_SHA APPROVED_TEAM
# The destination is the pre-resign helper. Builders may force-sign it only
# after this function succeeds, then must verify the final bundle seal/team.
tilde_stage_authenticated_helper() {
  local source="$1" destination="$2" expected_sha="$3" approved_team="$4"
  local identity details actual_team
  [[ "$expected_sha" =~ ^[0-9a-f]{64}$ ]] \
    || { echo "approved helper SHA-256 must be 64 lowercase hexadecimal characters" >&2; return 2; }
  [[ "$approved_team" =~ ^[A-Z0-9]{10}$ ]] \
    || { echo "approved helper TeamIdentifier must be 10 uppercase alphanumeric characters" >&2; return 2; }
  identity="$(
    tilde_stage_helper_bytes_by_fd "$source" "$destination" "$expected_sha"
  )" || return
  if ! /usr/bin/codesign --verify --strict --verbose=2 "$destination"; then
    tilde_remove_exact_regular_file "$destination" "$identity" || true
    echo "approved helper input does not have a valid code signature" >&2
    return 1
  fi
  details="$(/usr/bin/codesign --display --verbose=4 "$destination" 2>&1)" || {
    tilde_remove_exact_regular_file "$destination" "$identity" || true
    return 1
  }
  actual_team="$(tilde_codesign_team_from_details "$details")" || {
    tilde_remove_exact_regular_file "$destination" "$identity" || true
    return 1
  }
  [[ "$actual_team" == "$approved_team" ]] || {
    tilde_remove_exact_regular_file "$destination" "$identity" || true
    echo "helper input signing team does not match the approved team" >&2
    return 1
  }
  TILDE_HELPER_INPUT_SHA256="$expected_sha"
  TILDE_HELPER_APPROVED_TEAM="$approved_team"
  TILDE_HELPER_STAGED_IDENTITY="$identity"
  export TILDE_HELPER_INPUT_SHA256 TILDE_HELPER_APPROVED_TEAM
  export TILDE_HELPER_STAGED_IDENTITY
}

tilde_xcode_namespace_identity() {
  local developer_dir="$1"
  tilde_python_isolated - "$developer_dir" <<'PY'
import os
import stat
import sys

developer = os.path.abspath(sys.argv[1])
suffix = os.path.join("Contents", "Developer")
if not developer.endswith(os.sep + suffix) or os.path.realpath(developer) != developer:
    raise SystemExit("selected developer directory is not a canonical Xcode bundle")
bundle = developer[: -(len(suffix) + 1)]
if not bundle.endswith(".app"):
    raise SystemExit("selected developer directory is not inside Xcode.app")

ancestor = os.path.dirname(bundle)
parent_info = None
while True:
    info = os.lstat(ancestor)
    mode = stat.S_IMODE(info.st_mode)
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != 0:
        raise SystemExit("Xcode bundle ancestor is not a root-owned directory")
    if mode & 0o022:
        # macOS ships /Applications as root:admin 0775. It is the sole
        # permitted writable ancestor; its exact directory identity is held
        # across every compiler invocation. Arbitrary writable parents remain
        # ineligible for decision-grade provenance.
        if ancestor != "/Applications" or mode != 0o775 or info.st_gid != 80:
            raise SystemExit(
                "Xcode bundle ancestor is writable outside the platform Applications directory"
            )
    if parent_info is None:
        parent_info = info
    parent = os.path.dirname(ancestor)
    if parent == ancestor:
        break
    ancestor = parent

bundle_info = os.lstat(bundle)
if (
    not stat.S_ISDIR(bundle_info.st_mode)
    or bundle_info.st_uid != 0
    or stat.S_IMODE(bundle_info.st_mode) & 0o022
):
    raise SystemExit("Xcode bundle is not root-owned and immutable to ordinary users")

assert parent_info is not None
print(
    f"{parent_info.st_dev}:{parent_info.st_ino}:"
    f"{bundle_info.st_dev}:{bundle_info.st_ino}"
)
PY
}

tilde_validate_apple_toolchain_paths() {
  local developer_dir="$1" swift_executable="$2" sdk_path="$3"
  shift 3
  tilde_xcode_namespace_identity "$developer_dir" >/dev/null || return
  tilde_python_isolated - \
    "$developer_dir" "$swift_executable" "$sdk_path" "$@" <<'PY'
import os
import stat
import sys

developer, swift, sdk, *additional_tools = (
    os.path.abspath(value) for value in sys.argv[1:]
)
suffix = os.path.join("Contents", "Developer")
if not developer.endswith(os.sep + suffix) or os.path.realpath(developer) != developer:
    raise SystemExit("selected developer directory is not a canonical Xcode bundle")
bundle = developer[: -(len(suffix) + 1)]
if not bundle.endswith(".app"):
    raise SystemExit("selected developer directory is not inside Xcode.app")
bundle_info = os.lstat(bundle)
if (
    not stat.S_ISDIR(bundle_info.st_mode)
    or bundle_info.st_uid != 0
    or stat.S_IMODE(bundle_info.st_mode) & 0o022
):
    raise SystemExit("Xcode bundle is not root-owned and immutable to ordinary users")

if (
    os.path.realpath(swift) != swift
    or os.path.realpath(sdk) != sdk
    or os.path.commonpath([developer, swift]) != developer
    or os.path.commonpath([developer, sdk]) != developer
    or any(
        os.path.realpath(tool) != tool
        or os.path.commonpath([developer, tool]) != developer
        for tool in additional_tools
    )
):
    raise SystemExit(
        "Swift, build-tool, or SDK path is linked or outside the selected developer directory"
    )

def validate_descendants(
    path: str,
    *,
    final_directory: bool = False,
) -> None:
    relative = os.path.relpath(path, bundle)
    current = bundle
    components = relative.split(os.sep)
    for index, component in enumerate(components):
        current = os.path.join(current, component)
        info = os.lstat(current)
        final = index == len(components) - 1
        if final:
            if final_directory:
                if not stat.S_ISDIR(info.st_mode):
                    raise SystemExit("selected developer path is not a directory")
            elif not stat.S_ISREG(info.st_mode):
                raise SystemExit("Swift executable is not a regular file")
        elif not stat.S_ISDIR(info.st_mode):
            raise SystemExit("Xcode toolchain path contains a link or special entry")
        if info.st_uid != 0 or stat.S_IMODE(info.st_mode) & 0o022:
            raise SystemExit("Xcode toolchain path is writable by an unapproved identity")

validate_descendants(developer, final_directory=True)
validate_descendants(swift)
for tool in additional_tools:
    validate_descendants(tool)
validate_descendants(sdk, final_directory=True)
settings = os.path.join(sdk, "SDKSettings.plist")
validate_descendants(settings)
if (
    os.stat(swift).st_nlink != 1
    or any(os.stat(tool).st_nlink != 1 for tool in additional_tools)
    or os.stat(settings).st_nlink != 1
):
    raise SystemExit("Swift, build-tool, or SDK identity file is hard linked")
PY
}

tilde_toolchain_identity_sha256() {
  tilde_python_isolated - "$@" <<'PY'
import hashlib
import sys

digest = hashlib.sha256(b"tilde-apple-toolchain-v2\0")
for value in sys.argv[1:]:
    encoded = value.encode("utf-8")
    digest.update(len(encoded).to_bytes(8, "big"))
    digest.update(encoded)
print(digest.hexdigest())
PY
}

# API for preview builders:
#   tilde_capture_apple_swift_toolchain
#   tilde_swift build ...
# The second function resolves the `swift` driver through the captured Xcode
# toolchain in a minimal environment and revalidates its underlying signed
# frontend identity before and after every invocation.
tilde_capture_apple_swift_toolchain() {
  local developer_dir xcode_bundle swift_executable swift_build_executable
  local swift_driver_executable clang_executable linker_executable
  local libtool_executable archiver_executable xcode_details
  local xcode_signature_details xcode_identifier xcode_team xcode_cdhash swift_details
  local sdk_path sdk_version sdk_build sdk_settings_sha
  local swift_binary_sha swift_build_sha swift_driver_sha clang_sha linker_sha
  local libtool_sha archiver_sha swift_version_sha identity tool_specification tool_path
  local xcode_namespace_before xcode_namespace_after
  developer_dir="$(
    /usr/bin/env -i HOME=/var/empty PATH=/usr/bin:/bin:/usr/sbin:/sbin \
      /usr/bin/xcode-select -p
  )"
  xcode_namespace_before="$(
    tilde_xcode_namespace_identity "$developer_dir"
  )" || return
  swift_executable="$(
    /usr/bin/env -i HOME=/var/empty PATH=/usr/bin:/bin:/usr/sbin:/sbin \
      DEVELOPER_DIR="$developer_dir" \
      TOOLCHAINS=com.apple.dt.toolchain.XcodeDefault \
      /usr/bin/xcrun --no-cache \
        --toolchain com.apple.dt.toolchain.XcodeDefault --find swift
  )"
  swift_executable="$(
    tilde_python_isolated -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' \
      "$swift_executable"
  )"
  swift_build_executable="$(
    /usr/bin/env -i HOME=/var/empty PATH=/usr/bin:/bin:/usr/sbin:/sbin \
      DEVELOPER_DIR="$developer_dir" TOOLCHAINS=com.apple.dt.toolchain.XcodeDefault \
      /usr/bin/xcrun --no-cache --toolchain com.apple.dt.toolchain.XcodeDefault \
        --find swift-build
  )"
  swift_driver_executable="$(
    /usr/bin/env -i HOME=/var/empty PATH=/usr/bin:/bin:/usr/sbin:/sbin \
      DEVELOPER_DIR="$developer_dir" TOOLCHAINS=com.apple.dt.toolchain.XcodeDefault \
      /usr/bin/xcrun --no-cache --toolchain com.apple.dt.toolchain.XcodeDefault \
        --find swift-driver
  )"
  clang_executable="$(
    /usr/bin/env -i HOME=/var/empty PATH=/usr/bin:/bin:/usr/sbin:/sbin \
      DEVELOPER_DIR="$developer_dir" TOOLCHAINS=com.apple.dt.toolchain.XcodeDefault \
      /usr/bin/xcrun --no-cache --toolchain com.apple.dt.toolchain.XcodeDefault \
        --find clang
  )"
  linker_executable="$(
    /usr/bin/env -i HOME=/var/empty PATH=/usr/bin:/bin:/usr/sbin:/sbin \
      DEVELOPER_DIR="$developer_dir" TOOLCHAINS=com.apple.dt.toolchain.XcodeDefault \
      /usr/bin/xcrun --no-cache --toolchain com.apple.dt.toolchain.XcodeDefault \
        --find ld
  )"
  libtool_executable="$(
    /usr/bin/env -i HOME=/var/empty PATH=/usr/bin:/bin:/usr/sbin:/sbin \
      DEVELOPER_DIR="$developer_dir" TOOLCHAINS=com.apple.dt.toolchain.XcodeDefault \
      /usr/bin/xcrun --no-cache --toolchain com.apple.dt.toolchain.XcodeDefault \
        --find libtool
  )"
  archiver_executable="$(
    /usr/bin/env -i HOME=/var/empty PATH=/usr/bin:/bin:/usr/sbin:/sbin \
      DEVELOPER_DIR="$developer_dir" TOOLCHAINS=com.apple.dt.toolchain.XcodeDefault \
      /usr/bin/xcrun --no-cache --toolchain com.apple.dt.toolchain.XcodeDefault \
        --find ar
  )"
  swift_build_executable="$(tilde_python_isolated -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$swift_build_executable")"
  swift_driver_executable="$(tilde_python_isolated -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$swift_driver_executable")"
  clang_executable="$(tilde_python_isolated -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$clang_executable")"
  linker_executable="$(tilde_python_isolated -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$linker_executable")"
  libtool_executable="$(tilde_python_isolated -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$libtool_executable")"
  archiver_executable="$(tilde_python_isolated -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$archiver_executable")"
  sdk_path="$(
    /usr/bin/env -i HOME=/var/empty PATH=/usr/bin:/bin:/usr/sbin:/sbin \
      DEVELOPER_DIR="$developer_dir" \
      TOOLCHAINS=com.apple.dt.toolchain.XcodeDefault \
      /usr/bin/xcrun --no-cache --sdk macosx --show-sdk-path
  )"
  sdk_path="$(
    tilde_python_isolated -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' \
      "$sdk_path"
  )"
  tilde_validate_apple_toolchain_paths \
    "$developer_dir" "$swift_executable" "$sdk_path" \
    "$swift_build_executable" "$swift_driver_executable" "$clang_executable" \
    "$linker_executable" "$libtool_executable" "$archiver_executable" || return
  xcode_bundle="${developer_dir%/Contents/Developer}"
  [[ "$xcode_bundle" != "$developer_dir" && "$xcode_bundle" == *.app ]] \
    || { echo "selected developer directory is not inside Xcode.app" >&2; return 1; }
  /usr/bin/codesign --verify --strict \
    -R='anchor apple generic and identifier "com.apple.dt.Xcode"' \
    "$xcode_bundle" || {
      echo "selected Xcode bundle seal is invalid or untrusted" >&2
      return 1
    }
  xcode_signature_details="$(
    /usr/bin/codesign --display --verbose=4 "$xcode_bundle" 2>&1
  )" || return
  xcode_identifier="$(
    printf '%s\n' "$xcode_signature_details" \
      | /usr/bin/awk -F= '/^Identifier=/ { print $2; exit }'
  )"
  xcode_team="$(tilde_codesign_team_from_details "$xcode_signature_details")" || return
  xcode_cdhash="$(
    printf '%s\n' "$xcode_signature_details" \
      | /usr/bin/awk -F= '/^CDHash=/ { print $2; exit }'
  )"
  [[ "$xcode_identifier" == "com.apple.dt.Xcode" \
      && "$xcode_team" == "59GAB85EFG" \
      && "$xcode_cdhash" =~ ^[0-9a-f]{40}([0-9a-f]{24})?$ ]] || {
    echo "selected Xcode bundle has an unapproved signing identity" >&2
    return 1
  }
  /usr/bin/codesign --verify --strict \
    -R='anchor apple and identifier "com.apple.swift-frontend"' \
    "$swift_executable" || {
      echo "selected Swift compiler is not an Apple-signed swift-frontend" >&2
      return 1
    }
  for tool_specification in \
    "$swift_build_executable|com.apple.swift-package" \
    "$swift_driver_executable|com.apple.swift-driver" \
    "$clang_executable|com.apple.clang" \
    "$linker_executable|com.apple.ld" \
    "$libtool_executable|com.apple.libtool" \
    "$archiver_executable|com.apple.ar"; do
    tool_path="${tool_specification%%|*}"
    /usr/bin/codesign --verify --strict \
      -R="anchor apple and identifier \"${tool_specification##*|}\"" \
      "$tool_path" || {
        echo "selected Apple build tool has an unapproved signature: ${tool_specification##*|}" >&2
        return 1
      }
  done
  xcode_details="$(
    /usr/bin/env -i HOME=/var/empty PATH=/usr/bin:/bin:/usr/sbin:/sbin \
      DEVELOPER_DIR="$developer_dir" \
      TOOLCHAINS=com.apple.dt.toolchain.XcodeDefault \
      /usr/bin/xcodebuild -version
  )"
  swift_details="$(
    /usr/bin/env -i HOME=/var/empty PATH=/usr/bin:/bin:/usr/sbin:/sbin \
      DEVELOPER_DIR="$developer_dir" \
      TOOLCHAINS=com.apple.dt.toolchain.XcodeDefault \
      SDKROOT="$sdk_path" \
      "$swift_executable" --version 2>&1
  )"
  sdk_version="$(
    /usr/bin/env -i HOME=/var/empty PATH=/usr/bin:/bin:/usr/sbin:/sbin \
      DEVELOPER_DIR="$developer_dir" \
      TOOLCHAINS=com.apple.dt.toolchain.XcodeDefault \
      /usr/bin/xcrun --no-cache --sdk macosx --show-sdk-version
  )"
  sdk_build="$(
    /usr/bin/env -i HOME=/var/empty PATH=/usr/bin:/bin:/usr/sbin:/sbin \
      DEVELOPER_DIR="$developer_dir" \
      TOOLCHAINS=com.apple.dt.toolchain.XcodeDefault \
      /usr/bin/xcrun --no-cache --sdk macosx --show-sdk-build-version
  )"
  TILDE_XCODE_VERSION="$(
    printf '%s\n' "$xcode_details" | /usr/bin/awk '$1 == "Xcode" { print $2; exit }'
  )"
  TILDE_XCODE_BUILD="$(
    printf '%s\n' "$xcode_details" \
      | /usr/bin/awk '$1 == "Build" && $2 == "version" { print $3; exit }'
  )"
  swift_binary_sha="$(
    /usr/bin/shasum -a 256 "$swift_executable" | /usr/bin/awk '{ print $1 }'
  )"
  swift_build_sha="$(/usr/bin/shasum -a 256 "$swift_build_executable" | /usr/bin/awk '{ print $1 }')"
  swift_driver_sha="$(/usr/bin/shasum -a 256 "$swift_driver_executable" | /usr/bin/awk '{ print $1 }')"
  clang_sha="$(/usr/bin/shasum -a 256 "$clang_executable" | /usr/bin/awk '{ print $1 }')"
  linker_sha="$(/usr/bin/shasum -a 256 "$linker_executable" | /usr/bin/awk '{ print $1 }')"
  libtool_sha="$(/usr/bin/shasum -a 256 "$libtool_executable" | /usr/bin/awk '{ print $1 }')"
  archiver_sha="$(/usr/bin/shasum -a 256 "$archiver_executable" | /usr/bin/awk '{ print $1 }')"
  swift_version_sha="$(
    printf '%s' "$swift_details" | /usr/bin/shasum -a 256 | /usr/bin/awk '{ print $1 }'
  )"
  sdk_settings_sha="$(
    /usr/bin/shasum -a 256 "$sdk_path/SDKSettings.plist" \
      | /usr/bin/awk '{ print $1 }'
  )"
  xcode_namespace_after="$(
    tilde_xcode_namespace_identity "$developer_dir"
  )" || return
  [[ "$xcode_namespace_after" == "$xcode_namespace_before" ]] || {
    echo "Xcode bundle namespace changed during toolchain capture" >&2
    return 1
  }
  [[ -n "$TILDE_XCODE_VERSION" && -n "$TILDE_XCODE_BUILD" \
      && "$sdk_version" =~ ^[0-9]+([.][0-9]+)*$ \
      && "$sdk_build" =~ ^[A-Za-z0-9]+$ \
      && "$swift_binary_sha" =~ ^[0-9a-f]{64}$ \
      && "$swift_build_sha" =~ ^[0-9a-f]{64}$ \
      && "$swift_driver_sha" =~ ^[0-9a-f]{64}$ \
      && "$clang_sha" =~ ^[0-9a-f]{64}$ \
      && "$linker_sha" =~ ^[0-9a-f]{64}$ \
      && "$libtool_sha" =~ ^[0-9a-f]{64}$ \
      && "$archiver_sha" =~ ^[0-9a-f]{64}$ \
      && "$swift_version_sha" =~ ^[0-9a-f]{64}$ \
      && "$sdk_settings_sha" =~ ^[0-9a-f]{64}$ ]] \
    || { echo "Apple Swift toolchain identity is malformed" >&2; return 1; }
  identity="$(
    tilde_toolchain_identity_sha256 \
      "$TILDE_XCODE_VERSION" "$TILDE_XCODE_BUILD" \
      "$xcode_cdhash" \
      "$sdk_version" "$sdk_build" \
      "$sdk_settings_sha" "$swift_binary_sha" "$swift_version_sha" \
      "$swift_build_sha" "$swift_driver_sha" "$clang_sha" "$linker_sha" \
      "$libtool_sha" "$archiver_sha"
  )"
  [[ "$identity" =~ ^[0-9a-f]{64}$ ]] || return 1
  TILDE_DEVELOPER_DIR="$developer_dir"
  TILDE_XCODE_NAMESPACE_IDENTITY="$xcode_namespace_before"
  TILDE_SWIFT_EXECUTABLE="$swift_executable"
  TILDE_XCODE_CDHASH="$xcode_cdhash"
  TILDE_SWIFT_VERSION_SHA256="$swift_version_sha"
  TILDE_MACOS_SDK_VERSION="$sdk_version"
  TILDE_MACOS_SDK_BUILD="$sdk_build"
  TILDE_MACOS_SDK_PATH="$sdk_path"
  TILDE_MACOS_SDK_SETTINGS_SHA256="$sdk_settings_sha"
  TILDE_APPLE_TOOLCHAIN_SHA256="$identity"
  TILDE_SWIFT_EXECUTABLE_SHA256="$swift_binary_sha"
  TILDE_SWIFT_BUILD_EXECUTABLE_SHA256="$swift_build_sha"
  TILDE_SWIFT_DRIVER_EXECUTABLE_SHA256="$swift_driver_sha"
  TILDE_CLANG_EXECUTABLE_SHA256="$clang_sha"
  TILDE_LINKER_EXECUTABLE_SHA256="$linker_sha"
  TILDE_LIBTOOL_EXECUTABLE_SHA256="$libtool_sha"
  TILDE_ARCHIVER_EXECUTABLE_SHA256="$archiver_sha"
  export TILDE_DEVELOPER_DIR TILDE_XCODE_NAMESPACE_IDENTITY TILDE_SWIFT_EXECUTABLE
  export TILDE_XCODE_VERSION TILDE_XCODE_BUILD TILDE_XCODE_CDHASH
  export TILDE_SWIFT_VERSION_SHA256
  export TILDE_MACOS_SDK_VERSION TILDE_MACOS_SDK_BUILD TILDE_MACOS_SDK_PATH
  export TILDE_MACOS_SDK_SETTINGS_SHA256
  export TILDE_APPLE_TOOLCHAIN_SHA256 TILDE_SWIFT_EXECUTABLE_SHA256
  export TILDE_SWIFT_BUILD_EXECUTABLE_SHA256 TILDE_SWIFT_DRIVER_EXECUTABLE_SHA256
  export TILDE_CLANG_EXECUTABLE_SHA256 TILDE_LINKER_EXECUTABLE_SHA256
  export TILDE_LIBTOOL_EXECUTABLE_SHA256 TILDE_ARCHIVER_EXECUTABLE_SHA256
}

tilde_assert_apple_swift_toolchain_unchanged() {
  local expected="$TILDE_APPLE_TOOLCHAIN_SHA256" expected_executable="$TILDE_SWIFT_EXECUTABLE"
  local expected_developer="$TILDE_DEVELOPER_DIR" expected_sdk="$TILDE_MACOS_SDK_PATH"
  local expected_namespace="$TILDE_XCODE_NAMESPACE_IDENTITY"
  [[ "$expected" =~ ^[0-9a-f]{64}$ && -n "$expected_executable" \
      && -n "$expected_developer" && -n "$expected_sdk" \
      && "$expected_namespace" =~ ^[0-9]+:[0-9]+:[0-9]+:[0-9]+$ ]] \
    || { echo "Apple Swift toolchain has not been captured" >&2; return 1; }
  tilde_capture_apple_swift_toolchain || return
  [[ "$TILDE_APPLE_TOOLCHAIN_SHA256" == "$expected" \
      && "$TILDE_SWIFT_EXECUTABLE" == "$expected_executable" \
      && "$TILDE_DEVELOPER_DIR" == "$expected_developer" \
      && "$TILDE_MACOS_SDK_PATH" == "$expected_sdk" \
      && "$TILDE_XCODE_NAMESPACE_IDENTITY" == "$expected_namespace" ]] || {
    echo "Apple Swift toolchain changed during the build" >&2
    return 1
  }
}

tilde_swift() (
  set -euo pipefail
  local tool_home tool_temp="" cache_directory result
  [[ -n "${TILDE_BUILD_SOURCE_ROOT:-}" && -d "$TILDE_BUILD_SOURCE_ROOT" ]] \
    || { echo "a build source must be prepared before invoking Swift" >&2; return 1; }
  tilde_assert_apple_swift_toolchain_unchanged || return
  if [[ -n "${TILDE_BUILD_SOURCE_TEMP:-}" ]]; then
    tool_home="$TILDE_BUILD_SOURCE_TEMP/tool-home"
    if [[ ! -d "$tool_home" ]]; then
      /bin/mkdir -m 700 "$tool_home"
    fi
  else
    tool_temp="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/tilde-swift-home.XXXXXX")"
    /bin/chmod 700 "$tool_temp"
    tool_home="$tool_temp"
    trap 'tilde_remove_private_source_tree "$tool_temp" tilde-swift-home' EXIT
  fi
  [[ ! -L "$tool_home" && "$(/usr/bin/stat -f '%u:%Lp' "$tool_home")" == \
      "$(/usr/bin/id -u):700" ]] \
    || { echo "temporary Swift home is unsafe" >&2; return 1; }
  for cache_directory in tmp clang-module-cache swiftpm-module-cache; do
    if [[ ! -d "$tool_home/$cache_directory" ]]; then
      /bin/mkdir -m 700 "$tool_home/$cache_directory"
    fi
    [[ ! -L "$tool_home/$cache_directory" \
        && "$(/usr/bin/stat -f '%u:%Lp' "$tool_home/$cache_directory")" == \
          "$(/usr/bin/id -u):700" ]] \
      || { echo "temporary Swift cache directory is unsafe" >&2; return 1; }
  done
  set +e
  /usr/bin/env -i \
    HOME="$tool_home" \
    TMPDIR="$tool_home/tmp" \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin \
    DEVELOPER_DIR="$TILDE_DEVELOPER_DIR" \
    TOOLCHAINS=com.apple.dt.toolchain.XcodeDefault \
    SDKROOT="$TILDE_MACOS_SDK_PATH" \
    CLANG_MODULE_CACHE_PATH="$tool_home/clang-module-cache" \
    SWIFTPM_MODULECACHE_OVERRIDE="$tool_home/swiftpm-module-cache" \
    /usr/bin/xcrun --no-cache \
      --toolchain com.apple.dt.toolchain.XcodeDefault swift "$@"
  result=$?
  set -e
  tilde_assert_apple_swift_toolchain_unchanged || return 1
  return "$result"
)

tilde_bundle_manifest_sha256() {
  local bundle="$1"
  tilde_python_isolated - "$bundle" <<'PY'
import hashlib
import os
import stat
import sys

root = os.fsencode(os.path.abspath(sys.argv[1]))
root_info = os.lstat(root)
root_mode = stat.S_IMODE(root_info.st_mode)
if (
    not stat.S_ISDIR(root_info.st_mode)
    or root_info.st_uid not in (0, os.getuid())
    or root_mode & 0o022
):
    raise SystemExit("bundle root is unsafe")

entries = []
for directory, names, files in os.walk(root, topdown=True, followlinks=False):
    names.sort()
    files.sort()
    for name in names:
        path = os.path.join(directory, name)
        info = os.lstat(path)
        if not stat.S_ISDIR(info.st_mode):
            raise SystemExit("bundle contains a link or special entry")
        entries.append((os.path.relpath(path, root), b"D", info))
    for name in files:
        path = os.path.join(directory, name)
        info = os.lstat(path)
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
            raise SystemExit("bundle contains a link or special entry")
        entries.append((os.path.relpath(path, root), b"F", info))

entries.sort(key=lambda entry: entry[0])
digest = hashlib.sha256(b"tilde-bundle-manifest-v2\0")
digest.update(b"R")
digest.update(root_mode.to_bytes(4, "big"))
for relative, kind, info in entries:
    path = os.path.join(root, relative)
    mode = stat.S_IMODE(info.st_mode)
    if info.st_uid not in (0, os.getuid()) or mode & 0o022:
        raise SystemExit("bundle entry is writable by an unapproved identity")
    digest.update(kind)
    digest.update(len(relative).to_bytes(8, "big"))
    digest.update(relative)
    digest.update(mode.to_bytes(4, "big"))
    if kind == b"F":
        digest.update(info.st_size.to_bytes(8, "big"))
        descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
        try:
            held = os.fstat(descriptor)
            if (
                not stat.S_ISREG(held.st_mode)
                or held.st_nlink != 1
                or held.st_uid != info.st_uid
                or (held.st_dev, held.st_ino) != (info.st_dev, info.st_ino)
                or held.st_size != info.st_size
                or stat.S_IMODE(held.st_mode) != mode
            ):
                raise SystemExit("bundle entry changed during hashing")
            remaining = held.st_size
            while remaining:
                chunk = os.read(descriptor, min(1024 * 1024, remaining))
                if not chunk:
                    raise SystemExit("bundle entry was truncated")
                digest.update(chunk)
                remaining -= len(chunk)
            if os.read(descriptor, 1):
                raise SystemExit("bundle entry grew during hashing")
            visible = os.lstat(path)
            if (visible.st_dev, visible.st_ino) != (held.st_dev, held.st_ino):
                raise SystemExit("bundle entry was path-replaced")
        finally:
            os.close(descriptor)
print(digest.hexdigest())
PY
}

tilde_bundle_directory_identity() {
  local bundle="$1"
  tilde_python_isolated - "$bundle" <<'PY'
import os
import stat
import sys

try:
    info = os.lstat(os.path.abspath(sys.argv[1]))
    if (
        not stat.S_ISDIR(info.st_mode)
        or info.st_uid not in (0, os.getuid())
        or stat.S_IMODE(info.st_mode) & 0o022
    ):
        raise ValueError
    print(f"{info.st_dev}:{info.st_ino}")
except (OSError, ValueError):
    raise SystemExit("published bundle identity is unsafe")
PY
}

tilde_remove_private_publish_tree() {
  local temporary="$1"
  [[ -n "$temporary" && "${temporary##*/}" == .tilde-publish.* \
      && -d "$temporary" && ! -L "$temporary" \
      && "$(/usr/bin/stat -f '%u:%Lp' "$temporary")" == \
        "$(/usr/bin/id -u):700" ]] \
    || { echo "refusing to remove an unsafe publish staging directory" >&2; return 1; }
  /bin/chmod -R u+rwX "$temporary"
  /bin/rm -rf -- "$temporary"
}

tilde_quarantine_published_bundle() {
  local parent="$1" transaction_leaf="$2" bundle_leaf="$3" identity="$4"
  tilde_python_isolated - \
    "$parent" "$transaction_leaf" "$bundle_leaf" "$identity" <<'PY'
import ctypes
import os
import stat
import sys

parent_path, transaction_leaf, bundle_leaf, identity = sys.argv[1:]
try:
    expected = tuple(int(value) for value in identity.split(":", 1))
except ValueError:
    raise SystemExit("published bundle identity is malformed")

libc = ctypes.CDLL(None, use_errno=True)
libc.renameatx_np.argtypes = [
    ctypes.c_int,
    ctypes.c_char_p,
    ctypes.c_int,
    ctypes.c_char_p,
    ctypes.c_uint,
]
libc.renameatx_np.restype = ctypes.c_int
rename_flags = 0x00000004 | 0x00000010
parent_flags = (
    os.O_RDONLY
    | os.O_DIRECTORY
    | getattr(os, "O_NOFOLLOW_ANY", 0x20000000)
    | os.O_CLOEXEC
)
directory_flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC
parent = None
transaction = None
try:
    parent = os.open(parent_path, parent_flags)
    transaction = os.open(transaction_leaf, directory_flags, dir_fd=parent)
    transaction_info = os.fstat(transaction)
    transaction_visible = os.stat(
        transaction_leaf,
        dir_fd=parent,
        follow_symlinks=False,
    )
    if (
        transaction_info.st_uid != os.getuid()
        or stat.S_IMODE(transaction_info.st_mode) != 0o700
        or (transaction_info.st_dev, transaction_info.st_ino)
            != (transaction_visible.st_dev, transaction_visible.st_ino)
    ):
        raise ValueError
    visible = os.stat(bundle_leaf, dir_fd=parent, follow_symlinks=False)
    if not stat.S_ISDIR(visible.st_mode) or (visible.st_dev, visible.st_ino) != expected:
        raise ValueError
    try:
        os.stat(bundle_leaf, dir_fd=transaction, follow_symlinks=False)
    except FileNotFoundError:
        pass
    else:
        raise ValueError
    ctypes.set_errno(0)
    if libc.renameatx_np(
        parent,
        os.fsencode(bundle_leaf),
        transaction,
        os.fsencode(bundle_leaf),
        rename_flags,
    ) != 0:
        failure = ctypes.get_errno()
        raise OSError(failure, os.strerror(failure))
    quarantined = os.stat(bundle_leaf, dir_fd=transaction, follow_symlinks=False)
    if (
        not stat.S_ISDIR(quarantined.st_mode)
        or (quarantined.st_dev, quarantined.st_ino) != expected
    ):
        raise ValueError
    os.fsync(transaction)
    os.fsync(parent)
except (OSError, ValueError):
    print("refusing to quarantine a path-replaced published bundle", file=sys.stderr)
    raise SystemExit(1)
finally:
    if transaction is not None:
        os.close(transaction)
    if parent is not None:
        os.close(parent)
PY
}

# API for a new (not replacement) application install:
#   tilde_publish_new_bundle SOURCE_APP DESTINATION_APP EXPECTED_MANIFEST_SHA
# The caller supplies the manifest captured after signing. This function copies
# only into a private sibling, revalidates its seal and bytes, then performs one
# no-replace/no-symlink rename inside already-open directory descriptors.
tilde_publish_new_bundle() (
  set -euo pipefail
  local source="$1" destination="$2" expected_manifest="$3"
  local parent leaf transaction staged manifest published_identity current_identity
  local postcheck_ok=1 success=0
  [[ "$expected_manifest" =~ ^[0-9a-f]{64}$ ]] \
    || { echo "expected bundle manifest must be a lowercase SHA-256" >&2; return 2; }
  [[ -d "$source" && ! -L "$source" ]] \
    || { echo "bundle source is missing or linked" >&2; return 1; }
  source="$(cd "$(/usr/bin/dirname "$source")" && pwd -P)/$(/usr/bin/basename "$source")"
  leaf="$(/usr/bin/basename "$destination")"
  [[ "$leaf" == *.app && "$leaf" != "." && "$leaf" != ".." ]] \
    || { echo "bundle destination must name one .app leaf" >&2; return 2; }
  parent="$(cd "$(/usr/bin/dirname "$destination")" && pwd -P)" \
    || { echo "bundle destination parent is missing" >&2; return 1; }
  [[ "$destination" == "$parent/$leaf" ]] \
    || { echo "bundle destination path must already be canonical" >&2; return 1; }
  manifest="$(tilde_bundle_manifest_sha256 "$source")" || return
  [[ "$manifest" == "$expected_manifest" ]] \
    || { echo "bundle source manifest changed before staging" >&2; return 1; }
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$source"

  transaction="$(/usr/bin/mktemp -d "$parent/.tilde-publish.XXXXXX")"
  /bin/chmod 700 "$transaction"
  staged="$transaction/$leaf"
  trap 'if [[ "$success" != "1" && -n "${transaction:-}" && -d "$transaction" ]]; then tilde_remove_private_publish_tree "$transaction" || true; fi' EXIT
  /usr/bin/ditto "$source" "$staged"
  manifest="$(tilde_bundle_manifest_sha256 "$staged")" || return
  [[ "$manifest" == "$expected_manifest" ]] \
    || { echo "staged bundle does not match its signed source manifest" >&2; return 1; }
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$staged"

  published_identity="$(
    tilde_python_isolated - "$transaction" "$leaf" "$parent" <<'PY'
import ctypes
import errno
import os
import stat
import sys

transaction_path, leaf, parent_path = sys.argv[1:]
transaction_leaf = os.path.basename(transaction_path)
if transaction_path != os.path.join(parent_path, transaction_leaf):
    raise SystemExit("publish transaction path is not canonical")
libc = ctypes.CDLL(None, use_errno=True)
libc.renameatx_np.argtypes = [
    ctypes.c_int,
    ctypes.c_char_p,
    ctypes.c_int,
    ctypes.c_char_p,
    ctypes.c_uint,
]
libc.renameatx_np.restype = ctypes.c_int
RENAME_EXCL = 0x00000004
RENAME_NOFOLLOW_ANY = 0x00000010
rename_flags = RENAME_EXCL | RENAME_NOFOLLOW_ANY
parent_flags = (
    os.O_RDONLY
    | os.O_DIRECTORY
    | getattr(os, "O_NOFOLLOW_ANY", 0x20000000)
    | os.O_CLOEXEC
)
directory_flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC
parent = os.open(parent_path, parent_flags)
transaction = os.open(transaction_leaf, directory_flags, dir_fd=parent)
staged = None
renamed = False
try:
    transaction_info = os.fstat(transaction)
    transaction_visible = os.stat(
        transaction_leaf,
        dir_fd=parent,
        follow_symlinks=False,
    )
    parent_info = os.fstat(parent)
    if (
        transaction_info.st_uid != os.getuid()
        or stat.S_IMODE(transaction_info.st_mode) != 0o700
        or (transaction_info.st_dev, transaction_info.st_ino)
            != (transaction_visible.st_dev, transaction_visible.st_ino)
        or parent_info.st_uid not in (0, os.getuid())
        or stat.S_IMODE(parent_info.st_mode) & 0o002
    ):
        raise ValueError
    staged = os.open(leaf, directory_flags, dir_fd=transaction)
    staged_info = os.fstat(staged)
    staged_visible = os.stat(leaf, dir_fd=transaction, follow_symlinks=False)
    transaction_visible = os.stat(
        transaction_leaf,
        dir_fd=parent,
        follow_symlinks=False,
    )
    if (
        staged_info.st_uid != os.getuid()
        or not stat.S_ISDIR(staged_info.st_mode)
        or stat.S_IMODE(staged_info.st_mode) & 0o022
        or (staged_info.st_dev, staged_info.st_ino)
            != (staged_visible.st_dev, staged_visible.st_ino)
        or (transaction_info.st_dev, transaction_info.st_ino)
            != (transaction_visible.st_dev, transaction_visible.st_ino)
    ):
        raise ValueError
    ctypes.set_errno(0)
    result = libc.renameatx_np(
        transaction,
        os.fsencode(leaf),
        parent,
        os.fsencode(leaf),
        rename_flags,
    )
    if result != 0:
        failure = ctypes.get_errno()
        if failure in (errno.EEXIST, errno.ELOOP, errno.ENOTEMPTY):
            raise FileExistsError
        raise OSError(failure, os.strerror(failure))
    renamed = True
    visible = os.stat(leaf, dir_fd=parent, follow_symlinks=False)
    if (
        not stat.S_ISDIR(visible.st_mode)
        or visible.st_uid != os.getuid()
        or stat.S_IMODE(visible.st_mode) & 0o022
        or (visible.st_dev, visible.st_ino) != (staged_info.st_dev, staged_info.st_ino)
    ):
        raise ValueError
    os.fsync(parent)
    print(f"{visible.st_dev}:{visible.st_ino}")
except FileExistsError:
    print("bundle destination appeared before atomic publish", file=sys.stderr)
    raise SystemExit(1)
except (OSError, ValueError):
    if renamed:
        try:
            visible = os.stat(leaf, dir_fd=parent, follow_symlinks=False)
            if (
                stat.S_ISDIR(visible.st_mode)
                and (visible.st_dev, visible.st_ino)
                    == (staged_info.st_dev, staged_info.st_ino)
                and libc.renameatx_np(
                    parent,
                    os.fsencode(leaf),
                    transaction,
                    os.fsencode(leaf),
                    rename_flags,
                ) == 0
            ):
                os.fsync(transaction)
                os.fsync(parent)
            else:
                print(
                    "refusing to quarantine a path-replaced bundle after publish failure",
                    file=sys.stderr,
                )
        except OSError:
            print(
                "refusing to quarantine a path-replaced bundle after publish failure",
                file=sys.stderr,
            )
    print("atomic bundle publish failed closed", file=sys.stderr)
    raise SystemExit(1)
finally:
    if staged is not None:
        os.close(staged)
    os.close(transaction)
    os.close(parent)
PY
  )" || return
  if ! manifest="$(tilde_bundle_manifest_sha256 "$destination")"; then
    postcheck_ok=0
  elif [[ "$manifest" != "$expected_manifest" ]]; then
    echo "published bundle manifest changed after atomic commit" >&2
    postcheck_ok=0
  fi
  if ! current_identity="$(tilde_bundle_directory_identity "$destination")" \
      || [[ "$current_identity" != "$published_identity" ]]; then
    echo "published bundle path changed after atomic commit" >&2
    postcheck_ok=0
  fi
  if ! /usr/bin/codesign --verify --deep --strict --verbose=2 "$destination"; then
    postcheck_ok=0
  fi
  if [[ "$postcheck_ok" != "1" ]]; then
    tilde_quarantine_published_bundle \
      "$parent" "${transaction##*/}" "$leaf" "$published_identity" || true
    return 1
  fi
  /bin/rmdir "$transaction"
  success=1
  printf '%s\n' "$published_identity"
)

tilde_validate_preview_version() {
  local version="$1"
  [[ ${#version} -le 64 \
      && "$version" =~ ^[0-9]+([.][0-9]+){1,2}(-[A-Za-z0-9]+([.-][A-Za-z0-9]+)*)?$ ]] \
    || { echo "preview version must be a conservative ASCII numeric prerelease" >&2; return 2; }
}

# Serializes assembly into the repository's fixed dist bundle names. Build
# sources and scratch directories are already private per invocation, but the
# final dist paths are shared. The mkdir is the atomic acquisition point;
# crashes deliberately leave a stale fail-closed lock for owner review.
tilde_acquire_preview_build_lock() {
  local dist="$1" identity
  [[ -z "${TILDE_PREVIEW_BUILD_LOCK_IDENTITY:-}" ]] \
    || { echo "preview build lock is already held by this process" >&2; return 1; }
  identity="$(tilde_python_isolated - "$dist" <<'PY'
import os
import stat
import sys

dist = os.path.abspath(sys.argv[1])
descriptor = os.open(dist, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
try:
    info = os.fstat(descriptor)
    if (
        not stat.S_ISDIR(info.st_mode)
        or info.st_uid != os.getuid()
        or stat.S_IMODE(info.st_mode) & 0o022
    ):
        raise SystemExit("dist directory is unsafe for a preview build lock")
    name = ".tilde-preview-build-lock"
    try:
        os.mkdir(name, 0o700, dir_fd=descriptor)
    except FileExistsError:
        raise SystemExit("another preview build is assembling a shared dist bundle")
    created = os.stat(name, dir_fd=descriptor, follow_symlinks=False)
    if (
        not stat.S_ISDIR(created.st_mode)
        or created.st_uid != os.getuid()
        or stat.S_IMODE(created.st_mode) != 0o700
    ):
        raise SystemExit("preview build lock creation was raced")
    os.fsync(descriptor)
    print(f"{created.st_dev}:{created.st_ino}")
finally:
    os.close(descriptor)
PY
)" || return
  [[ "$identity" =~ ^[0-9]+:[0-9]+$ ]] \
    || { echo "preview build lock identity is malformed" >&2; return 1; }
  TILDE_PREVIEW_BUILD_LOCK_DIRECTORY="$(cd "$dist" && pwd -P)"
  TILDE_PREVIEW_BUILD_LOCK_IDENTITY="$identity"
  export TILDE_PREVIEW_BUILD_LOCK_DIRECTORY TILDE_PREVIEW_BUILD_LOCK_IDENTITY
}

tilde_release_preview_build_lock() {
  local dist="${TILDE_PREVIEW_BUILD_LOCK_DIRECTORY:-}"
  local identity="${TILDE_PREVIEW_BUILD_LOCK_IDENTITY:-}"
  [[ -n "$dist" && "$identity" =~ ^[0-9]+:[0-9]+$ ]] || return 0
  tilde_python_isolated - "$dist" "$identity" <<'PY'
import os
import stat
import sys

dist, identity = sys.argv[1:]
expected_device, expected_inode = (int(value) for value in identity.split(":"))
descriptor = os.open(dist, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
try:
    name = ".tilde-preview-build-lock"
    visible = os.stat(name, dir_fd=descriptor, follow_symlinks=False)
    if (
        not stat.S_ISDIR(visible.st_mode)
        or visible.st_uid != os.getuid()
        or stat.S_IMODE(visible.st_mode) != 0o700
        or (visible.st_dev, visible.st_ino) != (expected_device, expected_inode)
    ):
        raise SystemExit("refusing to remove a replaced preview build lock")
    os.rmdir(name, dir_fd=descriptor)
    os.fsync(descriptor)
finally:
    os.close(descriptor)
PY
  local result=$?
  if [[ "$result" == "0" ]]; then
    unset TILDE_PREVIEW_BUILD_LOCK_DIRECTORY TILDE_PREVIEW_BUILD_LOCK_IDENTITY
  fi
  return "$result"
}

# Creates only owner-controlled 0700 directories beneath the real user home,
# clones or copies a missing model through directory/file descriptors, and
# accepts an existing target only when it is a single-link owner-only regular
# file with the exact registered bytes.
tilde_prepare_owner_only_model_target() {
  local source="$1" target="$2" expected_bytes="$3" expected_sha="$4" label="$5"
  local test_home="${6:-}" selftest_replacement="${7:-}"
  tilde_python_isolated - \
    "$source" "$target" "$expected_bytes" "$expected_sha" "$label" \
    "$test_home" "$selftest_replacement" <<'PY'
import ctypes
import errno
import fcntl
import hashlib
import os
import pwd
import stat
import string
import sys

(
    source,
    target,
    expected_bytes,
    expected_sha,
    label,
    test_home,
    selftest_replacement,
) = sys.argv[1:]
libc = ctypes.CDLL(None, use_errno=True)
libc.acl_get_fd_np.argtypes = [ctypes.c_int, ctypes.c_int]
libc.acl_get_fd_np.restype = ctypes.c_void_p
libc.acl_get_entry.argtypes = [
    ctypes.c_void_p,
    ctypes.c_int,
    ctypes.POINTER(ctypes.c_void_p),
]
libc.acl_get_entry.restype = ctypes.c_int
libc.acl_free.argtypes = [ctypes.c_void_p]
libc.acl_free.restype = ctypes.c_int

def fail() -> None:
    print(f"{label} model target is unsafe or mismatched", file=sys.stderr)
    raise SystemExit(1)

try:
    expected_size = int(expected_bytes)
except ValueError:
    fail()
if (
    expected_size <= 0
    or len(expected_sha) != 64
    or any(character not in string.hexdigits for character in expected_sha)
):
    fail()

def has_extended_acl(descriptor: int) -> bool:
    ctypes.set_errno(0)
    acl = libc.acl_get_fd_np(descriptor, 0x00000100)
    if not acl:
        if ctypes.get_errno() == errno.ENOENT:
            return False
        fail()
    try:
        entry = ctypes.c_void_p()
        ctypes.set_errno(0)
        result = libc.acl_get_entry(acl, 0, ctypes.byref(entry))
        if result == 0:
            return True
        if ctypes.get_errno() == errno.EINVAL:
            return False
        fail()
    finally:
        libc.acl_free(acl)

def verify_model(descriptor: int, *, target_file: bool) -> os.stat_result:
    info = os.fstat(descriptor)
    if (
        not stat.S_ISREG(info.st_mode)
        or info.st_uid != os.getuid()
        or info.st_nlink != 1
        or info.st_size != expected_size
        or stat.S_IMODE(info.st_mode) & 0o022
        or (target_file and stat.S_IMODE(info.st_mode) != 0o600)
    ):
        fail()
    flags = fcntl.fcntl(descriptor, fcntl.F_GETFL)
    if flags & os.O_NONBLOCK:
        fcntl.fcntl(descriptor, fcntl.F_SETFL, flags & ~os.O_NONBLOCK)
    os.lseek(descriptor, 0, os.SEEK_SET)
    digest = hashlib.sha256()
    prefix = b""
    while chunk := os.read(descriptor, 1024 * 1024):
        if len(prefix) < 4:
            prefix += chunk[: 4 - len(prefix)]
        digest.update(chunk)
    os.lseek(descriptor, 0, os.SEEK_SET)
    final_info = os.fstat(descriptor)
    if (
        prefix != b"GGUF"
        or digest.hexdigest() != expected_sha
        or (info.st_dev, info.st_ino, info.st_mode, info.st_uid, info.st_nlink, info.st_size)
            != (
                final_info.st_dev,
                final_info.st_ino,
                final_info.st_mode,
                final_info.st_uid,
                final_info.st_nlink,
                final_info.st_size,
            )
        or info.st_mtime_ns != final_info.st_mtime_ns
        or info.st_ctime_ns != final_info.st_ctime_ns
    ):
        fail()
    if target_file and has_extended_acl(descriptor):
        fail()
    return info

home = os.path.abspath(test_home or pwd.getpwuid(os.getuid()).pw_dir)
target = os.path.abspath(target)
if selftest_replacement:
    selftest_replacement = os.path.abspath(selftest_replacement)
    if not test_home or os.path.commonpath([home, selftest_replacement]) != home:
        fail()
source_descriptor = None
directory_descriptors = []
created_directories = []
created_leaf = False
created_leaf_identity = None
success = False
try:
    if os.path.commonpath([home, target]) != home:
        fail()
    relative = os.path.relpath(target, home)
    components = relative.split(os.sep)
    if (
        len(components) < 4
        or components[:2] != ["Library", "Application Support"]
        or any(component in ("", ".", "..") for component in components)
    ):
        fail()

    source_descriptor = os.open(
        source,
        os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC,
    )
    verify_model(source_descriptor, target_file=False)

    directory_flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC
    parent = os.open(home, directory_flags)
    directory_descriptors.append(parent)
    home_info = os.fstat(parent)
    if (
        not stat.S_ISDIR(home_info.st_mode)
        or home_info.st_uid != os.getuid()
        or stat.S_IMODE(home_info.st_mode) & 0o022
    ):
        fail()

    for component in components[:-1]:
        try:
            child = os.open(component, directory_flags, dir_fd=parent)
        except FileNotFoundError:
            os.mkdir(component, 0o700, dir_fd=parent)
            created_directories.append((parent, component))
            child = os.open(component, directory_flags, dir_fd=parent)
        child_info = os.fstat(child)
        visible_info = os.stat(component, dir_fd=parent, follow_symlinks=False)
        if (
            not stat.S_ISDIR(child_info.st_mode)
            or child_info.st_uid != os.getuid()
            or stat.S_IMODE(child_info.st_mode) & 0o022
            or (child_info.st_dev, child_info.st_ino)
                != (visible_info.st_dev, visible_info.st_ino)
        ):
            os.close(child)
            fail()
        directory_descriptors.append(child)
        parent = child

    def revalidate_directories() -> None:
        for index, component in enumerate(components[:-1]):
            visible = os.stat(
                component,
                dir_fd=directory_descriptors[index],
                follow_symlinks=False,
            )
            held = os.fstat(directory_descriptors[index + 1])
            if (
                not stat.S_ISDIR(visible.st_mode)
                or visible.st_uid != os.getuid()
                or stat.S_IMODE(visible.st_mode) & 0o022
                or (visible.st_dev, visible.st_ino) != (held.st_dev, held.st_ino)
            ):
                fail()

    fcntl.flock(parent, fcntl.LOCK_EX)
    revalidate_directories()
    for directory in directory_descriptors[3:]:
        if has_extended_acl(directory):
            fail()
    leaf = components[-1]
    try:
        leaf_info = os.stat(leaf, dir_fd=parent, follow_symlinks=False)
    except FileNotFoundError:
        leaf_info = None

    if leaf_info is not None:
        if not stat.S_ISREG(leaf_info.st_mode):
            fail()
        descriptor = os.open(
            leaf,
            os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC,
            dir_fd=parent,
        )
        try:
            fcntl.flock(descriptor, fcntl.LOCK_SH)
            info = verify_model(descriptor, target_file=True)
            final = os.stat(leaf, dir_fd=parent, follow_symlinks=False)
            if (info.st_dev, info.st_ino) != (final.st_dev, final.st_ino):
                fail()
            for directory in directory_descriptors[3:]:
                os.fchmod(directory, 0o700)
                if stat.S_IMODE(os.fstat(directory).st_mode) != 0o700:
                    fail()
            revalidate_directories()
            final = os.stat(leaf, dir_fd=parent, follow_symlinks=False)
            if (info.st_dev, info.st_ino) != (final.st_dev, final.st_ino):
                fail()
        finally:
            os.close(descriptor)
        success = True
    else:
        for directory in directory_descriptors[3:]:
            os.fchmod(directory, 0o700)
            if stat.S_IMODE(os.fstat(directory).st_mode) != 0o700:
                fail()
        if stat.S_IMODE(os.fstat(parent).st_mode) != 0o700:
            fail()
        revalidate_directories()

        clone = getattr(libc, "fclonefileat", None)
        clone_error = errno.ENOSYS
        if clone is not None:
            clone.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_char_p, ctypes.c_int]
            clone.restype = ctypes.c_int
            ctypes.set_errno(0)
            if clone(source_descriptor, parent, os.fsencode(leaf), 0x0003) == 0:
                created_leaf = True
                cloned = os.stat(leaf, dir_fd=parent, follow_symlinks=False)
                created_leaf_identity = (cloned.st_dev, cloned.st_ino)
            else:
                clone_error = ctypes.get_errno()
        if not created_leaf:
            if clone_error not in (
                errno.ENOTSUP,
                errno.EXDEV,
                errno.EINVAL,
                errno.ENOSYS,
            ):
                fail()
            destination = os.open(
                leaf,
                os.O_WRONLY
                | os.O_CREAT
                | os.O_EXCL
                | os.O_NOFOLLOW
                | os.O_CLOEXEC,
                0o600,
                dir_fd=parent,
            )
            created_leaf = True
            created = os.fstat(destination)
            created_leaf_identity = (created.st_dev, created.st_ino)
            try:
                os.lseek(source_descriptor, 0, os.SEEK_SET)
                while chunk := os.read(source_descriptor, 1024 * 1024):
                    view = memoryview(chunk)
                    while view:
                        written = os.write(destination, view)
                        if written <= 0:
                            fail()
                        view = view[written:]
                os.fsync(destination)
            finally:
                os.close(destination)

        # A test-only seventh argument forces a same-owner path replacement
        # after creation. It can only make preparation fail and exists to prove
        # cleanup never unlinks an inode it did not create.
        if selftest_replacement:
            replacement_info = os.lstat(selftest_replacement)
            if (
                not stat.S_ISREG(replacement_info.st_mode)
                or replacement_info.st_uid != os.getuid()
                or replacement_info.st_nlink != 1
            ):
                fail()
            backup_leaf = f"{leaf}.created-selftest"
            try:
                os.stat(backup_leaf, dir_fd=parent, follow_symlinks=False)
            except FileNotFoundError:
                pass
            else:
                fail()
            os.rename(
                leaf,
                backup_leaf,
                src_dir_fd=parent,
                dst_dir_fd=parent,
            )
            os.rename(selftest_replacement, leaf, dst_dir_fd=parent)

        descriptor = os.open(
            leaf,
            os.O_RDWR | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC,
            dir_fd=parent,
        )
        try:
            os.fchmod(descriptor, 0o600)
            fcntl.flock(descriptor, fcntl.LOCK_EX)
            info = verify_model(descriptor, target_file=True)
            final = os.stat(leaf, dir_fd=parent, follow_symlinks=False)
            if (info.st_dev, info.st_ino) != (final.st_dev, final.st_ino):
                fail()
            revalidate_directories()
            os.fsync(descriptor)
        finally:
            os.close(descriptor)
        os.fsync(parent)
        success = True
except (OSError, ValueError, AttributeError):
    fail()
finally:
    if not success:
        if created_leaf and created_leaf_identity is not None and directory_descriptors:
            try:
                visible = os.stat(
                    components[-1],
                    dir_fd=directory_descriptors[-1],
                    follow_symlinks=False,
                )
                if (visible.st_dev, visible.st_ino) == created_leaf_identity:
                    os.unlink(components[-1], dir_fd=directory_descriptors[-1])
                    os.fsync(directory_descriptors[-1])
                else:
                    print(
                        f"{label} model cleanup refused a path-replaced target",
                        file=sys.stderr,
                    )
            except OSError:
                pass
        for parent_descriptor, component in reversed(created_directories):
            try:
                os.rmdir(component, dir_fd=parent_descriptor)
            except OSError:
                pass
    for descriptor in reversed(directory_descriptors):
        try:
            os.close(descriptor)
        except OSError:
            pass
    if source_descriptor is not None:
        try:
            os.close(source_descriptor)
        except OSError:
            pass
PY
}

tilde_source_snapshot_sha256() {
  local root="$1" commit="$2" tree="$3"
  tilde_python_isolated - "$root" "$commit" "$tree" <<'PY'
import hashlib
import os
import stat
import subprocess
import sys

root, commit, tree = sys.argv[1:]

def git(*args: str) -> bytes:
    environment = os.environ.copy()
    for key in (
        "GIT_DIR",
        "GIT_WORK_TREE",
        "GIT_INDEX_FILE",
        "GIT_OBJECT_DIRECTORY",
        "GIT_ALTERNATE_OBJECT_DIRECTORIES",
        "GIT_COMMON_DIR",
        "GIT_CONFIG_COUNT",
        "GIT_CONFIG_PARAMETERS",
        "GIT_PREFIX",
    ):
        environment.pop(key, None)
    environment.update(
        {
            "GIT_NO_REPLACE_OBJECTS": "1",
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_ATTR_NOSYSTEM": "1",
        }
    )
    return subprocess.check_output(
        [
            "/usr/bin/git",
            "--no-optional-locks",
            "-c",
            "core.fsmonitor=false",
            "-c",
            "core.untrackedCache=false",
            "-c",
            "core.attributesFile=/dev/null",
            "-C",
            root,
            *args,
        ],
        env=environment,
    )

digest = hashlib.sha256()
digest.update(b"tilde-source-snapshot-v1\0")
digest.update(commit.encode("ascii") + b"\0")
digest.update(tree.encode("ascii") + b"\0")
digest.update(git("diff", "--binary", "--no-ext-diff", "HEAD", "--"))

untracked = sorted(
    path for path in git("ls-files", "--others", "--exclude-standard", "-z").split(b"\0")
    if path
)
root_bytes = os.fsencode(root)
for path in untracked:
    absolute = os.path.join(root_bytes, path)
    info = os.lstat(absolute)
    digest.update(b"untracked\0" + path + b"\0")
    digest.update(f"{stat.S_IFMT(info.st_mode):o}:{stat.S_IMODE(info.st_mode):o}".encode("ascii"))
    digest.update(b"\0")
    if stat.S_ISREG(info.st_mode):
        with open(absolute, "rb") as handle:
            while chunk := handle.read(1024 * 1024):
                digest.update(chunk)
    elif stat.S_ISLNK(info.st_mode):
        digest.update(os.fsencode(os.readlink(absolute)))
    else:
        raise SystemExit("unsupported untracked source entry type")
    digest.update(b"\0")

print(digest.hexdigest())
PY
}

tilde_capture_source_provenance() {
  local root="$1" evidence_class="${2:-decision-grade}"
  local top status unexpected_entry

  case "$evidence_class" in
    decision-grade|diagnostic) ;;
    *) echo "source evidence class must be decision-grade or diagnostic" >&2; return 2 ;;
  esac

  top="$(tilde_git_raw "$root" rev-parse --show-toplevel 2>/dev/null)" \
    || { echo "packaged builds require a Git worktree" >&2; return 1; }
  [[ "$(cd "$top" && pwd -P)" == "$(cd "$root" && pwd -P)" ]] \
    || { echo "packaged build root is not the Git worktree root" >&2; return 1; }

  if [[ "$evidence_class" == "decision-grade" ]]; then
    tilde_reject_unsafe_git_metadata "$root" || return
  fi

  TILDE_SOURCE_COMMIT="$(tilde_git_raw "$root" rev-parse --verify 'HEAD^{commit}')"
  TILDE_SOURCE_TREE="$(
    tilde_git_raw "$root" rev-parse --verify "$TILDE_SOURCE_COMMIT^{tree}"
  )"
  [[ "$TILDE_SOURCE_COMMIT" =~ ^[0-9a-f]{40}$ && "$TILDE_SOURCE_TREE" =~ ^[0-9a-f]{40}$ ]] \
    || { echo "Git source identity is malformed" >&2; return 1; }
  [[ "$(tilde_git_raw "$root" rev-parse --verify "$TILDE_SOURCE_COMMIT^{tree}")" \
      == "$TILDE_SOURCE_TREE" ]] \
    || { echo "Git commit does not bind the recorded source tree" >&2; return 1; }

  status="$(
    tilde_git_raw "$root" status --porcelain=v1 \
      --untracked-files=all --ignore-submodules=none
  )"
  if [[ -n "$status" ]]; then
    TILDE_SOURCE_STATE="dirty"
    [[ "$evidence_class" == "diagnostic" ]] || {
      echo "decision-grade preview build refused: source tree is dirty" >&2
      echo "commit or clean the source, or pass --diagnostic-dirty-source for a non-evidentiary package" >&2
      return 1
    }
  else
    TILDE_SOURCE_STATE="clean"
  fi

  TILDE_SOURCE_EVIDENCE_CLASS="$evidence_class"
  if [[ "$evidence_class" == "decision-grade" ]]; then
    unexpected_entry="$(
      tilde_git_raw "$root" ls-tree -r "$TILDE_SOURCE_COMMIT" \
        | /usr/bin/awk '$1 != "100644" && $1 != "100755" { print; exit }'
    )"
    [[ -z "$unexpected_entry" ]] || {
      echo "decision-grade source archive contains a link, submodule, or special entry" >&2
      return 1
    }
    TILDE_SOURCE_SNAPSHOT_SHA256="$(
      tilde_clean_commit_manifest_sha256 "$root" "$TILDE_SOURCE_COMMIT"
    )"
  else
    TILDE_SOURCE_SNAPSHOT_SHA256="$(
      tilde_source_snapshot_sha256 \
        "$root" "$TILDE_SOURCE_COMMIT" "$TILDE_SOURCE_TREE"
    )"
  fi
  [[ "$TILDE_SOURCE_SNAPSHOT_SHA256" =~ ^[0-9a-f]{64}$ ]] \
    || { echo "source snapshot identity is malformed" >&2; return 1; }
  export TILDE_SOURCE_COMMIT TILDE_SOURCE_TREE TILDE_SOURCE_STATE
  export TILDE_SOURCE_EVIDENCE_CLASS TILDE_SOURCE_SNAPSHOT_SHA256
}

tilde_assert_source_provenance_unchanged() {
  local root="$1" current_commit current_tree current_status current_state current_snapshot
  local materialized_snapshot
  if [[ "$TILDE_SOURCE_EVIDENCE_CLASS" == "decision-grade" ]]; then
    tilde_reject_unsafe_git_metadata "$root" || return
  fi
  current_commit="$(tilde_git_raw "$root" rev-parse --verify 'HEAD^{commit}')"
  current_tree="$(
    tilde_git_raw "$root" rev-parse --verify "$current_commit^{tree}"
  )"
  current_status="$(
    tilde_git_raw "$root" status --porcelain=v1 \
      --untracked-files=all --ignore-submodules=none
  )"
  current_state="clean"
  [[ -z "$current_status" ]] || current_state="dirty"
  if [[ "$TILDE_SOURCE_EVIDENCE_CLASS" == "decision-grade" ]]; then
    current_snapshot="$(tilde_clean_commit_manifest_sha256 "$root" "$current_commit")"
  else
    current_snapshot="$(tilde_source_snapshot_sha256 "$root" "$current_commit" "$current_tree")"
  fi

  [[ "$current_commit" == "$TILDE_SOURCE_COMMIT" \
      && "$current_tree" == "$TILDE_SOURCE_TREE" \
      && "$current_state" == "$TILDE_SOURCE_STATE" \
      && "$current_snapshot" == "$TILDE_SOURCE_SNAPSHOT_SHA256" ]] || {
    echo "source changed while the package was building; refusing to sign it" >&2
    return 1
  }
  if [[ "$TILDE_SOURCE_EVIDENCE_CLASS" == "decision-grade" \
      && "$current_state" != "clean" ]]; then
    echo "decision-grade package ended with dirty source; refusing to sign it" >&2
    return 1
  fi
  if [[ -n "${TILDE_BUILD_SOURCE_ROOT:-}" \
      && "${TILDE_BUILD_SOURCE_ROOT:-}" != "$(cd "$root" && pwd -P)" ]]; then
    materialized_snapshot="$(
      tilde_source_tree_manifest_sha256 "$TILDE_BUILD_SOURCE_ROOT"
    )" || return
    [[ "$materialized_snapshot" == "$TILDE_SOURCE_SNAPSHOT_SHA256" ]] || {
      echo "materialized build source changed after capture" >&2
      return 1
    }
  fi
}

tilde_assert_build_source_unchanged() {
  [[ -n "${TILDE_BUILD_SOURCE_ROOT:-}" ]] \
    || { echo "build source has not been prepared" >&2; return 1; }
  tilde_assert_source_provenance_unchanged "$1"
}

tilde_embed_source_provenance() {
  local plist="$1" key value
  [[ -f "$plist" ]] || { echo "missing provenance plist: $plist" >&2; return 1; }
  while IFS=$'\t' read -r key value; do
    /usr/libexec/PlistBuddy -c "Delete :$key" "$plist" >/dev/null 2>&1 || true
    /usr/libexec/PlistBuddy -c "Add :$key string $value" "$plist"
  done <<EOF
TildeSourceCommit	$TILDE_SOURCE_COMMIT
TildeSourceTree	$TILDE_SOURCE_TREE
TildeSourceSnapshotSHA256	$TILDE_SOURCE_SNAPSHOT_SHA256
TildeSourceState	$TILDE_SOURCE_STATE
TildeEvidenceClass	$TILDE_SOURCE_EVIDENCE_CLASS
EOF
}

tilde_verify_source_provenance() {
  local plist="$1"
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :TildeSourceCommit' "$plist")" == "$TILDE_SOURCE_COMMIT" ]]
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :TildeSourceTree' "$plist")" == "$TILDE_SOURCE_TREE" ]]
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :TildeSourceSnapshotSHA256' "$plist")" == "$TILDE_SOURCE_SNAPSHOT_SHA256" ]]
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :TildeSourceState' "$plist")" == "$TILDE_SOURCE_STATE" ]]
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :TildeEvidenceClass' "$plist")" == "$TILDE_SOURCE_EVIDENCE_CLASS" ]]
}

tilde_validate_build_provenance_values() {
  [[ "${TILDE_APPLE_TOOLCHAIN_SHA256:-}" =~ ^[0-9a-f]{64}$ \
      && "${TILDE_XCODE_VERSION:-}" =~ ^[0-9]+([.][0-9]+){1,3}$ \
      && "${TILDE_XCODE_BUILD:-}" =~ ^[A-Za-z0-9]{1,32}$ \
      && "${TILDE_XCODE_CDHASH:-}" =~ ^[0-9a-f]{40}([0-9a-f]{24})?$ \
      && "${TILDE_SWIFT_VERSION_SHA256:-}" =~ ^[0-9a-f]{64}$ \
      && "${TILDE_SWIFT_EXECUTABLE_SHA256:-}" =~ ^[0-9a-f]{64}$ \
      && "${TILDE_SWIFT_BUILD_EXECUTABLE_SHA256:-}" =~ ^[0-9a-f]{64}$ \
      && "${TILDE_SWIFT_DRIVER_EXECUTABLE_SHA256:-}" =~ ^[0-9a-f]{64}$ \
      && "${TILDE_CLANG_EXECUTABLE_SHA256:-}" =~ ^[0-9a-f]{64}$ \
      && "${TILDE_LINKER_EXECUTABLE_SHA256:-}" =~ ^[0-9a-f]{64}$ \
      && "${TILDE_LIBTOOL_EXECUTABLE_SHA256:-}" =~ ^[0-9a-f]{64}$ \
      && "${TILDE_ARCHIVER_EXECUTABLE_SHA256:-}" =~ ^[0-9a-f]{64}$ \
      && "${TILDE_MACOS_SDK_VERSION:-}" =~ ^[0-9]+([.][0-9]+){1,3}$ \
      && "${TILDE_MACOS_SDK_BUILD:-}" =~ ^[A-Za-z0-9]{1,32}$ \
      && "${TILDE_MACOS_SDK_SETTINGS_SHA256:-}" =~ ^[0-9a-f]{64}$ \
      && "${TILDE_HELPER_INPUT_SHA256:-}" =~ ^[0-9a-f]{64}$ \
      && "${TILDE_HELPER_APPROVED_TEAM:-}" =~ ^[A-Z0-9]{10}$ \
      && "${TILDE_F03_RUNNER_SHA256:-}" =~ ^[0-9a-f]{64}$ ]] || {
    echo "portable build provenance is missing or malformed" >&2
    return 1
  }
}

# API for signed bundles. Only portable identities are embedded: local
# developer, SDK, helper, and staging paths deliberately remain runtime-only.
tilde_embed_build_provenance() {
  local plist="$1" key value
  tilde_validate_build_provenance_values || return
  tilde_embed_source_provenance "$plist" || return
  while IFS=$'\t' read -r key value; do
    /usr/libexec/PlistBuddy -c "Delete :$key" "$plist" >/dev/null 2>&1 || true
    /usr/libexec/PlistBuddy -c "Add :$key string $value" "$plist" || return
  done <<EOF
TildeAppleToolchainSHA256	$TILDE_APPLE_TOOLCHAIN_SHA256
TildeAppleToolchainIdentitySchema	tilde-apple-toolchain-v2
TildeXcodeVersion	$TILDE_XCODE_VERSION
TildeXcodeBuild	$TILDE_XCODE_BUILD
TildeXcodeCDHash	$TILDE_XCODE_CDHASH
TildeSwiftVersionSHA256	$TILDE_SWIFT_VERSION_SHA256
TildeSwiftExecutableSHA256	$TILDE_SWIFT_EXECUTABLE_SHA256
TildeSwiftBuildExecutableSHA256	$TILDE_SWIFT_BUILD_EXECUTABLE_SHA256
TildeSwiftDriverExecutableSHA256	$TILDE_SWIFT_DRIVER_EXECUTABLE_SHA256
TildeClangExecutableSHA256	$TILDE_CLANG_EXECUTABLE_SHA256
TildeLinkerExecutableSHA256	$TILDE_LINKER_EXECUTABLE_SHA256
TildeLibtoolExecutableSHA256	$TILDE_LIBTOOL_EXECUTABLE_SHA256
TildeArchiverExecutableSHA256	$TILDE_ARCHIVER_EXECUTABLE_SHA256
TildeMacOSSDKVersion	$TILDE_MACOS_SDK_VERSION
TildeMacOSSDKBuild	$TILDE_MACOS_SDK_BUILD
TildeMacOSSDKSettingsSHA256	$TILDE_MACOS_SDK_SETTINGS_SHA256
TildeApprovedHelperInputSHA256	$TILDE_HELPER_INPUT_SHA256
TildeApprovedHelperTeamIdentifier	$TILDE_HELPER_APPROVED_TEAM
TildeF03RunnerSHA256	$TILDE_F03_RUNNER_SHA256
EOF
}

tilde_verify_build_provenance() {
  local plist="$1" key expected actual
  tilde_validate_build_provenance_values || return
  tilde_verify_source_provenance "$plist" || return
  while IFS=$'\t' read -r key expected; do
    actual="$(/usr/libexec/PlistBuddy -c "Print :$key" "$plist")" || {
      echo "missing portable build provenance key: $key" >&2
      return 1
    }
    [[ "$actual" == "$expected" ]] || {
      echo "portable build provenance mismatch: $key" >&2
      return 1
    }
  done <<EOF
TildeAppleToolchainSHA256	$TILDE_APPLE_TOOLCHAIN_SHA256
TildeAppleToolchainIdentitySchema	tilde-apple-toolchain-v2
TildeXcodeVersion	$TILDE_XCODE_VERSION
TildeXcodeBuild	$TILDE_XCODE_BUILD
TildeXcodeCDHash	$TILDE_XCODE_CDHASH
TildeSwiftVersionSHA256	$TILDE_SWIFT_VERSION_SHA256
TildeSwiftExecutableSHA256	$TILDE_SWIFT_EXECUTABLE_SHA256
TildeSwiftBuildExecutableSHA256	$TILDE_SWIFT_BUILD_EXECUTABLE_SHA256
TildeSwiftDriverExecutableSHA256	$TILDE_SWIFT_DRIVER_EXECUTABLE_SHA256
TildeClangExecutableSHA256	$TILDE_CLANG_EXECUTABLE_SHA256
TildeLinkerExecutableSHA256	$TILDE_LINKER_EXECUTABLE_SHA256
TildeLibtoolExecutableSHA256	$TILDE_LIBTOOL_EXECUTABLE_SHA256
TildeArchiverExecutableSHA256	$TILDE_ARCHIVER_EXECUTABLE_SHA256
TildeMacOSSDKVersion	$TILDE_MACOS_SDK_VERSION
TildeMacOSSDKBuild	$TILDE_MACOS_SDK_BUILD
TildeMacOSSDKSettingsSHA256	$TILDE_MACOS_SDK_SETTINGS_SHA256
TildeApprovedHelperInputSHA256	$TILDE_HELPER_INPUT_SHA256
TildeApprovedHelperTeamIdentifier	$TILDE_HELPER_APPROVED_TEAM
TildeF03RunnerSHA256	$TILDE_F03_RUNNER_SHA256
EOF
}

tilde_source_provenance_selftest() (
  set -euo pipefail
  local selftest_root temporary root plist clean_snapshot untracked_snapshot
  local sealed_root sealed_temporary model_source model_bytes model_sha
  local model_home model_target unsafe_home unsafe_target outside
  local flags_root newline_name replace_root commit_a commit_b
  local helper_parent helper_source helper_destination helper_sha helper_identity
  local hardlink_source team toolchain_identity swift_executable sdk_path fake_toolchain
  local runner_fixture runner_fixture_sha
  local source_app publish_parent publish_destination publish_manifest published_identity
  local restricted_manifest unsafe_root_destination
  local quarantine_transaction quarantine_bundle quarantine_identity replacement
  local invalid_version long_version swift_build_help
  local build_lock_root first_build_lock_identity
  selftest_root="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/tilde-source-provenance.XXXXXX")"
  temporary="$selftest_root"
  trap 'tilde_release_preview_build_lock >/dev/null 2>&1 || true; tilde_cleanup_build_source >/dev/null 2>&1 || true; /bin/rm -rf -- "$selftest_root"' EXIT
  root="$temporary/repo"
  /bin/mkdir -p "$root"
  /usr/bin/git -C "$root" init -q
  printf 'sealed\n' >"$root/source.txt"
  /usr/bin/git -C "$root" add source.txt
  /usr/bin/git -C "$root" -c user.name=Tilde -c user.email=tilde.invalid commit -qm initial

  tilde_prepare_build_source "$root" decision-grade
  [[ "$TILDE_SOURCE_STATE" == "clean" && "$TILDE_SOURCE_EVIDENCE_CLASS" == "decision-grade" ]]
  clean_snapshot="$TILDE_SOURCE_SNAPSHOT_SHA256"
  sealed_root="$TILDE_BUILD_SOURCE_ROOT"
  sealed_temporary="$TILDE_BUILD_SOURCE_TEMP"
  [[ "$sealed_root" != "$root" && -d "$sealed_temporary" ]]
  [[ "$(<"$sealed_root/source.txt")" == "sealed" ]]
  [[ "$(/usr/bin/stat -f '%Lp' "$sealed_root")" == "500" ]]
  [[ "$(/usr/bin/stat -f '%Lp' "$sealed_root/source.txt")" == "400" ]]
  tilde_assert_source_provenance_unchanged "$root"

  /bin/chmod 600 "$sealed_root/source.txt"
  printf 'materialized-tamper\n' >"$sealed_root/source.txt"
  /bin/chmod 400 "$sealed_root/source.txt"
  if tilde_assert_source_provenance_unchanged "$root" >/dev/null 2>&1; then
    echo "selftest FAIL: changed materialized source bytes were accepted" >&2
    return 1
  fi
  tilde_cleanup_build_source
  tilde_prepare_build_source "$root" decision-grade
  [[ "$TILDE_SOURCE_SNAPSHOT_SHA256" == "$clean_snapshot" ]]
  sealed_root="$TILDE_BUILD_SOURCE_ROOT"
  sealed_temporary="$TILDE_BUILD_SOURCE_TEMP"
  /bin/chmod 600 "$sealed_root/source.txt"
  if tilde_assert_source_provenance_unchanged "$root" >/dev/null 2>&1; then
    echo "selftest FAIL: changed materialized source mode was accepted" >&2
    return 1
  fi
  tilde_cleanup_build_source
  tilde_prepare_build_source "$root" decision-grade
  [[ "$TILDE_SOURCE_SNAPSHOT_SHA256" == "$clean_snapshot" ]]
  sealed_root="$TILDE_BUILD_SOURCE_ROOT"
  sealed_temporary="$TILDE_BUILD_SOURCE_TEMP"

  printf 'dirty\n' >>"$root/source.txt"
  [[ "$(<"$sealed_root/source.txt")" == "sealed" ]]
  if tilde_assert_source_provenance_unchanged "$root" >/dev/null 2>&1; then
    echo "selftest FAIL: source mutation during build was accepted" >&2
    return 1
  fi
  /usr/bin/git -C "$root" checkout -q -- source.txt
  [[ "$(<"$root/source.txt")" == "sealed" ]]
  [[ "$(<"$sealed_root/source.txt")" == "sealed" ]]
  tilde_assert_source_provenance_unchanged "$root"
  tilde_cleanup_build_source
  [[ ! -e "$sealed_temporary" ]]

  printf 'dirty\n' >>"$root/source.txt"
  if tilde_prepare_build_source "$root" decision-grade >/dev/null 2>&1; then
    echo "selftest FAIL: dirty source entered the decision-grade lane" >&2
    return 1
  fi
  tilde_prepare_build_source "$root" diagnostic
  [[ "$TILDE_SOURCE_STATE" == "dirty" && "$TILDE_SOURCE_EVIDENCE_CLASS" == "diagnostic" ]]
  [[ "$TILDE_BUILD_SOURCE_ROOT" == "$(cd "$root" && pwd -P)" ]]
  [[ -z "$TILDE_BUILD_SOURCE_TEMP" ]]
  [[ "$(tail -n 1 "$TILDE_BUILD_SOURCE_ROOT/source.txt")" == "dirty" ]]
  [[ "$TILDE_SOURCE_SNAPSHOT_SHA256" != "$clean_snapshot" ]]

  /usr/bin/git -C "$root" checkout -q -- source.txt
  printf 'untracked\n' >"$root/untracked.txt"
  tilde_capture_source_provenance "$root" diagnostic
  untracked_snapshot="$TILDE_SOURCE_SNAPSHOT_SHA256"
  printf 'untracked-changed\n' >>"$root/untracked.txt"
  tilde_capture_source_provenance "$root" diagnostic
  [[ "$TILDE_SOURCE_SNAPSHOT_SHA256" != "$untracked_snapshot" ]]

  plist="$temporary/Info.plist"
  printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' \
    '<plist version="1.0"><dict></dict></plist>' >"$plist"
  tilde_embed_source_provenance "$plist"
  tilde_verify_source_provenance "$plist"

  printf 'changed-again\n' >>"$root/source.txt"
  if tilde_assert_source_provenance_unchanged "$root" >/dev/null 2>&1; then
    echo "selftest FAIL: source mutation during build was accepted" >&2
    return 1
  fi

  flags_root="$temporary/index-flags-repo"
  /bin/mkdir "$flags_root"
  /usr/bin/git -C "$flags_root" init -q
  printf 'visible\n' >"$flags_root/plain.txt"
  newline_name=$'skip\nworktree.txt'
  printf 'visible-newline\n' >"$flags_root/$newline_name"
  /usr/bin/git -C "$flags_root" add -- plain.txt "$newline_name"
  /usr/bin/git -C "$flags_root" \
    -c user.name=Tilde -c user.email=tilde.invalid commit -qm initial

  /usr/bin/git -C "$flags_root" update-index --assume-unchanged -- plain.txt
  printf 'hidden-by-index-flag\n' >"$flags_root/plain.txt"
  if tilde_capture_source_provenance "$flags_root" decision-grade \
      >/dev/null 2>&1; then
    echo "selftest FAIL: assume-unchanged source was accepted" >&2
    return 1
  fi
  /usr/bin/git -C "$flags_root" update-index --no-assume-unchanged -- plain.txt
  /usr/bin/git -C "$flags_root" checkout -q -- plain.txt

  /usr/bin/git -C "$flags_root" update-index --skip-worktree -- "$newline_name"
  printf 'hidden-newline-path\n' >"$flags_root/$newline_name"
  if tilde_capture_source_provenance "$flags_root" decision-grade \
      >/dev/null 2>&1; then
    echo "selftest FAIL: NUL-delimited skip-worktree source was accepted" >&2
    return 1
  fi
  /usr/bin/git -C "$flags_root" update-index --no-skip-worktree -- "$newline_name"
  /usr/bin/git -C "$flags_root" checkout -q -- "$newline_name"

  /usr/bin/git -C "$flags_root" config core.fsmonitor "$temporary/missing-monitor"
  /usr/bin/git -C "$flags_root" config core.untrackedCache true
  (
    export GIT_DIR="$temporary/poisoned-git-dir"
    export GIT_WORK_TREE="$temporary/poisoned-worktree"
    export GIT_INDEX_FILE="$temporary/poisoned-index"
    export GIT_OBJECT_DIRECTORY="$temporary/poisoned-objects"
    export GIT_CONFIG_COUNT=1
    export GIT_CONFIG_KEY_0=core.fsmonitor
    export GIT_CONFIG_VALUE_0="$temporary/poisoned-monitor"
    tilde_capture_source_provenance "$flags_root" decision-grade
    [[ "$TILDE_SOURCE_STATE" == "clean" ]]
  )

  replace_root="$temporary/replace-repo"
  /bin/mkdir "$replace_root"
  /usr/bin/git -C "$replace_root" init -q
  printf 'tree-a\n' >"$replace_root/source.txt"
  /usr/bin/git -C "$replace_root" add source.txt
  /usr/bin/git -C "$replace_root" \
    -c user.name=Tilde -c user.email=tilde.invalid commit -qm tree-a
  commit_a="$(/usr/bin/git -C "$replace_root" rev-parse HEAD)"
  printf 'tree-b\n' >"$replace_root/source.txt"
  /usr/bin/git -C "$replace_root" \
    -c user.name=Tilde -c user.email=tilde.invalid commit -qam tree-b
  commit_b="$(/usr/bin/git -C "$replace_root" rev-parse HEAD)"
  /usr/bin/git -C "$replace_root" replace "$commit_a" "$commit_b"
  tilde_git_raw "$replace_root" reset --hard -q "$commit_a"
  if tilde_capture_source_provenance "$replace_root" decision-grade \
      >/dev/null 2>&1; then
    echo "selftest FAIL: Git replacement objects were accepted" >&2
    return 1
  fi
  tilde_git_raw "$replace_root" update-ref -d "refs/replace/$commit_a"
  /bin/mkdir -p "$replace_root/.git/info"
  printf '%s %s\n' "$commit_a" "$commit_b" >"$replace_root/.git/info/grafts"
  if tilde_capture_source_provenance "$replace_root" decision-grade \
      >/dev/null 2>&1; then
    echo "selftest FAIL: legacy Git graft metadata was accepted" >&2
    return 1
  fi

  model_source="$temporary/model-source.gguf"
  printf 'GGUFfixture\n' >"$model_source"
  model_bytes="$(/usr/bin/stat -f '%z' "$model_source")"
  model_sha="$(/usr/bin/shasum -a 256 "$model_source" | /usr/bin/awk '{print $1}')"
  tilde_verify_model_file "$model_source" "$model_bytes" "$model_sha" fixture
  if tilde_verify_model_file \
      "$model_source" "$model_bytes" "$model_sha" fixture selftest-inplace-touch \
      >/dev/null 2>&1; then
    echo "selftest FAIL: in-place model mutation during verification was accepted" >&2
    return 1
  fi

  /usr/bin/mkfifo "$temporary/model-source.fifo"
  unsafe_home="$temporary/fifo-home"
  /bin/mkdir -m 700 "$unsafe_home"
  unsafe_target="$unsafe_home/Library/Application Support/FIFO Preview/Models/test/model.gguf"
  tilde_python_isolated - \
    "${BASH_SOURCE[0]}" "$temporary/model-source.fifo" \
    "$model_bytes" "$model_sha" "$unsafe_home" "$unsafe_target" <<'PY'
import os
import signal
import subprocess
import sys

script, fifo, expected_bytes, expected_sha, home, target = sys.argv[1:]
script = os.path.realpath(script)
commands = [
    (
        "model verifier",
        [
            "/bin/bash",
            "-c",
            'source "$1"; tilde_verify_model_file "$2" "$3" "$4" fixture',
            "tilde-fifo-verifier",
            script,
            fifo,
            expected_bytes,
            expected_sha,
        ],
    ),
    (
        "target preparation",
        [
            "/bin/bash",
            "-c",
            'source "$1"; tilde_prepare_owner_only_model_target '
            '"$2" "$3" "$4" "$5" fixture "$6"',
            "tilde-fifo-target",
            script,
            fifo,
            target,
            expected_bytes,
            expected_sha,
            home,
        ],
    ),
]
for context, command in commands:
    process = subprocess.Popen(
        command,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    try:
        result = process.wait(timeout=1.0)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait()
        print(
            f"selftest FAIL: {context} blocked while opening a FIFO model source",
            file=sys.stderr,
        )
        raise SystemExit(1)
    if result == 0:
        print(f"selftest FAIL: {context} accepted a FIFO model source", file=sys.stderr)
        raise SystemExit(1)
PY
  [[ ! -e "$unsafe_home/Library" ]]

  model_home="$temporary/model-home"
  /bin/mkdir -m 700 "$model_home"
  model_target="$model_home/Library/Application Support/Test Preview/Models/test/model.gguf"
  tilde_prepare_owner_only_model_target \
    "$model_source" "$model_target" "$model_bytes" "$model_sha" fixture "$model_home"
  [[ "$(<"$model_target")" == "GGUFfixture" ]]
  [[ "$(/usr/bin/stat -f '%Lp' "$model_target")" == "600" ]]
  [[ "$(/usr/bin/stat -f '%l' "$model_target")" == "1" ]]
  [[ "$(/usr/bin/stat -f '%Lp' "$model_home/Library/Application Support/Test Preview")" == "700" ]]
  [[ "$(/usr/bin/stat -f '%Lp' "$(/usr/bin/dirname "$model_target")")" == "700" ]]
  tilde_prepare_owner_only_model_target \
    "$model_source" "$model_target" "$model_bytes" "$model_sha" fixture "$model_home"

  unsafe_home="$temporary/replaced-cleanup-home"
  /bin/mkdir -m 700 "$unsafe_home"
  replacement="$unsafe_home/replacement.gguf"
  printf 'GGUFreplacement-owned-by-selftest\n' >"$replacement"
  /bin/chmod 600 "$replacement"
  unsafe_target="$unsafe_home/Library/Application Support/Replacement Preview/Models/test/model.gguf"
  if tilde_prepare_owner_only_model_target \
      "$model_source" "$unsafe_target" "$model_bytes" "$model_sha" fixture \
      "$unsafe_home" "$replacement" >/dev/null 2>&1; then
    echo "selftest FAIL: path-replaced model target was accepted" >&2
    return 1
  fi
  [[ "$(<"$unsafe_target")" == "GGUFreplacement-owned-by-selftest" ]]
  [[ -f "$unsafe_target.created-selftest" ]]

  unsafe_home="$temporary/symlink-home"
  outside="$temporary/symlink-outside"
  /bin/mkdir -m 700 "$unsafe_home" "$outside"
  /bin/mkdir -p "$unsafe_home/Library/Application Support"
  /bin/ln -s "$outside" "$unsafe_home/Library/Application Support/Linked Preview"
  unsafe_target="$unsafe_home/Library/Application Support/Linked Preview/Models/test/model.gguf"
  if tilde_prepare_owner_only_model_target \
      "$model_source" "$unsafe_target" "$model_bytes" "$model_sha" fixture "$unsafe_home" \
      >/dev/null 2>&1; then
    echo "selftest FAIL: symlinked model directory was accepted" >&2
    return 1
  fi
  [[ -z "$(/usr/bin/find "$outside" -mindepth 1 -print -quit)" ]]

  unsafe_home="$temporary/nondirectory-home"
  /bin/mkdir -m 700 "$unsafe_home"
  /bin/mkdir "$unsafe_home/Library"
  printf 'not a directory\n' >"$unsafe_home/Library/Application Support"
  unsafe_target="$unsafe_home/Library/Application Support/File Preview/Models/test/model.gguf"
  if tilde_prepare_owner_only_model_target \
      "$model_source" "$unsafe_target" "$model_bytes" "$model_sha" fixture "$unsafe_home" \
      >/dev/null 2>&1; then
    echo "selftest FAIL: non-directory model component was accepted" >&2
    return 1
  fi
  [[ "$(<"$unsafe_home/Library/Application Support")" == "not a directory" ]]

  unsafe_home="$temporary/dangling-home"
  /bin/mkdir -m 700 "$unsafe_home"
  unsafe_target="$unsafe_home/Library/Application Support/Dangling Preview/Models/test/model.gguf"
  /bin/mkdir -p "$(/usr/bin/dirname "$unsafe_target")"
  /bin/chmod 755 \
    "$unsafe_home/Library/Application Support/Dangling Preview" \
    "$unsafe_home/Library/Application Support/Dangling Preview/Models" \
    "$(/usr/bin/dirname "$unsafe_target")"
  /bin/ln -s "$temporary/does-not-exist" "$unsafe_target"
  if tilde_prepare_owner_only_model_target \
      "$model_source" "$unsafe_target" "$model_bytes" "$model_sha" fixture "$unsafe_home" \
      >/dev/null 2>&1; then
    echo "selftest FAIL: dangling model symlink was accepted" >&2
    return 1
  fi
  [[ -L "$unsafe_target" ]]
  [[ "$(/usr/bin/stat -f '%Lp' "$unsafe_home/Library/Application Support/Dangling Preview")" == "755" ]]

  unsafe_home="$temporary/hardlink-home"
  /bin/mkdir -m 700 "$unsafe_home"
  unsafe_target="$unsafe_home/Library/Application Support/Hardlink Preview/Models/test/model.gguf"
  /bin/mkdir -p "$(/usr/bin/dirname "$unsafe_target")"
  /bin/chmod 755 \
    "$unsafe_home/Library/Application Support/Hardlink Preview" \
    "$unsafe_home/Library/Application Support/Hardlink Preview/Models" \
    "$(/usr/bin/dirname "$unsafe_target")"
  /bin/cp "$model_source" "$unsafe_home/hardlink-source.gguf"
  /bin/chmod 600 "$unsafe_home/hardlink-source.gguf"
  /bin/ln "$unsafe_home/hardlink-source.gguf" "$unsafe_target"
  if tilde_prepare_owner_only_model_target \
      "$model_source" "$unsafe_target" "$model_bytes" "$model_sha" fixture "$unsafe_home" \
      >/dev/null 2>&1; then
    echo "selftest FAIL: hard-linked model target was accepted" >&2
    return 1
  fi
  [[ "$(/usr/bin/stat -f '%l' "$unsafe_target")" == "2" ]]
  [[ "$(/usr/bin/stat -f '%Lp' "$unsafe_home/Library/Application Support/Hardlink Preview")" == "755" ]]

  unsafe_home="$temporary/mode-home"
  /bin/mkdir -m 700 "$unsafe_home"
  unsafe_target="$unsafe_home/Library/Application Support/Mode Preview/Models/test/model.gguf"
  /bin/mkdir -p "$(/usr/bin/dirname "$unsafe_target")"
  /bin/chmod 755 \
    "$unsafe_home/Library/Application Support/Mode Preview" \
    "$unsafe_home/Library/Application Support/Mode Preview/Models" \
    "$(/usr/bin/dirname "$unsafe_target")"
  /bin/cp "$model_source" "$unsafe_target"
  /bin/chmod 644 "$unsafe_target"
  if tilde_prepare_owner_only_model_target \
      "$model_source" "$unsafe_target" "$model_bytes" "$model_sha" fixture "$unsafe_home" \
      >/dev/null 2>&1; then
    echo "selftest FAIL: non-owner-only model target was accepted" >&2
    return 1
  fi
  [[ "$(/usr/bin/stat -f '%Lp' "$unsafe_target")" == "644" ]]
  [[ "$(/usr/bin/stat -f '%Lp' "$unsafe_home/Library/Application Support/Mode Preview")" == "755" ]]

  unsafe_home="$temporary/acl-home"
  /bin/mkdir -m 700 "$unsafe_home"
  unsafe_target="$unsafe_home/Library/Application Support/ACL Preview/Models/test/model.gguf"
  /bin/mkdir -p "$(/usr/bin/dirname "$unsafe_target")"
  /bin/chmod 755 \
    "$unsafe_home/Library/Application Support/ACL Preview" \
    "$unsafe_home/Library/Application Support/ACL Preview/Models" \
    "$(/usr/bin/dirname "$unsafe_target")"
  /bin/cp "$model_source" "$unsafe_target"
  /bin/chmod 600 "$unsafe_target"
  /bin/chmod +a "everyone allow read" "$unsafe_target"
  if tilde_prepare_owner_only_model_target \
      "$model_source" "$unsafe_target" "$model_bytes" "$model_sha" fixture "$unsafe_home" \
      >/dev/null 2>&1; then
    echo "selftest FAIL: ACL-readable model target was accepted" >&2
    return 1
  fi
  [[ "$(/usr/bin/stat -f '%Lp' "$unsafe_home/Library/Application Support/ACL Preview")" == "755" ]]

  helper_parent="$temporary/helper-stage"
  /bin/mkdir -m 700 "$helper_parent"
  helper_parent="$(cd "$helper_parent" && pwd -P)"
  helper_source="/usr/bin/true"
  helper_sha="$(/usr/bin/shasum -a 256 "$helper_source" | /usr/bin/awk '{ print $1 }')"
  helper_destination="$helper_parent/staged-helper"
  if tilde_stage_helper_bytes_by_fd \
      "$helper_source" "$helper_destination" "$helper_sha" \
      selftest-corrupt-copy >/dev/null 2>&1; then
    echo "selftest FAIL: helper copy differing from its approved digest was accepted" >&2
    return 1
  fi
  [[ ! -e "$helper_destination" && ! -L "$helper_destination" ]]
  [[ "$(/usr/bin/shasum -a 256 "$helper_source" | /usr/bin/awk '{ print $1 }')" \
      == "$helper_sha" ]]
  helper_identity="$(
    tilde_stage_helper_bytes_by_fd \
      "$helper_source" "$helper_destination" "$helper_sha"
  )"
  [[ "$helper_identity" == \
      "$(/usr/bin/stat -f '%d:%i' "$helper_destination")" ]]
  [[ "$(/usr/bin/stat -f '%Lp:%l' "$helper_destination")" == "500:1" ]]
  [[ "$(/usr/bin/shasum -a 256 "$helper_destination" | /usr/bin/awk '{ print $1 }')" \
      == "$helper_sha" ]]
  tilde_remove_exact_regular_file "$helper_destination" "$helper_identity"
  [[ ! -e "$helper_destination" ]]

  if tilde_stage_helper_bytes_by_fd \
      "$helper_source" "$helper_destination" \
      0000000000000000000000000000000000000000000000000000000000000000 \
      >/dev/null 2>&1; then
    echo "selftest FAIL: helper with wrong approved digest was accepted" >&2
    return 1
  fi
  [[ ! -e "$helper_destination" ]]
  /bin/ln -s "$helper_source" "$helper_parent/linked-helper"
  if tilde_stage_helper_bytes_by_fd \
      "$helper_parent/linked-helper" "$helper_destination" "$helper_sha" \
      >/dev/null 2>&1; then
    echo "selftest FAIL: linked helper input was accepted" >&2
    return 1
  fi
  /bin/cp "$helper_source" "$helper_parent/hard-helper"
  /bin/chmod 500 "$helper_parent/hard-helper"
  /bin/ln "$helper_parent/hard-helper" "$helper_parent/hard-helper-link"
  if tilde_stage_helper_bytes_by_fd \
      "$helper_parent/hard-helper" "$helper_destination" "$helper_sha" \
      >/dev/null 2>&1; then
    echo "selftest FAIL: hard-linked helper input was accepted" >&2
    return 1
  fi
  /bin/cp "$helper_source" "$helper_parent/writable-helper"
  /bin/chmod 720 "$helper_parent/writable-helper"
  if tilde_stage_helper_bytes_by_fd \
      "$helper_parent/writable-helper" "$helper_destination" "$helper_sha" \
      >/dev/null 2>&1; then
    echo "selftest FAIL: group-writable helper input was accepted" >&2
    return 1
  fi
  /bin/ln -s "$outside" "$helper_destination"
  if tilde_stage_helper_bytes_by_fd \
      "$helper_source" "$helper_destination" "$helper_sha" \
      >/dev/null 2>&1; then
    echo "selftest FAIL: preexisting helper destination was overwritten" >&2
    return 1
  fi
  [[ -L "$helper_destination" ]]
  /bin/unlink "$helper_destination"
  team="$(tilde_codesign_team_from_details $'Executable=helper\nTeamIdentifier=ABCDE12345')"
  [[ "$team" == "ABCDE12345" ]]
  if tilde_codesign_team_from_details \
      $'TeamIdentifier=ABCDE12345\nTeamIdentifier=FGHIJ67890' \
      >/dev/null 2>&1; then
    echo "selftest FAIL: ambiguous helper signing team was accepted" >&2
    return 1
  fi
  if tilde_stage_authenticated_helper \
      "$helper_source" "$helper_destination" "$helper_sha" ABCDE12345 \
      >/dev/null 2>&1; then
    echo "selftest FAIL: helper without the approved team was accepted" >&2
    return 1
  fi
  [[ ! -e "$helper_destination" ]]
  TILDE_HELPER_INPUT_SHA256="$helper_sha"
  TILDE_HELPER_APPROVED_TEAM=ABCDE12345
  export TILDE_HELPER_INPUT_SHA256 TILDE_HELPER_APPROVED_TEAM
  runner_fixture="$temporary/f03_preview_run.sh"
  printf '#!/bin/sh\nexit 0\n' >"$runner_fixture"
  /bin/chmod 700 "$runner_fixture"
  runner_fixture_sha="$(/usr/bin/shasum -a 256 "$runner_fixture" | /usr/bin/awk '{ print $1 }')"
  tilde_capture_f03_runner_identity "$runner_fixture"
  [[ "$TILDE_F03_RUNNER_SHA256" == "$runner_fixture_sha" ]]

  build_lock_root="$temporary/dist-lock"
  /bin/mkdir -m 700 "$build_lock_root"
  tilde_acquire_preview_build_lock "$build_lock_root"
  first_build_lock_identity="$TILDE_PREVIEW_BUILD_LOCK_IDENTITY"
  if (
    unset TILDE_PREVIEW_BUILD_LOCK_DIRECTORY TILDE_PREVIEW_BUILD_LOCK_IDENTITY
    tilde_acquire_preview_build_lock "$build_lock_root"
  ) >/dev/null 2>&1; then
    echo "selftest FAIL: concurrent preview dist assembly acquired the same lock" >&2
    return 1
  fi
  [[ "$TILDE_PREVIEW_BUILD_LOCK_IDENTITY" == "$first_build_lock_identity" ]]
  tilde_release_preview_build_lock
  tilde_acquire_preview_build_lock "$build_lock_root"
  tilde_release_preview_build_lock

  tilde_capture_apple_swift_toolchain
  toolchain_identity="$TILDE_APPLE_TOOLCHAIN_SHA256"
  swift_executable="$TILDE_SWIFT_EXECUTABLE"
  sdk_path="$TILDE_MACOS_SDK_PATH"
  fake_toolchain="$temporary/fake-toolchain"
  /bin/mkdir -m 700 "$fake_toolchain"
  printf '#!/bin/sh\nexit 99\n' >"$fake_toolchain/swift"
  /bin/chmod 700 "$fake_toolchain/swift"
  (
    export PATH="$fake_toolchain"
    export DEVELOPER_DIR="$fake_toolchain"
    export TOOLCHAINS=attacker.toolchain
    export SDKROOT="$fake_toolchain"
    export SWIFT_EXEC="$fake_toolchain/swift"
    export PYTHONPATH="$fake_toolchain"
    tilde_capture_apple_swift_toolchain
    [[ "$TILDE_APPLE_TOOLCHAIN_SHA256" == "$toolchain_identity" ]]
    [[ "$TILDE_SWIFT_EXECUTABLE" == "$swift_executable" ]]
    [[ "$TILDE_MACOS_SDK_PATH" == "$sdk_path" ]]
  )
  if tilde_validate_apple_toolchain_paths \
      "$fake_toolchain/Xcode.app/Contents/Developer" \
      "$fake_toolchain/swift" "$fake_toolchain/Fake.sdk" \
      >/dev/null 2>&1; then
    echo "selftest FAIL: writable-ancestor fake Apple toolchain was accepted" >&2
    return 1
  fi
  if tilde_validate_apple_toolchain_paths \
      "$TILDE_DEVELOPER_DIR" "$swift_executable" "$sdk_path" \
      "$fake_toolchain/swift" >/dev/null 2>&1; then
    echo "selftest FAIL: build tool outside the selected Xcode was accepted" >&2
    return 1
  fi
  tilde_prepare_build_source "$root" diagnostic
  tilde_capture_apple_swift_toolchain
  [[ -z "$TILDE_BUILD_SOURCE_TEMP" ]]
  tilde_swift --version >/dev/null 2>&1
  swift_build_help="$(tilde_swift build --help)"
  [[ "$swift_build_help" == *"USAGE: swift build"* ]]

  tilde_embed_build_provenance "$plist"
  tilde_verify_build_provenance "$plist"
  if /usr/libexec/PlistBuddy -c 'Print :TildeSwiftExecutable' "$plist" \
      >/dev/null 2>&1 \
      || /usr/libexec/PlistBuddy -c 'Print :TildeMacOSSDKPath' "$plist" \
        >/dev/null 2>&1 \
      || /usr/libexec/PlistBuddy -c 'Print :TildeHelperStagedIdentity' "$plist" \
        >/dev/null 2>&1; then
    echo "selftest FAIL: local build paths entered portable provenance" >&2
    return 1
  fi
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :TildeF03RunnerSHA256' "$plist")" \
      == "$runner_fixture_sha" ]]
  /usr/libexec/PlistBuddy -c 'Set :TildeXcodeBuild tampered' "$plist"
  if tilde_verify_build_provenance "$plist" >/dev/null 2>&1; then
    echo "selftest FAIL: changed build provenance was accepted" >&2
    return 1
  fi
  tilde_embed_build_provenance "$plist"
  TILDE_HELPER_APPROVED_TEAM=$'BAD\nTEAM'
  if tilde_embed_build_provenance "$plist" >/dev/null 2>&1; then
    echo "selftest FAIL: malformed build provenance was embedded" >&2
    return 1
  fi
  TILDE_HELPER_APPROVED_TEAM=ABCDE12345
  export TILDE_HELPER_APPROVED_TEAM
  tilde_verify_build_provenance "$plist"

  source_app="$temporary/Atomic Source.app"
  /bin/mkdir -p "$source_app/Contents/MacOS"
  /bin/chmod 755 "$source_app" "$source_app/Contents" "$source_app/Contents/MacOS"
  /bin/cp /usr/bin/true "$source_app/Contents/MacOS/Selftest"
  /bin/chmod 500 "$source_app/Contents/MacOS/Selftest"
  printf '%s\n' \
    '<?xml version="1.0" encoding="UTF-8"?>' \
    '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
    '<plist version="1.0"><dict>' \
    '<key>CFBundleExecutable</key><string>Selftest</string>' \
    '<key>CFBundleIdentifier</key><string>com.tilde.publish-selftest</string>' \
    '<key>CFBundlePackageType</key><string>APPL</string>' \
    '<key>CFBundleVersion</key><string>1</string>' \
    '</dict></plist>' >"$source_app/Contents/Info.plist"
  /usr/bin/codesign --force --sign - --timestamp=none "$source_app" >/dev/null
  publish_manifest="$(tilde_bundle_manifest_sha256 "$source_app")"
  publish_parent="$temporary/publish-parent"
  /bin/mkdir -m 700 "$publish_parent"
  publish_parent="$(cd "$publish_parent" && pwd -P)"
  /bin/chmod 700 "$source_app"
  restricted_manifest="$(tilde_bundle_manifest_sha256 "$source_app")"
  [[ "$restricted_manifest" != "$publish_manifest" ]]
  /bin/chmod 777 "$source_app"
  if tilde_bundle_manifest_sha256 "$source_app" >/dev/null 2>&1; then
    echo "selftest FAIL: writable bundle root entered the manifest" >&2
    return 1
  fi
  if tilde_bundle_directory_identity "$source_app" >/dev/null 2>&1; then
    echo "selftest FAIL: writable bundle root received a publish identity" >&2
    return 1
  fi
  unsafe_root_destination="$publish_parent/Unsafe Root.app"
  if tilde_publish_new_bundle \
      "$source_app" "$unsafe_root_destination" "$publish_manifest" \
      >/dev/null 2>&1; then
    echo "selftest FAIL: publisher accepted a writable bundle root" >&2
    return 1
  fi
  [[ ! -e "$unsafe_root_destination" && ! -L "$unsafe_root_destination" ]]
  /bin/chmod 755 "$source_app"
  [[ "$(tilde_bundle_manifest_sha256 "$source_app")" == "$publish_manifest" ]]
  publish_destination="$publish_parent/Published.app"
  published_identity="$(
    tilde_publish_new_bundle \
      "$source_app" "$publish_destination" "$publish_manifest"
  )"
  [[ "$published_identity" == \
      "$(tilde_bundle_directory_identity "$publish_destination")" ]]
  [[ "$(tilde_bundle_manifest_sha256 "$publish_destination")" == \
      "$publish_manifest" ]]
  if tilde_publish_new_bundle \
      "$source_app" "$publish_destination" "$publish_manifest" \
      >/dev/null 2>&1; then
    echo "selftest FAIL: atomic publisher overwrote an existing bundle" >&2
    return 1
  fi
  [[ "$(tilde_bundle_directory_identity "$publish_destination")" == \
      "$published_identity" ]]
  /bin/mkdir "$publish_parent/symlink-target"
  printf 'sentinel\n' >"$publish_parent/symlink-target/sentinel.txt"
  /bin/ln -s "$publish_parent/symlink-target" "$publish_parent/Symlink.app"
  if tilde_publish_new_bundle \
      "$source_app" "$publish_parent/Symlink.app" "$publish_manifest" \
      >/dev/null 2>&1; then
    echo "selftest FAIL: atomic publisher followed a destination symlink" >&2
    return 1
  fi
  [[ -L "$publish_parent/Symlink.app" ]]
  [[ "$(<"$publish_parent/symlink-target/sentinel.txt")" == "sentinel" ]]

  quarantine_transaction="$publish_parent/.tilde-publish.selftest"
  /bin/mkdir -m 700 "$quarantine_transaction"
  quarantine_bundle="$publish_parent/Quarantine.app"
  /usr/bin/ditto "$source_app" "$quarantine_bundle"
  quarantine_identity="$(tilde_bundle_directory_identity "$quarantine_bundle")"
  tilde_quarantine_published_bundle \
    "$publish_parent" "${quarantine_transaction##*/}" \
    "${quarantine_bundle##*/}" "$quarantine_identity"
  [[ ! -e "$quarantine_bundle" ]]
  [[ -d "$quarantine_transaction/${quarantine_bundle##*/}" ]]
  tilde_remove_private_publish_tree "$quarantine_transaction"

  quarantine_transaction="$publish_parent/.tilde-publish.replaced-selftest"
  /bin/mkdir -m 700 "$quarantine_transaction"
  quarantine_bundle="$publish_parent/Replaced.app"
  /usr/bin/ditto "$source_app" "$quarantine_bundle"
  quarantine_identity="$(tilde_bundle_directory_identity "$quarantine_bundle")"
  /bin/mv "$quarantine_bundle" "$publish_parent/original-replaced-bundle"
  /bin/mkdir "$quarantine_bundle"
  if tilde_quarantine_published_bundle \
      "$publish_parent" "${quarantine_transaction##*/}" \
      "${quarantine_bundle##*/}" "$quarantine_identity" \
      >/dev/null 2>&1; then
    echo "selftest FAIL: quarantine moved a path-replaced bundle" >&2
    return 1
  fi
  [[ -d "$quarantine_bundle" ]]

  for invalid_version in \
      '' '1' '0.1.0 preview' '0.1.0-</string>' $'0.1.0\nsecond-line'; do
    if tilde_validate_preview_version "$invalid_version" >/dev/null 2>&1; then
      echo "selftest FAIL: unsafe preview version was accepted" >&2
      return 1
    fi
  done
  long_version="0.1.0-$(printf '%070d' 0)"
  if tilde_validate_preview_version "$long_version" >/dev/null 2>&1; then
    echo "selftest FAIL: oversized preview version was accepted" >&2
    return 1
  fi
  tilde_validate_preview_version 0.1.0-preview9b
  tilde_validate_preview_version 0.1.0-preview26b
  tilde_validate_preview_version 0.1.0-model-preview

  echo "selftest OK: raw source, model, helper, toolchain, and atomic publish fail closed"
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-}" in
    --selftest) tilde_source_provenance_selftest ;;
    *) echo "usage: $0 --selftest" >&2; exit 2 ;;
  esac
fi
