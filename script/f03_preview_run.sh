#!/usr/bin/env bash
# Owner-approved, recoverable Preview9B install + F03 ledger rotation.
# This is called only by build_preview_9b.sh's explicit F03 run mode.
set -euo pipefail
PATH="/usr/bin:/bin:/usr/sbin:/sbin"
export PATH
umask 077

bootstrap_python_isolated() {
  /usr/bin/env -i \
    HOME=/var/empty \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin \
    LC_ALL=C \
    /usr/bin/python3 -I -S "$@"
}

bootstrap_git_raw() {
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

bootstrap_verify_file() {
  local path="$1" expected_sha="$2" sealed="$3"
  bootstrap_python_isolated - "$path" "$expected_sha" "$sealed" <<'PY'
import hashlib
import os
import stat
import sys

path, expected_sha, sealed = sys.argv[1:]
if (
    not os.path.isabs(path)
    or len(expected_sha) != 64
    or any(character not in "0123456789abcdef" for character in expected_sha)
    or sealed not in {"0", "1", "2"}
):
    raise SystemExit("invalid F03 policy-file identity")
if sealed == "1" and not os.path.dirname(path).startswith(
    "/private/tmp/tilde-f03-runner."
):
    raise SystemExit("sealed F03 policy file is outside its private directory")
descriptor = os.open(
    path,
    os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW | os.O_CLOEXEC,
)
try:
    info = os.fstat(descriptor)
    visible = os.stat(path, follow_symlinks=False)
    required_mode = 0o400 if sealed != "0" else None
    if (
        not stat.S_ISREG(info.st_mode)
        or not stat.S_ISREG(visible.st_mode)
        or info.st_uid != os.getuid()
        or visible.st_uid != os.getuid()
        or info.st_nlink != 1
        or visible.st_nlink != 1
        or stat.S_IMODE(info.st_mode) & 0o022
        or (required_mode is not None and stat.S_IMODE(info.st_mode) != required_mode)
        or (info.st_dev, info.st_ino) != (visible.st_dev, visible.st_ino)
        or info.st_size <= 0
        or info.st_size > 2 * 1024 * 1024
    ):
        raise RuntimeError("unsafe F03 policy-file identity")
    digest = hashlib.sha256()
    size = 0
    while chunk := os.read(descriptor, 1024 * 1024):
        digest.update(chunk)
        size += len(chunk)
    final = os.fstat(descriptor)
    final_visible = os.stat(path, follow_symlinks=False)
    if (
        digest.hexdigest() != expected_sha
        or size != info.st_size
        or (info.st_dev, info.st_ino, info.st_size, info.st_nlink)
            != (final.st_dev, final.st_ino, final.st_size, final.st_nlink)
        or (info.st_dev, info.st_ino)
            != (final_visible.st_dev, final_visible.st_ino)
    ):
        raise RuntimeError("F03 policy file changed while verified")
finally:
    os.close(descriptor)
PY
}

if [[ -n "${TILDE_F03_SEALED_RUNNER_SHA:-}" ]]; then
  [[ -n "${TILDE_F03_REPO_ROOT:-}" ]] \
    || { echo "sealed F03 runner is missing its repository root" >&2; exit 1; }
  ROOT_DIR="$(cd "$TILDE_F03_REPO_ROOT" && pwd -P)"
else
  ROOT_DIR="$(cd "$(/usr/bin/dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fi
SCRIPT_PATH="$(cd "$(/usr/bin/dirname "${BASH_SOURCE[0]}")" && pwd -P)/$(/usr/bin/basename "${BASH_SOURCE[0]}")"
ORIGINAL_ARGUMENTS=("$@")
SOURCE_PROVENANCE_PATH=""
SOURCE_PROVENANCE_SHA256=""
if [[ -n "${TILDE_F03_SEALED_RUNNER_SHA:-}" ]]; then
  SOURCE_PROVENANCE_PATH="${TILDE_F03_SEALED_PROVENANCE_PATH:-}"
  SOURCE_PROVENANCE_SHA256="${TILDE_F03_SEALED_PROVENANCE_SHA:-}"
  [[ -n "$SOURCE_PROVENANCE_PATH" && -n "$SOURCE_PROVENANCE_SHA256" \
      && "$(/usr/bin/dirname "$SOURCE_PROVENANCE_PATH")" == \
        "$(/usr/bin/dirname "$SCRIPT_PATH")" ]] \
    || { echo "sealed F03 runner is missing its sealed provenance policy" >&2; exit 1; }
  bootstrap_verify_file "$SOURCE_PROVENANCE_PATH" "$SOURCE_PROVENANCE_SHA256" 1
  source "$SOURCE_PROVENANCE_PATH"
else
  SELFTEST_ONLY_BOOTSTRAP=0
  for argument in "${ORIGINAL_ARGUMENTS[@]}"; do
    case "$argument" in
      --selftest|--selftest-write-receipt) SELFTEST_ONLY_BOOTSTRAP=1 ;;
    esac
  done
  if [[ "$SELFTEST_ONLY_BOOTSTRAP" == "1" ]]; then
    SOURCE_PROVENANCE_PATH="$ROOT_DIR/script/source_provenance.sh"
    SOURCE_PROVENANCE_SHA256="$(/usr/bin/shasum -a 256 "$SOURCE_PROVENANCE_PATH" \
      | /usr/bin/awk '{ print $1 }')"
    bootstrap_verify_file "$SOURCE_PROVENANCE_PATH" "$SOURCE_PROVENANCE_SHA256" 0
    source "$SOURCE_PROVENANCE_PATH"
  else
    BOOTSTRAP_COMMIT="$(bootstrap_git_raw "$ROOT_DIR" rev-parse --verify 'HEAD^{commit}')"
    BOOTSTRAP_DIRECTORY="$(/usr/bin/mktemp -d /private/tmp/tilde-f03-policy.XXXXXX)"
    /bin/chmod 700 "$BOOTSTRAP_DIRECTORY"
    SOURCE_PROVENANCE_PATH="$BOOTSTRAP_DIRECTORY/source_provenance.sh"
    set -o noclobber
    if ! bootstrap_git_raw "$ROOT_DIR" show \
        "$BOOTSTRAP_COMMIT:script/source_provenance.sh" >"$SOURCE_PROVENANCE_PATH"; then
      set +o noclobber
      /bin/rm -f -- "$SOURCE_PROVENANCE_PATH"
      /bin/rmdir "$BOOTSTRAP_DIRECTORY"
      echo "F03 requires a committed source-provenance policy" >&2
      exit 1
    fi
    set +o noclobber
    /bin/chmod 400 "$SOURCE_PROVENANCE_PATH"
    SOURCE_PROVENANCE_SHA256="$(/usr/bin/shasum -a 256 "$SOURCE_PROVENANCE_PATH" \
      | /usr/bin/awk '{ print $1 }')"
    bootstrap_verify_file "$SOURCE_PROVENANCE_PATH" "$SOURCE_PROVENANCE_SHA256" 2 \
      2>/dev/null || {
        /bin/rm -f -- "$SOURCE_PROVENANCE_PATH"
        /bin/rmdir "$BOOTSTRAP_DIRECTORY"
        echo "committed F03 source-provenance policy failed verification" >&2
        exit 1
      }
    source "$SOURCE_PROVENANCE_PATH"
    /bin/rm -- "$SOURCE_PROVENANCE_PATH"
    /bin/rmdir "$BOOTSTRAP_DIRECTORY"
    SOURCE_PROVENANCE_PATH=""
  fi
fi
CANDIDATE=""
PREVIOUS_LEDGER=""
OWNER_APPROVED=0
SELFTEST=0
SELFTEST_RECEIPT_OUTPUT=""
DEFAULTS_COMMAND="/usr/bin/defaults"
ROTATION_TEST_READY=""
ROTATION_TEST_CONTINUE=""
RECEIPT_TEST_READY=""
RECEIPT_TEST_CONTINUE=""
BUNDLE_MOVE_TEST_READY=""
BUNDLE_MOVE_TEST_CONTINUE=""

usage() {
  /bin/cat <<'EOF'
Usage: script/f03_preview_run.sh --candidate APP --owner-approved \
  --previous-ledger archive|delete
       script/f03_preview_run.sh --selftest
       script/f03_preview_run.sh --selftest-write-receipt ABS_PATH

Performs one guarded F03 maintenance transaction for Tilde 9B Preview:
verifies a clean decision-grade app+IME lineage, replaces the preview app,
lets that app atomically update its IME, stops the exact preview processes,
rotates only the text-free events.jsonl, starts the exact packaged runtime,
and atomically writes a local aggregate-only run receipt.

This command changes the installed preview and local Outcome Ledger. Run it
only in an owner-approved maintenance window. `archive` preserves the previous
text-free event file beside the local receipt; `delete` removes it only after
the new app, IME, helper, rotation, and receipt all succeed. It never touches
the local word diary.

--selftest-write-receipt writes one synthetic contract fixture only beneath an
owner-only test temporary directory. It never inspects or mutates installed
apps, processes, defaults, model storage, or Outcome Ledger data.
EOF
}

while (($#)); do
  case "$1" in
    --candidate|--previous-ledger|--selftest-write-receipt)
      [[ $# -ge 2 ]] || { echo "missing value for $1" >&2; exit 2; }
      case "$1" in
        --candidate) CANDIDATE="$2" ;;
        --previous-ledger) PREVIOUS_LEDGER="$2" ;;
        --selftest-write-receipt) SELFTEST_RECEIPT_OUTPUT="$2" ;;
      esac
      shift
      ;;
    --owner-approved) OWNER_APPROVED=1 ;;
    --selftest) SELFTEST=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$2"
}

sha256() {
  /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{ print $1 }'
}

assert_sealed_runner_identity() {
  local runner="$1" expected_sha="$2"
  tilde_python_isolated - "$runner" "$expected_sha" <<'PY'
import fcntl
import hashlib
import os
import stat
import sys

runner, expected_sha = sys.argv[1:]
directory_path = os.path.dirname(runner)
if (
    not os.path.isabs(runner)
    or not directory_path.startswith("/private/tmp/tilde-f03-runner.")
    or len(expected_sha) != 64
    or any(character not in "0123456789abcdef" for character in expected_sha)
):
    raise SystemExit("invalid sealed F03 runner identity")
directory = os.open(
    directory_path,
    os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC,
)
descriptor = None
try:
    directory_info = os.fstat(directory)
    path_directory_info = os.stat(directory_path, follow_symlinks=False)
    if (
        not stat.S_ISDIR(directory_info.st_mode)
        or not stat.S_ISDIR(path_directory_info.st_mode)
        or directory_info.st_uid != os.getuid()
        or path_directory_info.st_uid != os.getuid()
        or directory_info.st_nlink < 1
        or path_directory_info.st_nlink < 1
        or stat.S_IMODE(directory_info.st_mode) != 0o700
        or stat.S_IMODE(path_directory_info.st_mode) != 0o700
        or (directory_info.st_dev, directory_info.st_ino)
            != (path_directory_info.st_dev, path_directory_info.st_ino)
    ):
        raise RuntimeError("refusing unsafe sealed F03 runner directory")
    descriptor = os.open(
        os.path.basename(runner),
        os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW | os.O_CLOEXEC,
        dir_fd=directory,
    )
    info = os.fstat(descriptor)
    path_info = os.stat(
        os.path.basename(runner), dir_fd=directory, follow_symlinks=False
    )
    if (
        not stat.S_ISREG(info.st_mode)
        or not stat.S_ISREG(path_info.st_mode)
        or info.st_uid != os.getuid()
        or path_info.st_uid != os.getuid()
        or info.st_nlink != 1
        or path_info.st_nlink != 1
        or stat.S_IMODE(info.st_mode) != 0o400
        or stat.S_IMODE(path_info.st_mode) != 0o400
        or info.st_size <= 0
        or info.st_size > 2 * 1024 * 1024
        or (info.st_dev, info.st_ino) != (path_info.st_dev, path_info.st_ino)
    ):
        raise RuntimeError("refusing unsafe sealed F03 runner file")
    flags = fcntl.fcntl(descriptor, fcntl.F_GETFL)
    fcntl.fcntl(descriptor, fcntl.F_SETFL, flags & ~os.O_NONBLOCK)
    digest = hashlib.sha256()
    size = 0
    while chunk := os.read(descriptor, 1024 * 1024):
        digest.update(chunk)
        size += len(chunk)
    final_info = os.fstat(descriptor)
    final_path_info = os.stat(
        os.path.basename(runner), dir_fd=directory, follow_symlinks=False
    )
    if (
        digest.hexdigest() != expected_sha
        or size != info.st_size
        or (info.st_dev, info.st_ino, info.st_size, info.st_nlink)
            != (
                final_info.st_dev,
                final_info.st_ino,
                final_info.st_size,
                final_info.st_nlink,
            )
        or (info.st_dev, info.st_ino)
            != (final_path_info.st_dev, final_path_info.st_ino)
        or final_path_info.st_nlink != 1
        or stat.S_IMODE(final_path_info.st_mode) != 0o400
    ):
        raise RuntimeError("sealed F03 runner changed while it was verified")
finally:
    if descriptor is not None:
        os.close(descriptor)
    os.close(directory)
PY
}

seal_and_reexec_runner() {
  local source_commit="$1" expected_sha="$2" expected_provenance_sha="$3"
  local materialized_directory materialized_runner materialized_provenance
  if [[ -n "${TILDE_F03_SEALED_RUNNER_SHA:-}" ]]; then
    [[ "$TILDE_F03_SEALED_RUNNER_SHA" == "$expected_sha" \
        && "${TILDE_F03_SEALED_PROVENANCE_SHA:-}" == "$expected_provenance_sha" \
        && "${TILDE_F03_REPO_ROOT:-}" == "$ROOT_DIR" ]] \
      || { echo "sealed F03 runner environment does not match candidate lineage" >&2; return 1; }
    assert_sealed_runner_identity "$SCRIPT_PATH" "$expected_sha"
    assert_sealed_runner_identity "$SOURCE_PROVENANCE_PATH" "$expected_provenance_sha"
    return 0
  fi

  materialized_directory="$(/usr/bin/mktemp -d /private/tmp/tilde-f03-committed-runner.XXXXXX)"
  /bin/chmod 700 "$materialized_directory"
  materialized_runner="$materialized_directory/f03_preview_run.sh"
  materialized_provenance="$materialized_directory/source_provenance.sh"
  set -o noclobber
  if ! tilde_git_raw "$ROOT_DIR" show \
      "$source_commit:script/f03_preview_run.sh" >"$materialized_runner"; then
    set +o noclobber
    /bin/rm -f -- "$materialized_runner"
    /bin/rmdir "$materialized_directory"
    return 1
  fi
  if ! tilde_git_raw "$ROOT_DIR" show \
      "$source_commit:script/source_provenance.sh" >"$materialized_provenance"; then
    set +o noclobber
    /bin/rm -f -- "$materialized_runner" "$materialized_provenance"
    /bin/rmdir "$materialized_directory"
    return 1
  fi
  set +o noclobber
  /bin/chmod 400 "$materialized_runner" "$materialized_provenance"

  exec /usr/bin/env -i \
    HOME=/var/empty PATH=/usr/bin:/bin:/usr/sbin:/sbin LC_ALL=C \
    /usr/bin/python3 -I -S - \
    "$ROOT_DIR" "$source_commit" "$materialized_runner" "$materialized_provenance" \
    "$SCRIPT_PATH" "$expected_sha" "$expected_provenance_sha" \
    "${ORIGINAL_ARGUMENTS[@]}" <<'PY'
import hashlib
import os
import stat
import sys
import tempfile

(
    root,
    source_commit,
    materialized_runner,
    materialized_provenance,
    current_runner,
    expected_sha,
    expected_provenance_sha,
    *arguments,
) = sys.argv[1:]
if (
    len(source_commit) != 40
    or any(character not in "0123456789abcdef" for character in source_commit)
    or len(expected_sha) != 64
    or any(character not in "0123456789abcdef" for character in expected_sha)
    or len(expected_provenance_sha) != 64
    or any(
        character not in "0123456789abcdef"
        for character in expected_provenance_sha
    )
):
    raise SystemExit("invalid F03 runner commit identity")

materialized_directory_path = os.path.dirname(materialized_runner)
if not materialized_directory_path.startswith(
    "/private/tmp/tilde-f03-committed-runner."
):
    raise SystemExit("invalid committed-runner materialization path")
materialized_directory = os.open(
    materialized_directory_path,
    os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC,
)
materialized_descriptor = None
materialized_provenance_descriptor = None

def read_bounded(descriptor: int, maximum: int) -> bytes:
    chunks = []
    size = 0
    while True:
        chunk = os.read(descriptor, min(1024 * 1024, maximum + 1 - size))
        if not chunk:
            return b"".join(chunks)
        chunks.append(chunk)
        size += len(chunk)
        if size > maximum:
            raise RuntimeError("F03 runner exceeded its bounded size")

try:
    directory_info = os.fstat(materialized_directory)
    directory_path_info = os.stat(
        materialized_directory_path, follow_symlinks=False
    )
    if (
        not stat.S_ISDIR(directory_info.st_mode)
        or directory_info.st_uid != os.getuid()
        or stat.S_IMODE(directory_info.st_mode) != 0o700
        or (directory_info.st_dev, directory_info.st_ino)
            != (directory_path_info.st_dev, directory_path_info.st_ino)
    ):
        raise RuntimeError("unsafe committed-runner materialization directory")
    materialized_descriptor = os.open(
        os.path.basename(materialized_runner),
        os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW | os.O_CLOEXEC,
        dir_fd=materialized_directory,
    )
    materialized_info = os.fstat(materialized_descriptor)
    materialized_path_info = os.stat(
        os.path.basename(materialized_runner),
        dir_fd=materialized_directory,
        follow_symlinks=False,
    )
    if (
        not stat.S_ISREG(materialized_info.st_mode)
        or materialized_info.st_uid != os.getuid()
        or materialized_info.st_nlink != 1
        or stat.S_IMODE(materialized_info.st_mode) != 0o400
        or materialized_info.st_size <= 0
        or materialized_info.st_size > 2 * 1024 * 1024
        or (materialized_info.st_dev, materialized_info.st_ino)
            != (materialized_path_info.st_dev, materialized_path_info.st_ino)
    ):
        raise RuntimeError("unsafe committed-runner materialization file")
    committed = read_bounded(materialized_descriptor, 2 * 1024 * 1024)
    if len(committed) != materialized_info.st_size:
        raise RuntimeError("committed-runner materialization changed while read")
    materialized_provenance_descriptor = os.open(
        os.path.basename(materialized_provenance),
        os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW | os.O_CLOEXEC,
        dir_fd=materialized_directory,
    )
    provenance_info = os.fstat(materialized_provenance_descriptor)
    provenance_path_info = os.stat(
        os.path.basename(materialized_provenance),
        dir_fd=materialized_directory,
        follow_symlinks=False,
    )
    if (
        not stat.S_ISREG(provenance_info.st_mode)
        or provenance_info.st_uid != os.getuid()
        or provenance_info.st_nlink != 1
        or stat.S_IMODE(provenance_info.st_mode) != 0o400
        or provenance_info.st_size <= 0
        or provenance_info.st_size > 2 * 1024 * 1024
        or (provenance_info.st_dev, provenance_info.st_ino)
            != (provenance_path_info.st_dev, provenance_path_info.st_ino)
    ):
        raise RuntimeError("unsafe committed-provenance materialization file")
    committed_provenance = read_bounded(
        materialized_provenance_descriptor, 2 * 1024 * 1024
    )
    if len(committed_provenance) != provenance_info.st_size:
        raise RuntimeError("committed-provenance materialization changed while read")
finally:
    if materialized_descriptor is not None:
        os.close(materialized_descriptor)
    if materialized_provenance_descriptor is not None:
        os.close(materialized_provenance_descriptor)
    try:
        for path in (materialized_runner, materialized_provenance):
            os.unlink(os.path.basename(path), dir_fd=materialized_directory)
        os.fsync(materialized_directory)
    finally:
        os.close(materialized_directory)
        os.rmdir(materialized_directory_path)

current_descriptor = os.open(
    current_runner,
    os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW | os.O_CLOEXEC,
)
try:
    current_info = os.fstat(current_descriptor)
    current_path_info = os.stat(current_runner, follow_symlinks=False)
    if (
        not stat.S_ISREG(current_info.st_mode)
        or current_info.st_uid != os.getuid()
        or current_info.st_nlink != 1
        or current_info.st_size <= 0
        or current_info.st_size > 2 * 1024 * 1024
        or (current_info.st_dev, current_info.st_ino)
            != (current_path_info.st_dev, current_path_info.st_ino)
    ):
        raise RuntimeError("live F03 runner identity is unsafe")
    current = read_bounded(current_descriptor, 2 * 1024 * 1024)
    current_final = os.fstat(current_descriptor)
    current_final_path = os.stat(current_runner, follow_symlinks=False)
    if (
        (current_info.st_dev, current_info.st_ino, current_info.st_size)
        != (current_final.st_dev, current_final.st_ino, current_final.st_size)
        or (current_info.st_dev, current_info.st_ino)
            != (current_final_path.st_dev, current_final_path.st_ino)
    ):
        raise RuntimeError("live F03 runner changed while read")
finally:
    os.close(current_descriptor)
if (
    len(current) > 2 * 1024 * 1024
    or hashlib.sha256(committed).hexdigest() != expected_sha
    or hashlib.sha256(committed_provenance).hexdigest()
        != expected_provenance_sha
    or hashlib.sha256(current).hexdigest() != expected_sha
    or current != committed
):
    raise SystemExit(
        "live F03 runner or provenance policy does not match the candidate source commit"
    )

directory_path = tempfile.mkdtemp(prefix="tilde-f03-runner.", dir="/private/tmp")
os.chmod(directory_path, 0o700)
runner_path = os.path.join(directory_path, "f03_preview_run.sh")
provenance_path = os.path.join(directory_path, "source_provenance.sh")
directory = os.open(
    directory_path,
    os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC,
)
descriptor = None
provenance_descriptor = None
try:
    descriptor = os.open(
        "f03_preview_run.sh",
        os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC,
        0o400,
        dir_fd=directory,
    )
    view = memoryview(committed)
    while view:
        view = view[os.write(descriptor, view):]
    os.fsync(descriptor)
    info = os.fstat(descriptor)
    path_info = os.stat(
        "f03_preview_run.sh", dir_fd=directory, follow_symlinks=False
    )
    if (
        not stat.S_ISREG(info.st_mode)
        or info.st_uid != os.getuid()
        or info.st_nlink != 1
        or stat.S_IMODE(info.st_mode) != 0o400
        or info.st_size != len(committed)
        or (info.st_dev, info.st_ino) != (path_info.st_dev, path_info.st_ino)
    ):
        raise RuntimeError("sealed F03 runner publication failed")
    provenance_descriptor = os.open(
        "source_provenance.sh",
        os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC,
        0o400,
        dir_fd=directory,
    )
    view = memoryview(committed_provenance)
    while view:
        view = view[os.write(provenance_descriptor, view):]
    os.fsync(provenance_descriptor)
    provenance_published_info = os.fstat(provenance_descriptor)
    provenance_visible_info = os.stat(
        "source_provenance.sh", dir_fd=directory, follow_symlinks=False
    )
    if (
        not stat.S_ISREG(provenance_published_info.st_mode)
        or provenance_published_info.st_uid != os.getuid()
        or provenance_published_info.st_nlink != 1
        or stat.S_IMODE(provenance_published_info.st_mode) != 0o400
        or provenance_published_info.st_size != len(committed_provenance)
        or (provenance_published_info.st_dev, provenance_published_info.st_ino)
            != (provenance_visible_info.st_dev, provenance_visible_info.st_ino)
    ):
        raise RuntimeError("sealed F03 provenance-policy publication failed")
    os.fsync(directory)
    environment = {
        "HOME": "/var/empty",
        "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
        "LC_ALL": "C",
    }
    environment["TILDE_F03_SEALED_RUNNER_SHA"] = expected_sha
    environment["TILDE_F03_SEALED_PROVENANCE_PATH"] = provenance_path
    environment["TILDE_F03_SEALED_PROVENANCE_SHA"] = expected_provenance_sha
    environment["TILDE_F03_REPO_ROOT"] = root
    os.execve("/bin/bash", ["/bin/bash", runner_path, *arguments], environment)
finally:
    if descriptor is not None:
        os.close(descriptor)
    if provenance_descriptor is not None:
        os.close(provenance_descriptor)
    os.close(directory)
    for path in (runner_path, provenance_path):
        try:
            os.unlink(path)
        except FileNotFoundError:
            pass
    try:
        os.rmdir(directory_path)
    except FileNotFoundError:
        pass
PY
}

cleanup_sealed_runner() {
  [[ -n "${TILDE_F03_SEALED_RUNNER_SHA:-}" ]] || return 0
  tilde_python_isolated - \
    "$SCRIPT_PATH" "$TILDE_F03_SEALED_RUNNER_SHA" \
    "$SOURCE_PROVENANCE_PATH" "$TILDE_F03_SEALED_PROVENANCE_SHA" <<'PY'
import fcntl
import hashlib
import os
import stat
import sys

runner, expected_runner_sha, provenance, expected_provenance_sha = sys.argv[1:]
directory_path = os.path.dirname(runner)
if os.path.dirname(provenance) != directory_path:
    raise RuntimeError("sealed runner and provenance policy are not co-located")
directory = os.open(
    directory_path,
    os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC,
)
descriptors = []
try:
    directory_info = os.fstat(directory)
    directory_visible = os.stat(directory_path, follow_symlinks=False)
    if (
        not stat.S_ISDIR(directory_info.st_mode)
        or not stat.S_ISDIR(directory_visible.st_mode)
        or directory_info.st_uid != os.getuid()
        or directory_visible.st_uid != os.getuid()
        or stat.S_IMODE(directory_info.st_mode) != 0o700
        or stat.S_IMODE(directory_visible.st_mode) != 0o700
        or (directory_info.st_dev, directory_info.st_ino)
            != (directory_visible.st_dev, directory_visible.st_ino)
        or not directory_path.startswith("/private/tmp/tilde-f03-runner.")
    ):
        raise RuntimeError("refusing unsafe sealed-runner cleanup directory")
    for path, expected_sha in (
        (runner, expected_runner_sha),
        (provenance, expected_provenance_sha),
    ):
        descriptor = os.open(
            os.path.basename(path),
            os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW | os.O_CLOEXEC,
            dir_fd=directory,
        )
        descriptors.append(descriptor)
        info = os.fstat(descriptor)
        current_flags = fcntl.fcntl(descriptor, fcntl.F_GETFL)
        fcntl.fcntl(descriptor, fcntl.F_SETFL, current_flags & ~os.O_NONBLOCK)
        digest = hashlib.sha256()
        size = 0
        while chunk := os.read(descriptor, 1024 * 1024):
            digest.update(chunk)
            size += len(chunk)
        final = os.fstat(descriptor)
        path_info = os.stat(
            os.path.basename(path), dir_fd=directory, follow_symlinks=False
        )
        if (
            not stat.S_ISREG(info.st_mode)
            or info.st_uid != os.getuid()
            or info.st_nlink != 1
            or stat.S_IMODE(info.st_mode) != 0o400
            or info.st_size <= 0
            or info.st_size > 2 * 1024 * 1024
            or digest.hexdigest() != expected_sha
            or size != info.st_size
            or (info.st_dev, info.st_ino, info.st_size, info.st_nlink)
                != (final.st_dev, final.st_ino, final.st_size, final.st_nlink)
            or (info.st_dev, info.st_ino)
                != (path_info.st_dev, path_info.st_ino)
        ):
            raise RuntimeError("refusing unsafe sealed cleanup identity")
    for path in (runner, provenance):
        os.unlink(os.path.basename(path), dir_fd=directory)
    os.fsync(directory)
finally:
    for descriptor in descriptors:
        os.close(descriptor)
    os.close(directory)
os.rmdir(directory_path)
PY
}

process_executable() {
  /usr/sbin/lsof -nP -a -p "$1" -d txt -Fn 2>/dev/null \
    | /usr/bin/awk '/^n/ { sub(/^n/, ""); print; exit }' || true
}

same_file_identity() {
  [[ -n "$1" && -n "$2" && -e "$1" && -e "$2" && "$1" -ef "$2" ]]
}

ensure_maintenance_lock() {
  local directory="$1" filename="$2"
  local inherited_fd="${TILDE_F03_MAINTENANCE_LOCK_FD:-}"
  local inherited_path="${TILDE_F03_MAINTENANCE_LOCK_PATH:-}"
  local expected_path="$directory/$filename"

  if [[ -n "$inherited_fd" || -n "$inherited_path" ]]; then
    [[ "$inherited_fd" =~ ^[0-9]+$ && "$inherited_path" == "$expected_path" ]] \
      || { echo "refusing invalid inherited F03 maintenance lock" >&2; return 1; }
    tilde_python_isolated - "$directory" "$filename" "$inherited_fd" <<'PY'
import fcntl
import os
import stat
import sys

directory_path, filename, descriptor_text = sys.argv[1:]
descriptor = int(descriptor_text)
directory = os.open(directory_path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
try:
    directory_info = os.fstat(directory)
    path_directory_info = os.stat(directory_path, follow_symlinks=False)
    file_info = os.fstat(descriptor)
    path_file_info = os.stat(filename, dir_fd=directory, follow_symlinks=False)
    if (
        not stat.S_ISDIR(directory_info.st_mode)
        or not stat.S_ISDIR(path_directory_info.st_mode)
        or directory_info.st_uid != os.getuid()
        or path_directory_info.st_uid != os.getuid()
        or stat.S_IMODE(directory_info.st_mode) != 0o700
        or stat.S_IMODE(path_directory_info.st_mode) != 0o700
        or (directory_info.st_dev, directory_info.st_ino)
            != (path_directory_info.st_dev, path_directory_info.st_ino)
        or not stat.S_ISREG(file_info.st_mode)
        or not stat.S_ISREG(path_file_info.st_mode)
        or file_info.st_uid != os.getuid()
        or path_file_info.st_uid != os.getuid()
        or file_info.st_nlink != 1
        or path_file_info.st_nlink != 1
        or stat.S_IMODE(file_info.st_mode) != 0o600
        or stat.S_IMODE(path_file_info.st_mode) != 0o600
        or (file_info.st_dev, file_info.st_ino)
            != (path_file_info.st_dev, path_file_info.st_ino)
    ):
        raise SystemExit("refusing unsafe inherited F03 maintenance lock identity")
    fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
finally:
    os.close(directory)
PY
    return
  fi

  # Replace this shell with a lock-owning Python process, which immediately
  # re-execs this exact script with the locked descriptor inherited. The same
  # open file description then survives through transaction rollback and exit.
  exec /usr/bin/env -i \
    HOME=/var/empty PATH=/usr/bin:/bin:/usr/sbin:/sbin LC_ALL=C \
    TILDE_F03_SEALED_RUNNER_SHA="${TILDE_F03_SEALED_RUNNER_SHA:-}" \
    TILDE_F03_SEALED_PROVENANCE_PATH="${TILDE_F03_SEALED_PROVENANCE_PATH:-}" \
    TILDE_F03_SEALED_PROVENANCE_SHA="${TILDE_F03_SEALED_PROVENANCE_SHA:-}" \
    TILDE_F03_REPO_ROOT="${TILDE_F03_REPO_ROOT:-}" \
    /usr/bin/python3 -I -S - "$directory" "$filename" "$SCRIPT_PATH" \
    "${ORIGINAL_ARGUMENTS[@]}" <<'PY'
import fcntl
import os
import stat
import sys

directory_path, filename, script, *arguments = sys.argv[1:]
directory = os.open(directory_path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
descriptor = None
try:
    directory_info = os.fstat(directory)
    path_directory_info = os.stat(directory_path, follow_symlinks=False)
    if (
        not stat.S_ISDIR(directory_info.st_mode)
        or not stat.S_ISDIR(path_directory_info.st_mode)
        or directory_info.st_uid != os.getuid()
        or path_directory_info.st_uid != os.getuid()
        or stat.S_IMODE(directory_info.st_mode) != 0o700
        or stat.S_IMODE(path_directory_info.st_mode) != 0o700
        or (directory_info.st_dev, directory_info.st_ino)
            != (path_directory_info.st_dev, path_directory_info.st_ino)
    ):
        raise SystemExit("refusing unsafe F03 maintenance-lock directory")
    descriptor = os.open(
        filename,
        os.O_RDWR | os.O_CREAT | os.O_NONBLOCK | os.O_NOFOLLOW,
        0o600,
        dir_fd=directory,
    )
    file_info = os.fstat(descriptor)
    path_file_info = os.stat(filename, dir_fd=directory, follow_symlinks=False)
    if (
        not stat.S_ISREG(file_info.st_mode)
        or not stat.S_ISREG(path_file_info.st_mode)
        or file_info.st_uid != os.getuid()
        or path_file_info.st_uid != os.getuid()
        or file_info.st_nlink != 1
        or path_file_info.st_nlink != 1
        or stat.S_IMODE(file_info.st_mode) != 0o600
        or stat.S_IMODE(path_file_info.st_mode) != 0o600
        or (file_info.st_dev, file_info.st_ino)
            != (path_file_info.st_dev, path_file_info.st_ino)
    ):
        raise SystemExit("refusing unsafe F03 maintenance lock identity")
    current_flags = fcntl.fcntl(descriptor, fcntl.F_GETFL)
    fcntl.fcntl(descriptor, fcntl.F_SETFL, current_flags & ~os.O_NONBLOCK)
    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        raise SystemExit("another F03 maintenance transaction already holds the global lock")
    os.set_inheritable(descriptor, True)
    environment = os.environ.copy()
    for unsafe_name in ("BASH_ENV", "ENV", "PYTHONHOME", "PYTHONPATH"):
        environment.pop(unsafe_name, None)
    environment["TILDE_F03_MAINTENANCE_LOCK_FD"] = str(descriptor)
    environment["TILDE_F03_MAINTENANCE_LOCK_PATH"] = os.path.join(
        directory_path, filename
    )
    os.execve("/bin/bash", ["/bin/bash", script, *arguments], environment)
finally:
    if descriptor is not None:
        os.close(descriptor)
    os.close(directory)
PY
}

selftest_maintenance_lock_contention() {
  local directory="$1"
  tilde_python_isolated - "$directory" <<'PY'
import fcntl
import os
import stat
import subprocess
import sys

directory_path = sys.argv[1]
lock_path = os.path.join(directory_path, ".f03-maintenance.lock")
descriptor = os.open(lock_path, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
try:
    info = os.fstat(descriptor)
    if (
        not stat.S_ISREG(info.st_mode)
        or info.st_uid != os.getuid()
        or info.st_nlink != 1
        or stat.S_IMODE(info.st_mode) != 0o600
    ):
        raise SystemExit("unsafe selftest maintenance lock")
    fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
    probe = r'''
import fcntl, os, sys
descriptor = os.open(sys.argv[1], os.O_RDWR | os.O_NOFOLLOW)
try:
    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        raise SystemExit(73)
finally:
    os.close(descriptor)
'''
    blocked = subprocess.run([sys.executable, "-c", probe, lock_path], check=False)
    if blocked.returncode != 73:
        raise SystemExit("maintenance-lock contender was not refused")
finally:
    os.close(descriptor)

available = subprocess.run([sys.executable, "-c", probe, lock_path], check=False)
if available.returncode != 0:
    raise SystemExit("released maintenance lock stayed unavailable")
PY
}

pids_for_binary() {
  local binary="$1" pid executable
  /bin/ps ax -o pid= | while read -r pid; do
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    executable="$(process_executable "$pid")"
    same_file_identity "$executable" "$binary" && printf '%s\n' "$pid"
  done
  return 0
}

process_start_identity() {
  /bin/ps -p "$1" -o lstart= 2>/dev/null | /usr/bin/awk '{$1=$1; print}' || true
}

binary_process_identities() {
  local binary="$1" pid executable started
  /bin/ps ax -o pid= | while read -r pid; do
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    executable="$(process_executable "$pid")"
    same_file_identity "$executable" "$binary" || continue
    started="$(process_start_identity "$pid")"
    [[ -n "$started" ]] && printf '%s\t%s\n' "$pid" "$started"
  done
  return 0
}

captured_binary_process_is_current() {
  local pid="$1" expected_started="$2" binary="$3" executable current_started
  executable="$(process_executable "$pid")"
  same_file_identity "$executable" "$binary" || return 1
  current_started="$(process_start_identity "$pid")"
  [[ -n "$current_started" && "$current_started" == "$expected_started" ]]
}

refuse_remaining_preview_processes() {
  local pid command found=0
  while read -r pid command; do
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    case "$command" in
      *"/Tilde 9B Preview.app/Contents/MacOS/Tilde"*|\
      *"/Tilde 9B Preview.app/Contents/Helpers/llama-server"*|\
      *"/InlineGhostIME 9B Preview.app/Contents/MacOS/InlineGhostIME"*)
        echo "unmatched Preview9B process remains after exact shutdown (pid $pid)" >&2
        found=1
        ;;
    esac
  done < <(/bin/ps ax -o pid=,command=)
  [[ "$found" == "0" ]]
}

stop_exact_binary() {
  local binary="$1" label="$2" identities pid started
  [[ -e "$binary" ]] || return 0
  identities="$(binary_process_identities "$binary")"
  [[ -n "$identities" ]] || return 0
  while IFS=$'\t' read -r pid started; do
    [[ -n "$pid" && -n "$started" ]] || continue
    # Revalidate both the executable inode and process birth immediately before
    # signalling so a recycled PID cannot receive this maintenance TERM.
    captured_binary_process_is_current "$pid" "$started" "$binary" || continue
    if ! kill -TERM "$pid" 2>/dev/null; then
      captured_binary_process_is_current "$pid" "$started" "$binary" || continue
      echo "$label could not be signalled without a PID-identity change" >&2
      return 1
    fi
  done <<<"$identities"
  for _ in {1..50}; do
    [[ -z "$(pids_for_binary "$binary")" ]] && return 0
    /bin/sleep 0.1
  done
  echo "$label did not stop cleanly; no maintenance mutation may continue" >&2
  return 1
}

helper_child_pid() {
  local parent="$1" helper="$2" pid ppid executable
  /bin/ps ax -o pid=,ppid= | while read -r pid ppid; do
    [[ "$ppid" == "$parent" ]] || continue
    executable="$(process_executable "$pid")"
    same_file_identity "$executable" "$helper" && printf '%s\n' "$pid"
  done
  return 0
}

pid_listens_on_preview_port() {
  local wanted="$1" listener
  while read -r listener; do
    [[ "$listener" == "$wanted" ]] && return 0
  done < <(/usr/sbin/lsof -nP -t -a -iTCP:17875 -sTCP:LISTEN 2>/dev/null || true)
  return 1
}

wait_for_preview_ready() {
  local app_binary="$1" helper="$2" installed_ime_binary="$3" expected_ime_sha="$4"
  local app_pid child_pid
  for _ in {1..120}; do
    app_pid="$(pids_for_binary "$app_binary" | /usr/bin/head -n 1)"
    if [[ -n "$app_pid" && -x "$installed_ime_binary" \
        && "$(sha256 "$installed_ime_binary")" == "$expected_ime_sha" ]]; then
      child_pid="$(helper_child_pid "$app_pid" "$helper" | /usr/bin/head -n 1)"
      if [[ -n "$child_pid" ]] && pid_listens_on_preview_port "$child_pid" \
        && /usr/bin/curl -sf http://127.0.0.1:17875/health >/dev/null; then
        return 0
      fi
    fi
    /bin/sleep 1
  done
  echo "exact Preview9B app, IME, and helper did not become ready" >&2
  return 1
}

atomic_receipt() {
  local output="$1"
  shift
  tilde_python_isolated - "$output" "$@" <<'PY'
import ctypes
import fcntl
import hashlib
import json
import os
import re
import stat
import sys

(
    output, run_id, source_commit, source_tree, source_snapshot,
    apple_toolchain_sha, xcode_version, xcode_build,
    swift_version_sha, swift_executable_sha,
    macos_sdk_version, macos_sdk_build, macos_sdk_settings_sha,
    approved_helper_input_sha, approved_helper_team,
    runner_sha, invocation_profile, version, build, app_sha, ime_sha, helper_sha, app_plist_sha,
    ime_plist_sha, rotation_at, completed_at, previous_disposition,
    previous_bytes, previous_sha, generation, signing_team, model_sha,
    model_bytes, os_version, os_build, architecture, hardware_model,
    power_source, first_registration_verified, final_registration_verified,
) = sys.argv[1:]

if first_registration_verified != "1" or final_registration_verified != "1":
    raise SystemExit("receipt requires first-install and final TIS registration proof")
if (
    not re.fullmatch(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", run_id)
    or
    len(runner_sha) != 64
    or any(character not in "0123456789abcdef" for character in runner_sha)
    or invocation_profile != "preview9b-owner-approved-v1"
):
    raise SystemExit("receipt requires exact F03 runner and invocation lineage")

lower_hex_fields = {
    "sourceCommit": (source_commit, 40),
    "sourceTree": (source_tree, 40),
    "sourceSnapshotSHA256": (source_snapshot, 64),
    "appleToolchainSHA256": (apple_toolchain_sha, 64),
    "swiftVersionSHA256": (swift_version_sha, 64),
    "swiftExecutableSHA256": (swift_executable_sha, 64),
    "macOSSDKSettingsSHA256": (macos_sdk_settings_sha, 64),
    "approvedHelperInputSHA256": (approved_helper_input_sha, 64),
    "installedAppBinarySHA256": (app_sha, 64),
    "installedIMEBinarySHA256": (ime_sha, 64),
    "installedHelperSHA256": (helper_sha, 64),
    "installedAppInfoPlistSHA256": (app_plist_sha, 64),
    "installedIMEInfoPlistSHA256": (ime_plist_sha, 64),
    "modelSHA256": (model_sha, 64),
}
for name, (value, length) in lower_hex_fields.items():
    if len(value) != length or any(
        character not in "0123456789abcdef" for character in value
    ):
        raise SystemExit(f"receipt has invalid {name}")
if not re.fullmatch(r"[0-9]+(?:[.][0-9]+){1,3}", xcode_version):
    raise SystemExit("receipt has invalid xcodeVersion")
if not re.fullmatch(r"[0-9]+(?:[.][0-9]+){1,3}", macos_sdk_version):
    raise SystemExit("receipt has invalid macOSSDKVersion")
if not re.fullmatch(r"[A-Za-z0-9]{1,32}", xcode_build):
    raise SystemExit("receipt has invalid xcodeBuild")
if not re.fullmatch(r"[A-Za-z0-9]{1,32}", macos_sdk_build):
    raise SystemExit("receipt has invalid macOSSDKBuild")
if not re.fullmatch(r"[A-Z0-9]{10}", approved_helper_team):
    raise SystemExit("receipt has invalid approvedHelperTeamIdentifier")
if approved_helper_team != signing_team:
    raise SystemExit("approved helper team must equal the final signing team")
registered_helper_sha = (
    "e7b0946d81c2342d0d5afd1639dcb8af444c843b4fb50cef5ceeafa302a80546"
)
registered_team = "XG6WL66WUQ"
registered_model_sha = (
    "4171d5fec62a373744ca4f01ec9e2378c092a65f480c039e9c679d910351fda2"
)
if (
    approved_helper_input_sha != registered_helper_sha
    or helper_sha != registered_helper_sha
    or approved_helper_team != registered_team
    or signing_team != registered_team
    or model_sha != registered_model_sha
    or model_bytes != "5629109312"
):
    raise SystemExit("receipt identity is not registered for F03")
if previous_sha:
    if len(previous_sha) != 64 or any(
        character not in "0123456789abcdef" for character in previous_sha
    ):
        raise SystemExit("receipt has invalid previousLedgerSHA256")
try:
    previous_bytes_value = int(previous_bytes)
    generation_value = int(generation)
except ValueError as error:
    raise SystemExit("receipt counters must be decimal integers") from error
if (
    str(previous_bytes_value) != previous_bytes
    or previous_bytes_value < 0
    or str(generation_value) != generation
    or not 1 <= generation_value <= 2147483647
    or not re.fullmatch(r"[0-9]{1,64}", build)
):
    raise SystemExit("receipt counters are outside the registered domain")
if previous_disposition == "absent":
    if previous_bytes_value != 0 or previous_sha:
        raise SystemExit("absent previous ledger may not claim bytes or a digest")
elif previous_disposition in {"archive", "delete"}:
    if not previous_sha:
        raise SystemExit("rotated previous ledger requires an exact digest")
else:
    raise SystemExit("receipt has invalid previousLedgerDisposition")
timestamp_pattern = r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:[.][0-9]{3})?Z"
if not re.fullmatch(timestamp_pattern, rotation_at) or not re.fullmatch(
    timestamp_pattern, completed_at
):
    raise SystemExit("receipt timestamps must be UTC RFC3339 tokens")

payload = {
    "schema": "tilde.f03-local-run-receipt.v1",
    "runID": run_id,
    "profile": "preview-9b",
    "evidenceClass": "decision-grade",
    "sourceState": "clean",
    "sourceCommit": source_commit,
    "sourceTree": source_tree,
    "sourceSnapshotSHA256": source_snapshot,
    "appleToolchainSHA256": apple_toolchain_sha,
    "xcodeVersion": xcode_version,
    "xcodeBuild": xcode_build,
    "swiftVersionSHA256": swift_version_sha,
    "swiftExecutableSHA256": swift_executable_sha,
    "macOSSDKVersion": macos_sdk_version,
    "macOSSDKBuild": macos_sdk_build,
    "macOSSDKSettingsSHA256": macos_sdk_settings_sha,
    "approvedHelperInputSHA256": approved_helper_input_sha,
    "approvedHelperTeamIdentifier": approved_helper_team,
    "runnerSHA256": runner_sha,
    "invocationProfile": invocation_profile,
    "bundleVersion": version,
    "bundleBuild": build,
    "installedAppBinarySHA256": app_sha,
    "installedIMEBinarySHA256": ime_sha,
    "installedHelperSHA256": helper_sha,
    "installedAppInfoPlistSHA256": app_plist_sha,
    "installedIMEInfoPlistSHA256": ime_plist_sha,
    "rotationTimestamp": rotation_at,
    "completedTimestamp": completed_at,
    "previousLedgerDisposition": previous_disposition,
    "previousLedgerBytes": previous_bytes_value,
    "previousLedgerSHA256": previous_sha or None,
    "outcomeLedgerGeneration": generation_value,
    "signingTeamIdentifier": signing_team,
    "modelSHA256": model_sha,
    "modelBytes": int(model_bytes),
    "operatingSystemVersion": os_version,
    "operatingSystemBuild": os_build,
    "architecture": architecture,
    "hardwareModel": hardware_model,
    "powerSource": power_source,
    "appReady": True,
    "inputMethodBundleInstalled": True,
    "inputMethodRegistrationVerified": (
        first_registration_verified == "1" and final_registration_verified == "1"
    ),
    "helperReady": True,
}

if not os.path.isabs(output):
    raise SystemExit("receipt path must be absolute")
parent = os.path.dirname(output)
output_name = os.path.basename(output)
temporary_name = ".receipt.tmp"
directory_flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC
directory = os.open(parent, directory_flags)
descriptor = None
renamed = False

def validate_directory() -> None:
    info = os.fstat(directory)
    path_info = os.stat(parent, follow_symlinks=False)
    if (
        not stat.S_ISDIR(info.st_mode)
        or not stat.S_ISDIR(path_info.st_mode)
        or info.st_uid != os.getuid()
        or path_info.st_uid != os.getuid()
        or info.st_nlink < 1
        or path_info.st_nlink < 1
        or stat.S_IMODE(info.st_mode) != 0o700
        or stat.S_IMODE(path_info.st_mode) != 0o700
        or (info.st_dev, info.st_ino) != (path_info.st_dev, path_info.st_ino)
    ):
        raise RuntimeError("refusing unsafe F03 receipt directory")

def refuse_existing(name: str, label: str) -> None:
    try:
        os.stat(name, dir_fd=directory, follow_symlinks=False)
    except FileNotFoundError:
        return
    raise RuntimeError(f"refusing existing {label}")

def validate_file(name: str, info: os.stat_result) -> None:
    path_info = os.stat(name, dir_fd=directory, follow_symlinks=False)
    if (
        not stat.S_ISREG(info.st_mode)
        or not stat.S_ISREG(path_info.st_mode)
        or info.st_uid != os.getuid()
        or path_info.st_uid != os.getuid()
        or info.st_nlink != 1
        or path_info.st_nlink != 1
        or stat.S_IMODE(info.st_mode) != 0o600
        or stat.S_IMODE(path_info.st_mode) != 0o600
        or (info.st_dev, info.st_ino) != (path_info.st_dev, path_info.st_ino)
    ):
        raise RuntimeError("refusing unsafe F03 receipt file identity")

def rename_exclusive(source_name: str, target_name: str) -> None:
    libc = ctypes.CDLL(None, use_errno=True)
    renameatx_np = libc.renameatx_np
    renameatx_np.argtypes = [
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_uint,
    ]
    renameatx_np.restype = ctypes.c_int
    flags = 0x00000004 | 0x00000010  # RENAME_EXCL | RENAME_NOFOLLOW_ANY
    if renameatx_np(
        directory,
        os.fsencode(source_name),
        directory,
        os.fsencode(target_name),
        flags,
    ) != 0:
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error), target_name)

try:
    validate_directory()
    fcntl.flock(directory, fcntl.LOCK_EX)
    validate_directory()
    refuse_existing(output_name, "F03 receipt target")
    refuse_existing(temporary_name, "F03 receipt temporary")
    descriptor = os.open(
        temporary_name,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC,
        0o600,
        dir_fd=directory,
    )
    initial_info = os.fstat(descriptor)
    validate_file(temporary_name, initial_info)
    encoded = (
        json.dumps(payload, sort_keys=True, separators=(",", ":")) + "\n"
    ).encode("utf-8")
    receipt_digest = hashlib.sha256(encoded).hexdigest()
    view = memoryview(encoded)
    while view:
        view = view[os.write(descriptor, view):]
    os.fsync(descriptor)
    final_info = os.fstat(descriptor)
    validate_file(temporary_name, final_info)
    rename_exclusive(temporary_name, output_name)
    renamed = True
    os.fsync(directory)
    published_info = os.fstat(descriptor)
    validate_file(output_name, published_info)
except BaseException:
    try:
        cleanup_name = output_name if renamed else temporary_name
        cleanup_info = os.stat(cleanup_name, dir_fd=directory, follow_symlinks=False)
        if descriptor is not None:
            owned_info = os.fstat(descriptor)
            if (cleanup_info.st_dev, cleanup_info.st_ino) == (
                owned_info.st_dev, owned_info.st_ino
            ):
                os.unlink(cleanup_name, dir_fd=directory)
                os.fsync(directory)
    except (FileNotFoundError, OSError):
        pass
    raise
finally:
    if descriptor is not None:
        os.close(descriptor)
    os.close(directory)
print(receipt_digest)
PY
}

finalize_receipt() {
  local pending="$1" final="$2" expected_run_id="$3"
  local expected_runner_sha="$4" expected_invocation_profile="$5"
  local expected_receipt_sha="$6"
  tilde_python_isolated - \
    "$pending" "$final" "$expected_run_id" "$expected_runner_sha" \
    "$expected_invocation_profile" "$expected_receipt_sha" \
    "$RECEIPT_TEST_READY" "$RECEIPT_TEST_CONTINUE" <<'PY'
import ctypes
import fcntl
import hashlib
import json
import os
import stat
import sys
import time

(
    pending,
    final,
    expected_run_id,
    expected_runner_sha,
    expected_invocation_profile,
    expected_receipt_sha,
    test_ready,
    test_continue,
) = sys.argv[1:]
if not os.path.isabs(pending) or os.path.dirname(pending) != os.path.dirname(final):
    raise SystemExit("receipt finalization requires one absolute directory")
if len(expected_receipt_sha) != 64 or any(
    character not in "0123456789abcdef" for character in expected_receipt_sha
):
    raise SystemExit("receipt finalization requires an exact pending-receipt digest")
if bool(test_ready) != bool(test_continue):
    raise SystemExit("receipt race selftest requires both barrier paths")
if test_ready:
    for barrier in (test_ready, test_continue):
        barrier_parent = os.path.dirname(barrier)
        if (
            not os.path.isabs(barrier)
            or barrier_parent != os.path.dirname(pending)
            or not os.path.basename(barrier_parent).startswith("tilde-f03-receipt.")
        ):
            raise SystemExit("receipt race selftest barrier is outside its fixture")
parent = os.path.dirname(pending)
pending_name = os.path.basename(pending)
final_name = os.path.basename(final)
directory = os.open(
    parent,
    os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC,
)
renamed = False
pending_descriptor = None
try:
    info = os.fstat(directory)
    path_info = os.stat(parent, follow_symlinks=False)
    if (
        not stat.S_ISDIR(info.st_mode)
        or not stat.S_ISDIR(path_info.st_mode)
        or info.st_uid != os.getuid()
        or path_info.st_uid != os.getuid()
        or info.st_nlink < 1
        or path_info.st_nlink < 1
        or stat.S_IMODE(info.st_mode) != 0o700
        or stat.S_IMODE(path_info.st_mode) != 0o700
        or (info.st_dev, info.st_ino) != (path_info.st_dev, path_info.st_ino)
    ):
        raise RuntimeError("refusing unsafe F03 receipt directory")
    fcntl.flock(directory, fcntl.LOCK_EX)
    pending_descriptor = os.open(
        pending_name,
        os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW | os.O_CLOEXEC,
        dir_fd=directory,
    )
    pending_info = os.fstat(pending_descriptor)
    pending_path_info = os.stat(
        pending_name, dir_fd=directory, follow_symlinks=False
    )
    if (
        not stat.S_ISREG(pending_info.st_mode)
        or not stat.S_ISREG(pending_path_info.st_mode)
        or pending_info.st_uid != os.getuid()
        or pending_path_info.st_uid != os.getuid()
        or pending_info.st_nlink != 1
        or pending_path_info.st_nlink != 1
        or stat.S_IMODE(pending_info.st_mode) != 0o600
        or stat.S_IMODE(pending_path_info.st_mode) != 0o600
        or pending_info.st_size > 1024 * 1024
        or (pending_info.st_dev, pending_info.st_ino)
            != (pending_path_info.st_dev, pending_path_info.st_ino)
    ):
        raise RuntimeError("refusing unsafe pending F03 receipt")
    encoded = b""
    while chunk := os.read(pending_descriptor, 1024 * 1024):
        encoded += chunk
        if len(encoded) > 1024 * 1024:
            raise RuntimeError("pending F03 receipt exceeds its size bound")
    pending_after_read = os.fstat(pending_descriptor)
    pending_path_after_read = os.stat(
        pending_name, dir_fd=directory, follow_symlinks=False
    )
    if (
        hashlib.sha256(encoded).hexdigest() != expected_receipt_sha
        or len(encoded) != pending_info.st_size
        or (pending_info.st_dev, pending_info.st_ino, pending_info.st_size,
            pending_info.st_nlink, stat.S_IMODE(pending_info.st_mode))
            != (pending_after_read.st_dev, pending_after_read.st_ino,
                pending_after_read.st_size, pending_after_read.st_nlink,
                stat.S_IMODE(pending_after_read.st_mode))
        or (pending_info.st_dev, pending_info.st_ino)
            != (pending_path_after_read.st_dev, pending_path_after_read.st_ino)
    ):
        raise RuntimeError("pending F03 receipt changed while it was verified")
    parsed = json.loads(encoded)
    if (
        parsed.get("schema") != "tilde.f03-local-run-receipt.v1"
        or parsed.get("runID") != expected_run_id
        or parsed.get("runnerSHA256") != expected_runner_sha
        or parsed.get("invocationProfile") != expected_invocation_profile
    ):
        raise RuntimeError("pending F03 receipt lineage mismatch")
    try:
        os.stat(final_name, dir_fd=directory, follow_symlinks=False)
    except FileNotFoundError:
        pass
    else:
        raise RuntimeError("final F03 receipt already exists")
    if test_ready:
        ready_descriptor = os.open(
            test_ready,
            os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC,
            0o600,
        )
        os.close(ready_descriptor)
        for _ in range(500):
            try:
                continuation = os.lstat(test_continue)
            except FileNotFoundError:
                time.sleep(0.01)
                continue
            if not stat.S_ISREG(continuation.st_mode):
                raise RuntimeError("receipt race selftest continuation is unsafe")
            break
        else:
            raise RuntimeError("receipt race selftest continuation timed out")
    libc = ctypes.CDLL(None, use_errno=True)
    renameatx_np = libc.renameatx_np
    renameatx_np.argtypes = [
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_uint,
    ]
    renameatx_np.restype = ctypes.c_int
    if renameatx_np(
        directory,
        os.fsencode(pending_name),
        directory,
        os.fsencode(final_name),
        0x00000004 | 0x00000010,
    ) != 0:
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error), final_name)
    renamed = True
    os.fsync(directory)
    final_descriptor_info = os.fstat(pending_descriptor)
    final_info = os.stat(final_name, dir_fd=directory, follow_symlinks=False)
    if (
        not stat.S_ISREG(final_descriptor_info.st_mode)
        or not stat.S_ISREG(final_info.st_mode)
        or final_descriptor_info.st_uid != os.getuid()
        or final_info.st_uid != os.getuid()
        or (final_info.st_dev, final_info.st_ino)
            != (final_descriptor_info.st_dev, final_descriptor_info.st_ino)
        or (final_descriptor_info.st_dev, final_descriptor_info.st_ino)
            != (pending_info.st_dev, pending_info.st_ino)
        or final_descriptor_info.st_nlink != 1
        or final_info.st_nlink != 1
        or stat.S_IMODE(final_descriptor_info.st_mode) != 0o600
        or stat.S_IMODE(final_info.st_mode) != 0o600
    ):
        raise RuntimeError("final F03 receipt identity changed")
except BaseException:
    # Once the exclusive final rename succeeds the receipt is the durable
    # commit marker. Leave it in place so the caller can fail closed and ask
    # for inspection instead of attempting a second, potentially overwriting
    # rename across an indeterminate fsync boundary.
    raise
finally:
    if pending_descriptor is not None:
        os.close(pending_descriptor)
    os.close(directory)
PY
}

write_transaction_journal() {
  local operation="$1" output="$2" run_id="$3" phase="$4" run_dir="$5"
  local transaction_dir="$6" ime_transaction_dir="$7" old_app_was_running="$8"
  local app_backup_state="$9" ime_backup_state="${10}"
  local generation_was_present="${11}" current_generation="${12}"
  local next_generation="${13}" receipt="${14}" runner_sha="${15}"
  local invocation_profile="${16}"
  tilde_python_isolated - \
    "$operation" "$output" "$run_id" "$phase" "$run_dir" \
    "$transaction_dir" "$ime_transaction_dir" "$old_app_was_running" \
    "$app_backup_state" "$ime_backup_state" "$generation_was_present" \
    "$current_generation" "$next_generation" "$receipt" "$runner_sha" \
    "$invocation_profile" <<'PY'
import fcntl
import json
import os
import re
import stat
import sys

(
    operation, output, run_id, phase, run_dir, transaction_dir,
    ime_transaction_dir, old_app_was_running, app_backup_state,
    ime_backup_state, generation_was_present, current_generation,
    next_generation, receipt, runner_sha, invocation_profile,
) = sys.argv[1:]
if operation not in {"create", "update"}:
    raise SystemExit("invalid F03 journal operation")
if not re.fullmatch(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", run_id):
    raise SystemExit("invalid F03 journal run ID")
if not re.fullmatch(r"[a-z][a-z0-9-]{0,63}", phase):
    raise SystemExit("invalid F03 journal phase")
if old_app_was_running not in {"0", "1"}:
    raise SystemExit("invalid F03 journal running state")
if app_backup_state not in {"unknown", "absent", "present"} or ime_backup_state not in {
    "unknown", "absent", "present"
}:
    raise SystemExit("invalid F03 journal bundle state")
if generation_was_present not in {"0", "1"}:
    raise SystemExit("invalid F03 journal generation state")
if (
    len(runner_sha) != 64
    or any(character not in "0123456789abcdef" for character in runner_sha)
    or invocation_profile != "preview9b-owner-approved-v1"
):
    raise SystemExit("invalid F03 journal runner lineage")
for value in (current_generation, next_generation):
    if value and (not value.isdecimal() or int(value) > 2147483647):
        raise SystemExit("invalid F03 journal generation")
for path in (output, run_dir, transaction_dir, ime_transaction_dir, receipt):
    if not os.path.isabs(path) or "\x00" in path:
        raise SystemExit("F03 journal paths must be absolute")

payload = {
    "schema": "tilde.f03-maintenance-transaction.v1",
    "runID": run_id,
    "phase": phase,
    "runDirectory": run_dir,
    "appTransactionDirectory": transaction_dir,
    "imeTransactionDirectory": ime_transaction_dir,
    "oldAppWasRunning": old_app_was_running == "1",
    "appBackupState": app_backup_state,
    "imeBackupState": ime_backup_state,
    "generationWasPresent": generation_was_present == "1",
    "previousGeneration": int(current_generation) if current_generation else None,
    "nextGeneration": int(next_generation) if next_generation else None,
    "receipt": receipt,
    "runnerSHA256": runner_sha,
    "invocationProfile": invocation_profile,
    "commitDurable": phase in {"receipt-durable", "cleanup-intent", "cleanup-complete"},
}
parent = os.path.dirname(output)
output_name = os.path.basename(output)
temporary_name = ".f03-transaction.tmp"
directory = os.open(
    parent,
    os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC,
)
temporary_descriptor = None

def validate_directory() -> None:
    info = os.fstat(directory)
    path_info = os.stat(parent, follow_symlinks=False)
    if (
        not stat.S_ISDIR(info.st_mode)
        or not stat.S_ISDIR(path_info.st_mode)
        or info.st_uid != os.getuid()
        or path_info.st_uid != os.getuid()
        or info.st_nlink < 1
        or path_info.st_nlink < 1
        or stat.S_IMODE(info.st_mode) != 0o700
        or stat.S_IMODE(path_info.st_mode) != 0o700
        or (info.st_dev, info.st_ino) != (path_info.st_dev, path_info.st_ino)
    ):
        raise RuntimeError("refusing unsafe F03 journal directory")

def lstat_or_none(name: str):
    try:
        return os.stat(name, dir_fd=directory, follow_symlinks=False)
    except FileNotFoundError:
        return None

def open_validated(name: str) -> tuple[int, os.stat_result]:
    descriptor = os.open(
        name,
        os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW | os.O_CLOEXEC,
        dir_fd=directory,
    )
    info = os.fstat(descriptor)
    path_info = os.stat(name, dir_fd=directory, follow_symlinks=False)
    if (
        not stat.S_ISREG(info.st_mode)
        or not stat.S_ISREG(path_info.st_mode)
        or info.st_uid != os.getuid()
        or path_info.st_uid != os.getuid()
        or info.st_nlink != 1
        or path_info.st_nlink != 1
        or stat.S_IMODE(info.st_mode) != 0o600
        or stat.S_IMODE(path_info.st_mode) != 0o600
        or info.st_size > 64 * 1024
        or path_info.st_size > 64 * 1024
        or (info.st_dev, info.st_ino) != (path_info.st_dev, path_info.st_ino)
    ):
        os.close(descriptor)
        raise RuntimeError("refusing unsafe F03 journal identity")
    return descriptor, info

try:
    validate_directory()
    fcntl.flock(directory, fcntl.LOCK_EX)
    validate_directory()
    if lstat_or_none(temporary_name) is not None:
        raise RuntimeError("unfinished F03 journal temporary exists; recover manually")
    existing = lstat_or_none(output_name)
    if operation == "create":
        if existing is not None:
            raise RuntimeError("unfinished F03 transaction exists; recover manually")
    else:
        if existing is None:
            raise RuntimeError("F03 transaction journal disappeared")
        existing_descriptor, _ = open_validated(output_name)
        try:
            encoded_existing = b""
            while chunk := os.read(existing_descriptor, 64 * 1024):
                encoded_existing += chunk
                if len(encoded_existing) > 64 * 1024:
                    raise RuntimeError("F03 journal exceeds its size bound")
            existing_payload = json.loads(encoded_existing)
        finally:
            os.close(existing_descriptor)
        if (
            existing_payload.get("schema") != "tilde.f03-maintenance-transaction.v1"
            or existing_payload.get("runID") != run_id
        ):
            raise RuntimeError("F03 transaction journal lineage mismatch")
    temporary_descriptor = os.open(
        temporary_name,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC,
        0o600,
        dir_fd=directory,
    )
    temporary_info = os.fstat(temporary_descriptor)
    temporary_path_info = os.stat(
        temporary_name, dir_fd=directory, follow_symlinks=False
    )
    if (
        not stat.S_ISREG(temporary_info.st_mode)
        or not stat.S_ISREG(temporary_path_info.st_mode)
        or temporary_info.st_uid != os.getuid()
        or temporary_path_info.st_uid != os.getuid()
        or temporary_info.st_nlink != 1
        or temporary_path_info.st_nlink != 1
        or stat.S_IMODE(temporary_info.st_mode) != 0o600
        or stat.S_IMODE(temporary_path_info.st_mode) != 0o600
        or (temporary_info.st_dev, temporary_info.st_ino)
            != (temporary_path_info.st_dev, temporary_path_info.st_ino)
    ):
        raise RuntimeError("refusing unsafe F03 journal temporary")
    encoded = (
        json.dumps(payload, sort_keys=True, separators=(",", ":")) + "\n"
    ).encode("utf-8")
    view = memoryview(encoded)
    while view:
        view = view[os.write(temporary_descriptor, view):]
    os.fsync(temporary_descriptor)
    final_temporary_info = os.fstat(temporary_descriptor)
    final_temporary_path_info = os.stat(
        temporary_name, dir_fd=directory, follow_symlinks=False
    )
    if (
        final_temporary_info.st_nlink != 1
        or final_temporary_path_info.st_nlink != 1
        or stat.S_IMODE(final_temporary_info.st_mode) != 0o600
        or stat.S_IMODE(final_temporary_path_info.st_mode) != 0o600
        or (final_temporary_info.st_dev, final_temporary_info.st_ino)
            != (final_temporary_path_info.st_dev, final_temporary_path_info.st_ino)
    ):
        raise RuntimeError("F03 journal temporary identity changed")
    os.replace(
        temporary_name,
        output_name,
        src_dir_fd=directory,
        dst_dir_fd=directory,
    )
    os.fsync(directory)
    journal_descriptor, journal_info = open_validated(output_name)
    os.close(journal_descriptor)
    if (journal_info.st_dev, journal_info.st_ino) != (
        final_temporary_info.st_dev, final_temporary_info.st_ino
    ):
        raise RuntimeError("F03 journal identity changed after publication")
except BaseException:
    try:
        temporary_info = lstat_or_none(temporary_name)
        if temporary_info is not None and temporary_descriptor is not None:
            owned_info = os.fstat(temporary_descriptor)
            if (temporary_info.st_dev, temporary_info.st_ino) == (
                owned_info.st_dev, owned_info.st_ino
            ):
                os.unlink(temporary_name, dir_fd=directory)
                os.fsync(directory)
    except OSError:
        pass
    raise
finally:
    if temporary_descriptor is not None:
        os.close(temporary_descriptor)
    os.close(directory)
PY
}

remove_transaction_journal() {
  local output="$1" run_id="$2" expected_phase="$3"
  tilde_python_isolated - "$output" "$run_id" "$expected_phase" <<'PY'
import fcntl
import json
import os
import stat
import sys

output, run_id, expected_phase = sys.argv[1:]
parent = os.path.dirname(output)
name = os.path.basename(output)
directory = os.open(
    parent,
    os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC,
)
descriptor = None
try:
    directory_info = os.fstat(directory)
    path_directory_info = os.stat(parent, follow_symlinks=False)
    if (
        not stat.S_ISDIR(directory_info.st_mode)
        or not stat.S_ISDIR(path_directory_info.st_mode)
        or directory_info.st_uid != os.getuid()
        or path_directory_info.st_uid != os.getuid()
        or stat.S_IMODE(directory_info.st_mode) != 0o700
        or stat.S_IMODE(path_directory_info.st_mode) != 0o700
        or (directory_info.st_dev, directory_info.st_ino)
            != (path_directory_info.st_dev, path_directory_info.st_ino)
    ):
        raise RuntimeError("refusing unsafe F03 journal directory")
    fcntl.flock(directory, fcntl.LOCK_EX)
    try:
        os.stat(".f03-transaction.tmp", dir_fd=directory, follow_symlinks=False)
    except FileNotFoundError:
        pass
    else:
        raise RuntimeError("refusing to remove journal beside unfinished temporary")
    descriptor = os.open(
        name,
        os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW | os.O_CLOEXEC,
        dir_fd=directory,
    )
    info = os.fstat(descriptor)
    path_info = os.stat(name, dir_fd=directory, follow_symlinks=False)
    if (
        not stat.S_ISREG(info.st_mode)
        or not stat.S_ISREG(path_info.st_mode)
        or info.st_uid != os.getuid()
        or path_info.st_uid != os.getuid()
        or info.st_nlink != 1
        or path_info.st_nlink != 1
        or stat.S_IMODE(info.st_mode) != 0o600
        or stat.S_IMODE(path_info.st_mode) != 0o600
        or info.st_size > 64 * 1024
        or path_info.st_size > 64 * 1024
        or (info.st_dev, info.st_ino) != (path_info.st_dev, path_info.st_ino)
    ):
        raise RuntimeError("refusing unsafe F03 journal identity")
    encoded = b""
    while chunk := os.read(descriptor, 64 * 1024):
        encoded += chunk
    payload = json.loads(encoded)
    if (
        payload.get("schema") != "tilde.f03-maintenance-transaction.v1"
        or payload.get("runID") != run_id
        or payload.get("phase") != expected_phase
    ):
        raise RuntimeError("refusing to remove F03 journal in an unexpected phase")
    final_info = os.stat(name, dir_fd=directory, follow_symlinks=False)
    if (
        (info.st_dev, info.st_ino) != (final_info.st_dev, final_info.st_ino)
        or not stat.S_ISREG(final_info.st_mode)
        or final_info.st_uid != os.getuid()
        or final_info.st_nlink != 1
        or stat.S_IMODE(final_info.st_mode) != 0o600
    ):
        raise RuntimeError("F03 journal identity changed before removal")
    os.unlink(name, dir_fd=directory)
    os.fsync(directory)
finally:
    if descriptor is not None:
        os.close(descriptor)
    os.close(directory)
PY
}

ensure_owner_only_directory() {
  local path="$1" create_if_missing="${2:-0}" require_new="${3:-0}"
  tilde_python_isolated - "$path" "$create_if_missing" "$require_new" <<'PY'
import os
import stat
import sys

path, create_if_missing, require_new = sys.argv[1:]
if (
    create_if_missing not in {"0", "1"}
    or require_new not in {"0", "1"}
    or not os.path.isabs(path)
):
    raise SystemExit("invalid owner-only directory request")
created = False
if create_if_missing == "1":
    try:
        os.mkdir(path, 0o700)
        created = True
    except FileExistsError:
        if require_new == "1":
            raise RuntimeError("owner-only transaction directory already exists")
    except FileNotFoundError:
        raise RuntimeError("owner-only directory parent is missing")
if not created and create_if_missing != "1" and not os.path.isdir(path):
    raise RuntimeError("required owner-only directory is missing")
descriptor = os.open(
    path,
    os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC,
)
try:
    info = os.fstat(descriptor)
    path_info = os.stat(path, follow_symlinks=False)
    if (
        not stat.S_ISDIR(info.st_mode)
        or not stat.S_ISDIR(path_info.st_mode)
        or info.st_uid != os.getuid()
        or path_info.st_uid != os.getuid()
        or info.st_nlink < 1
        or path_info.st_nlink < 1
        or stat.S_IMODE(info.st_mode) != 0o700
        or stat.S_IMODE(path_info.st_mode) != 0o700
        or (info.st_dev, info.st_ino) != (path_info.st_dev, path_info.st_ino)
    ):
        raise RuntimeError("refusing unsafe owner-only F03 directory")
    os.fsync(descriptor)
finally:
    os.close(descriptor)
if created:
    parent = os.open(
        os.path.dirname(path),
        os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC,
    )
    try:
        os.fsync(parent)
    finally:
        os.close(parent)
PY
}

rotate_event_file() {
  local source="$1" target="$2" domain="${3:-}" was_present="${4:-0}"
  local previous="${5:-0}" next="${6:-0}"
  tilde_python_isolated - "$source" "$target" "$DEFAULTS_COMMAND" "$domain" \
    "$was_present" "$previous" "$next" \
    "$ROTATION_TEST_READY" "$ROTATION_TEST_CONTINUE" <<'PY'
import fcntl
import hashlib
import os
import stat
import subprocess
import sys
import time

(
    source, target, defaults_command, domain, was_present,
    previous_generation, next_generation, ready_hook, continue_hook,
) = sys.argv[1:]
source_directory_path = os.path.dirname(source)
target_directory_path = os.path.dirname(target)
source_name = os.path.basename(source)
target_name = os.path.basename(target)
directory_flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC
source_directory = os.open(source_directory_path, directory_flags)
opened_target_directory = os.open(target_directory_path, directory_flags)
source_directory_identity = os.fstat(source_directory)
opened_target_identity = os.fstat(opened_target_directory)
same_directory = (
    source_directory_identity.st_dev,
    source_directory_identity.st_ino,
) == (opened_target_identity.st_dev, opened_target_identity.st_ino)
if same_directory:
    os.close(opened_target_directory)
    target_directory = os.dup(source_directory)
else:
    target_directory = opened_target_directory
descriptor = None
renamed = False
generation_changed = False
source_was_present = False
maximum_event_bytes = 64 * 1024 * 1024

def validate_directory(descriptor: int, path: str) -> None:
    info = os.fstat(descriptor)
    path_info = os.stat(path, follow_symlinks=False)
    if (
        not stat.S_ISDIR(info.st_mode)
        or not stat.S_ISDIR(path_info.st_mode)
        or info.st_uid != os.getuid()
        or path_info.st_uid != os.getuid()
        or info.st_nlink < 1
        or path_info.st_nlink < 1
        or stat.S_IMODE(info.st_mode) != 0o700
        or stat.S_IMODE(path_info.st_mode) != 0o700
        or (info.st_dev, info.st_ino) != (path_info.st_dev, path_info.st_ino)
    ):
        raise RuntimeError("refusing unsafe Outcome Ledger directory identity")

def run_defaults(*arguments: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [defaults_command, *arguments],
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

def restore_generation() -> None:
    if not domain:
        return
    if was_present == "1":
        run_defaults("write", domain, "OutcomeLedgerGeneration", "-int", previous_generation)
        observed = run_defaults("read", domain, "OutcomeLedgerGeneration").stdout.strip()
        if observed != previous_generation:
            raise RuntimeError("previous Outcome Ledger generation was not restored")
    else:
        run_defaults("delete", domain, "OutcomeLedgerGeneration", check=False)
        observed = run_defaults("read", domain, "OutcomeLedgerGeneration", check=False)
        if observed.returncode == 0:
            raise RuntimeError("new Outcome Ledger generation remained after rollback")

def validate_event_file(info: os.stat_result, path_info: os.stat_result) -> None:
    if (
        not stat.S_ISREG(info.st_mode)
        or not stat.S_ISREG(path_info.st_mode)
        or info.st_nlink != 1
        or path_info.st_nlink != 1
        or info.st_uid != os.getuid()
        or path_info.st_uid != os.getuid()
        or stat.S_IMODE(info.st_mode) != 0o600
        or stat.S_IMODE(path_info.st_mode) != 0o600
        or info.st_size > maximum_event_bytes
        or path_info.st_size > maximum_event_bytes
        or (info.st_dev, info.st_ino) != (path_info.st_dev, path_info.st_ino)
    ):
        raise RuntimeError("refusing unsafe Outcome Ledger file identity")

try:
    validate_directory(source_directory, source_directory_path)
    validate_directory(target_directory, target_directory_path)
    fcntl.flock(source_directory, fcntl.LOCK_EX)
    if not same_directory:
        fcntl.flock(target_directory, fcntl.LOCK_EX)
    validate_directory(source_directory, source_directory_path)
    validate_directory(target_directory, target_directory_path)
    try:
        os.stat(target_name, dir_fd=target_directory, follow_symlinks=False)
    except FileNotFoundError:
        pass
    else:
        raise RuntimeError("Outcome Ledger rotation target already exists")

    # Open and validate the ledger before changing generation. O_NONBLOCK makes
    # a substituted FIFO/device fail the regular-file gate instead of hanging
    # this owner-approved transaction while the directory lock is held.
    try:
        descriptor = os.open(
            source_name,
            os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW | os.O_CLOEXEC,
            dir_fd=source_directory,
        )
    except FileNotFoundError:
        descriptor = None
    else:
        source_was_present = True
        info = os.fstat(descriptor)
        path_info = os.stat(source_name, dir_fd=source_directory, follow_symlinks=False)
        validate_event_file(info, path_info)
        fcntl.flock(descriptor, fcntl.LOCK_EX)
        info = os.fstat(descriptor)
        path_info = os.stat(source_name, dir_fd=source_directory, follow_symlinks=False)
        validate_event_file(info, path_info)
        current_flags = fcntl.fcntl(descriptor, fcntl.F_GETFL)
        fcntl.fcntl(descriptor, fcntl.F_SETFL, current_flags & ~os.O_NONBLOCK)

    if domain:
        generation_changed = True
        run_defaults("write", domain, "OutcomeLedgerGeneration", "-int", next_generation)
        observed = run_defaults("read", domain, "OutcomeLedgerGeneration").stdout.strip()
        if observed != next_generation:
            raise RuntimeError("Outcome Ledger generation bump did not persist")

    if ready_hook:
        with open(ready_hook, "x", encoding="utf-8") as handle:
            handle.write("ready\n")
        deadline = time.monotonic() + 10
        while not os.path.exists(continue_hook):
            if time.monotonic() >= deadline:
                raise RuntimeError("rotation selftest continuation timed out")
            time.sleep(0.01)

    if not source_was_present:
        os.fsync(source_directory)
        if not same_directory:
            os.fsync(target_directory)
        print("absent\t0\t")
        raise SystemExit(0)

    info = os.fstat(descriptor)
    path_info = os.stat(source_name, dir_fd=source_directory, follow_symlinks=False)
    validate_event_file(info, path_info)
    digest = hashlib.sha256()
    size = 0
    while chunk := os.read(descriptor, 1024 * 1024):
        digest.update(chunk)
        size += len(chunk)
        if size > maximum_event_bytes:
            raise RuntimeError("Outcome Ledger exceeded its size bound while hashing")
    final_descriptor_info = os.fstat(descriptor)
    final_path_info = os.stat(source_name, dir_fd=source_directory, follow_symlinks=False)
    validate_event_file(final_descriptor_info, final_path_info)
    if (
        (info.st_dev, info.st_ino, info.st_size)
        != (final_descriptor_info.st_dev, final_descriptor_info.st_ino, final_descriptor_info.st_size)
        or size != info.st_size
    ):
        raise RuntimeError("Outcome Ledger changed while its rotation digest was computed")
    os.rename(
        source_name,
        target_name,
        src_dir_fd=source_directory,
        dst_dir_fd=target_directory,
    )
    renamed = True
    renamed_descriptor_info = os.fstat(descriptor)
    renamed_info = os.stat(target_name, dir_fd=target_directory, follow_symlinks=False)
    validate_event_file(renamed_descriptor_info, renamed_info)
    os.fsync(source_directory)
    if not same_directory:
        os.fsync(target_directory)
    print(f"rotated\t{size}\t{digest.hexdigest()}")
except SystemExit:
    raise
except BaseException as failure:
    recovery_errors = []
    if renamed:
        try:
            os.rename(
                target_name,
                source_name,
                src_dir_fd=target_directory,
                dst_dir_fd=source_directory,
            )
            os.fsync(source_directory)
            if not same_directory:
                os.fsync(target_directory)
        except BaseException as recovery_failure:
            recovery_errors.append(f"event restore failed: {recovery_failure}")
    if generation_changed:
        try:
            restore_generation()
        except BaseException as recovery_failure:
            recovery_errors.append(f"generation restore failed: {recovery_failure}")
    if recovery_errors:
        raise RuntimeError(
            "Outcome Ledger rotation recovery incomplete: " + "; ".join(recovery_errors)
        ) from failure
    raise
finally:
    if descriptor is not None:
        os.close(descriptor)
    os.close(target_directory)
    os.close(source_directory)
PY
}

restore_event_rotation() {
  local event_file="$1" pending_file="$2" failed_file="$3" previous_state="$4"
  tilde_python_isolated - \
    "$event_file" "$pending_file" "$failed_file" "$previous_state" <<'PY'
import fcntl
import os
import stat
import sys

event_file, pending_file, failed_file, previous_state = sys.argv[1:]
if previous_state not in {"rotated", "absent", "unknown"}:
    raise SystemExit("invalid previous Outcome Ledger state")
event_directory_path = os.path.dirname(event_file)
run_directory_path = os.path.dirname(pending_file)
if os.path.dirname(failed_file) != run_directory_path:
    raise SystemExit("Outcome Ledger rollback targets must share the run directory")
event_name = os.path.basename(event_file)
pending_name = os.path.basename(pending_file)
failed_name = os.path.basename(failed_file)
directory_flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC
event_directory = os.open(event_directory_path, directory_flags)
opened_run_directory = os.open(run_directory_path, directory_flags)
event_directory_identity = os.fstat(event_directory)
opened_run_identity = os.fstat(opened_run_directory)
same_directory = (
    event_directory_identity.st_dev,
    event_directory_identity.st_ino,
) == (opened_run_identity.st_dev, opened_run_identity.st_ino)
if same_directory:
    os.close(opened_run_directory)
    run_directory = os.dup(event_directory)
else:
    run_directory = opened_run_directory
opened_files = []
maximum_event_bytes = 64 * 1024 * 1024

def validate_directory(descriptor: int, path: str) -> None:
    info = os.fstat(descriptor)
    path_info = os.stat(path, follow_symlinks=False)
    if (
        not stat.S_ISDIR(info.st_mode)
        or not stat.S_ISDIR(path_info.st_mode)
        or info.st_uid != os.getuid()
        or path_info.st_uid != os.getuid()
        or info.st_nlink < 1
        or path_info.st_nlink < 1
        or stat.S_IMODE(info.st_mode) != 0o700
        or stat.S_IMODE(path_info.st_mode) != 0o700
        or (info.st_dev, info.st_ino) != (path_info.st_dev, path_info.st_ino)
    ):
        raise RuntimeError("refusing unsafe Outcome Ledger rollback directory")

def open_optional(directory: int, name: str):
    try:
        descriptor = os.open(
            name,
            os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW | os.O_CLOEXEC,
            dir_fd=directory,
        )
    except FileNotFoundError:
        return None
    info = os.fstat(descriptor)
    path_info = os.stat(name, dir_fd=directory, follow_symlinks=False)
    if (
        not stat.S_ISREG(info.st_mode)
        or not stat.S_ISREG(path_info.st_mode)
        or info.st_uid != os.getuid()
        or path_info.st_uid != os.getuid()
        or info.st_nlink != 1
        or path_info.st_nlink != 1
        or stat.S_IMODE(info.st_mode) != 0o600
        or stat.S_IMODE(path_info.st_mode) != 0o600
        or info.st_size > maximum_event_bytes
        or path_info.st_size > maximum_event_bytes
        or (info.st_dev, info.st_ino) != (path_info.st_dev, path_info.st_ino)
    ):
        os.close(descriptor)
        raise RuntimeError("refusing unsafe Outcome Ledger rollback file")
    fcntl.flock(descriptor, fcntl.LOCK_EX)
    opened_files.append(descriptor)
    return info

try:
    validate_directory(event_directory, event_directory_path)
    validate_directory(run_directory, run_directory_path)
    fcntl.flock(event_directory, fcntl.LOCK_EX)
    if not same_directory:
        fcntl.flock(run_directory, fcntl.LOCK_EX)
    validate_directory(event_directory, event_directory_path)
    validate_directory(run_directory, run_directory_path)
    try:
        os.stat(failed_name, dir_fd=run_directory, follow_symlinks=False)
    except FileNotFoundError:
        pass
    else:
        raise RuntimeError("failed-run Outcome Ledger recovery target already exists")
    current_info = open_optional(event_directory, event_name)
    pending_info = open_optional(run_directory, pending_name)
    if previous_state == "rotated" and pending_info is None:
        raise RuntimeError("previous Outcome Ledger is missing during rollback")
    if previous_state == "absent" and pending_info is not None:
        raise RuntimeError("unexpected previous Outcome Ledger during rollback")
    if current_info is not None:
        os.rename(
            event_name,
            failed_name,
            src_dir_fd=event_directory,
            dst_dir_fd=run_directory,
        )
        failed_info = os.stat(failed_name, dir_fd=run_directory, follow_symlinks=False)
        if (current_info.st_dev, current_info.st_ino) != (
            failed_info.st_dev, failed_info.st_ino
        ):
            raise RuntimeError("failed-run Outcome Ledger identity changed")
    if pending_info is not None:
        os.rename(
            pending_name,
            event_name,
            src_dir_fd=run_directory,
            dst_dir_fd=event_directory,
        )
        restored_info = os.stat(event_name, dir_fd=event_directory, follow_symlinks=False)
        if (pending_info.st_dev, pending_info.st_ino) != (
            restored_info.st_dev, restored_info.st_ino
        ):
            raise RuntimeError("restored Outcome Ledger identity changed")
    os.fsync(event_directory)
    os.fsync(run_directory)
finally:
    for descriptor in reversed(opened_files):
        os.close(descriptor)
    os.close(run_directory)
    os.close(event_directory)
PY
}

finalize_previous_events() {
  local pending="$1" archived="$2" disposition="$3"
  tilde_python_isolated - "$pending" "$archived" "$disposition" <<'PY'
import fcntl
import os
import stat
import sys

pending, archived, disposition = sys.argv[1:]
if disposition not in {"archive", "delete"}:
    raise SystemExit("invalid previous Outcome Ledger disposition")
if not os.path.isabs(pending) or os.path.dirname(pending) != os.path.dirname(archived):
    raise SystemExit("previous Outcome Ledger paths must share one absolute directory")
parent = os.path.dirname(pending)
pending_name = os.path.basename(pending)
archived_name = os.path.basename(archived)
directory = os.open(
    parent,
    os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC,
)
descriptor = None
try:
    directory_info = os.fstat(directory)
    path_directory_info = os.stat(parent, follow_symlinks=False)
    if (
        not stat.S_ISDIR(directory_info.st_mode)
        or not stat.S_ISDIR(path_directory_info.st_mode)
        or directory_info.st_uid != os.getuid()
        or path_directory_info.st_uid != os.getuid()
        or directory_info.st_nlink < 1
        or path_directory_info.st_nlink < 1
        or stat.S_IMODE(directory_info.st_mode) != 0o700
        or stat.S_IMODE(path_directory_info.st_mode) != 0o700
        or (directory_info.st_dev, directory_info.st_ino)
            != (path_directory_info.st_dev, path_directory_info.st_ino)
    ):
        raise RuntimeError("refusing unsafe F03 run directory")
    fcntl.flock(directory, fcntl.LOCK_EX)
    if disposition == "archive":
        try:
            os.stat(archived_name, dir_fd=directory, follow_symlinks=False)
        except FileNotFoundError:
            pass
        else:
            raise RuntimeError("previous Outcome Ledger archive already exists")
    try:
        descriptor = os.open(
            pending_name,
            os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW | os.O_CLOEXEC,
            dir_fd=directory,
        )
    except FileNotFoundError:
        raise SystemExit(0)
    info = os.fstat(descriptor)
    path_info = os.stat(pending_name, dir_fd=directory, follow_symlinks=False)
    if (
        not stat.S_ISREG(info.st_mode)
        or not stat.S_ISREG(path_info.st_mode)
        or info.st_uid != os.getuid()
        or path_info.st_uid != os.getuid()
        or info.st_nlink != 1
        or path_info.st_nlink != 1
        or stat.S_IMODE(info.st_mode) != 0o600
        or stat.S_IMODE(path_info.st_mode) != 0o600
        or info.st_size > 64 * 1024 * 1024
        or path_info.st_size > 64 * 1024 * 1024
        or (info.st_dev, info.st_ino) != (path_info.st_dev, path_info.st_ino)
    ):
        raise RuntimeError("refusing unsafe previous Outcome Ledger artifact")
    fcntl.flock(descriptor, fcntl.LOCK_EX)
    if disposition == "archive":
        os.rename(
            pending_name,
            archived_name,
            src_dir_fd=directory,
            dst_dir_fd=directory,
        )
        archived_info = os.stat(
            archived_name, dir_fd=directory, follow_symlinks=False
        )
        final_descriptor_info = os.fstat(descriptor)
        if (
            (final_descriptor_info.st_dev, final_descriptor_info.st_ino)
                != (archived_info.st_dev, archived_info.st_ino)
            or archived_info.st_uid != os.getuid()
            or archived_info.st_nlink != 1
            or stat.S_IMODE(archived_info.st_mode) != 0o600
        ):
            raise RuntimeError("previous Outcome Ledger archive identity changed")
    else:
        final_info = os.stat(pending_name, dir_fd=directory, follow_symlinks=False)
        final_descriptor_info = os.fstat(descriptor)
        if (
            (final_descriptor_info.st_dev, final_descriptor_info.st_ino)
                != (final_info.st_dev, final_info.st_ino)
            or final_info.st_uid != os.getuid()
            or final_info.st_nlink != 1
            or stat.S_IMODE(final_info.st_mode) != 0o600
        ):
            raise RuntimeError("previous Outcome Ledger identity changed before deletion")
        os.unlink(pending_name, dir_fd=directory)
    os.fsync(directory)
finally:
    if descriptor is not None:
        os.close(descriptor)
    os.close(directory)
PY
}

move_bundle_exclusive() {
  local source="$1" target="$2"
  tilde_python_isolated - \
    "$source" "$target" "$BUNDLE_MOVE_TEST_READY" "$BUNDLE_MOVE_TEST_CONTINUE" <<'PY'
import ctypes
import errno
import os
import stat
import sys
import time

source, target, test_ready, test_continue = sys.argv[1:]
if (
    not os.path.isabs(source)
    or not os.path.isabs(target)
    or os.path.normpath(source) != source
    or os.path.normpath(target) != target
    or source == os.sep
    or target == os.sep
    or source == target
):
    raise SystemExit("bundle transition requires distinct normalized absolute paths")
if bool(test_ready) != bool(test_continue):
    raise SystemExit("bundle transition selftest requires both barrier paths")

source_parent_path = os.path.dirname(source)
target_parent_path = os.path.dirname(target)
source_name = os.path.basename(source)
target_name = os.path.basename(target)
directory_flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC
if test_ready:
    for barrier in (test_ready, test_continue):
        if (
            not os.path.isabs(barrier)
            or os.path.normpath(barrier) != barrier
            or os.path.dirname(barrier) != source_parent_path
            or source_parent_path != target_parent_path
            or not os.path.basename(barrier).startswith("bundle-move-")
        ):
            raise SystemExit("bundle transition selftest barrier is outside its fixture")


def identity(info):
    return (info.st_dev, info.st_ino)


def validate_parent_mode(info):
    mode = stat.S_IMODE(info.st_mode)
    current_user_safe = info.st_uid == os.getuid() and not (mode & 0o022)
    root_safe = info.st_uid == 0 and (
        not (mode & 0o002) or bool(mode & stat.S_ISVTX)
    )
    if not stat.S_ISDIR(info.st_mode) or not (current_user_safe or root_safe):
        raise RuntimeError("bundle transition has an unsafe parent directory")


def open_parent_chain(path):
    components = [component for component in path.split(os.sep) if component]
    root = os.open(os.sep, directory_flags)
    descriptors = [root]
    chain = []
    try:
        root_info = os.fstat(root)
        root_visible = os.stat(os.sep, follow_symlinks=False)
        validate_parent_mode(root_info)
        if identity(root_info) != identity(root_visible):
            raise RuntimeError("bundle transition root identity changed")
        chain.append((root, None, None, root_info))
        parent = root
        for component in components:
            child = os.open(component, directory_flags, dir_fd=parent)
            descriptors.append(child)
            info = os.fstat(child)
            visible = os.stat(component, dir_fd=parent, follow_symlinks=False)
            validate_parent_mode(info)
            if not stat.S_ISDIR(visible.st_mode) or identity(info) != identity(visible):
                raise RuntimeError("bundle transition parent identity changed")
            chain.append((child, parent, component, info))
            parent = child
        return chain
    except BaseException:
        for descriptor in reversed(descriptors):
            os.close(descriptor)
        raise


def verify_parent_chain(chain):
    for descriptor, parent, component, initial in chain:
        current = os.fstat(descriptor)
        visible = (
            os.stat(os.sep, follow_symlinks=False)
            if parent is None
            else os.stat(component, dir_fd=parent, follow_symlinks=False)
        )
        validate_parent_mode(current)
        if (
            not stat.S_ISDIR(visible.st_mode)
            or identity(initial) != identity(current)
            or identity(initial) != identity(visible)
            or initial.st_uid != current.st_uid
            or initial.st_uid != visible.st_uid
            or stat.S_IMODE(initial.st_mode) != stat.S_IMODE(current.st_mode)
            or stat.S_IMODE(initial.st_mode) != stat.S_IMODE(visible.st_mode)
        ):
            raise RuntimeError("bundle transition parent chain changed")


source_chain = open_parent_chain(source_parent_path)
target_chain = None
source_descriptor = None
try:
    target_chain = open_parent_chain(target_parent_path)
    source_parent = source_chain[-1][0]
    target_parent = target_chain[-1][0]
    source_descriptor = os.open(source_name, directory_flags, dir_fd=source_parent)
    source_info = os.fstat(source_descriptor)
    source_visible = os.stat(
        source_name, dir_fd=source_parent, follow_symlinks=False
    )
    source_mode = stat.S_IMODE(source_info.st_mode)
    if (
        not stat.S_ISDIR(source_info.st_mode)
        or not stat.S_ISDIR(source_visible.st_mode)
        or source_info.st_uid != os.getuid()
        or source_visible.st_uid != os.getuid()
        or source_mode & 0o022
        or stat.S_IMODE(source_visible.st_mode) != source_mode
        or identity(source_info) != identity(source_visible)
    ):
        raise RuntimeError("refusing unsafe source bundle identity")

    try:
        os.stat(target_name, dir_fd=target_parent, follow_symlinks=False)
    except FileNotFoundError:
        pass
    else:
        raise FileExistsError(errno.EEXIST, "bundle transition target exists", target)

    if test_ready:
        ready_descriptor = os.open(
            os.path.basename(test_ready),
            os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC,
            0o600,
            dir_fd=source_parent,
        )
        try:
            os.write(ready_descriptor, b"ready\n")
            os.fsync(ready_descriptor)
        finally:
            os.close(ready_descriptor)
        os.fsync(source_parent)
        deadline = time.monotonic() + 5.0
        while True:
            try:
                continuation = os.stat(
                    os.path.basename(test_continue),
                    dir_fd=source_parent,
                    follow_symlinks=False,
                )
                if (
                    not stat.S_ISREG(continuation.st_mode)
                    or continuation.st_uid != os.getuid()
                    or stat.S_IMODE(continuation.st_mode) & 0o022
                ):
                    raise RuntimeError("unsafe bundle transition selftest continuation")
                break
            except FileNotFoundError:
                if time.monotonic() >= deadline:
                    raise RuntimeError("bundle transition selftest continuation timed out")
                time.sleep(0.01)

    verify_parent_chain(source_chain)
    verify_parent_chain(target_chain)
    final_source_visible = os.stat(
        source_name, dir_fd=source_parent, follow_symlinks=False
    )
    final_source_info = os.fstat(source_descriptor)
    if (
        identity(source_info) != identity(final_source_info)
        or identity(source_info) != identity(final_source_visible)
        or source_info.st_uid != final_source_info.st_uid
        or source_mode != stat.S_IMODE(final_source_info.st_mode)
    ):
        raise RuntimeError("source bundle changed before exclusive transition")

    libc = ctypes.CDLL(None, use_errno=True)
    renameatx_np = libc.renameatx_np
    renameatx_np.argtypes = [
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_uint,
    ]
    renameatx_np.restype = ctypes.c_int
    flags = 0x00000004 | 0x00000010  # RENAME_EXCL | RENAME_NOFOLLOW_ANY
    if renameatx_np(
        source_parent,
        os.fsencode(source_name),
        target_parent,
        os.fsencode(target_name),
        flags,
    ) != 0:
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error), target)

    os.fsync(source_parent)
    if identity(os.fstat(source_parent)) != identity(os.fstat(target_parent)):
        os.fsync(target_parent)

    try:
        os.stat(source_name, dir_fd=source_parent, follow_symlinks=False)
    except FileNotFoundError:
        pass
    else:
        raise RuntimeError("source bundle remained after exclusive transition")
    target_info = os.stat(
        target_name, dir_fd=target_parent, follow_symlinks=False
    )
    held_source_info = os.fstat(source_descriptor)
    if (
        not stat.S_ISDIR(target_info.st_mode)
        or identity(source_info) != identity(held_source_info)
        or identity(source_info) != identity(target_info)
        or source_info.st_uid != target_info.st_uid
        or source_mode != stat.S_IMODE(target_info.st_mode)
    ):
        raise RuntimeError("exclusive bundle transition changed source identity")
    verify_parent_chain(source_chain)
    verify_parent_chain(target_chain)
finally:
    if source_descriptor is not None:
        os.close(source_descriptor)
    if target_chain is not None:
        for descriptor, _, _, _ in reversed(target_chain):
            os.close(descriptor)
    for descriptor, _, _, _ in reversed(source_chain):
        os.close(descriptor)
PY
}

backup_bundle_for_transaction() {
  local installed="$1" backup="$2"
  if [[ ! -e "$installed" && ! -L "$installed" ]]; then
    printf 'absent'
    return 0
  fi
  move_bundle_exclusive "$installed" "$backup"
  printf 'present'
}

restore_bundle_after_failure() {
  local installed="$1" backup="$2" failed="$3"
  quarantine_installed_bundle "$installed" "$failed"
  restore_backup_bundle "$installed" "$backup"
}

quarantine_installed_bundle() {
  local installed="$1" failed="$2"
  if [[ -e "$installed" || -L "$installed" ]]; then
    move_bundle_exclusive "$installed" "$failed"
  fi
}

restore_backup_bundle() {
  local installed="$1" backup="$2"
  if [[ -e "$backup" || -L "$backup" ]]; then
    move_bundle_exclusive "$backup" "$installed"
  fi
}

restore_bundle_state() {
  local installed="$1" backup="$2" failed="$3" previous_state="$4"
  local backup_completed="${5:-0}"
  [[ "$previous_state" == "present" || "$previous_state" == "absent" ]] \
    || { echo "unknown prior bundle state" >&2; return 1; }
  [[ "$backup_completed" == "0" || "$backup_completed" == "1" ]] \
    || { echo "unknown bundle backup completion state" >&2; return 1; }
  [[ ! -L "$installed" && ! -L "$backup" && ! -L "$failed" ]] \
    || { echo "refusing linked bundle transaction state" >&2; return 1; }
  if [[ "$previous_state" == "present" ]]; then
    if [[ -e "$backup" ]]; then
      quarantine_installed_bundle "$installed" "$failed"
      restore_backup_bundle "$installed" "$backup"
    elif [[ "$backup_completed" == "1" || ! -e "$installed" ]]; then
      echo "prior bundle and its transaction backup are both missing" >&2
      return 1
    fi
    [[ -e "$installed" && ! -e "$backup" ]]
  else
    [[ ! -e "$backup" ]] \
      || { echo "unexpected backup exists for a previously absent bundle" >&2; return 1; }
    quarantine_installed_bundle "$installed" "$failed"
    [[ ! -e "$installed" ]]
  fi
}

generation_restore_action() {
  local was_present="$1" previous="$2"
  if [[ "$was_present" == "1" ]]; then
    printf 'write\t%s\n' "$previous"
  else
    printf 'delete\n'
  fi
}

restore_generation() {
  local domain="$1" was_present="$2" previous="$3"
  if [[ "$was_present" == "1" ]]; then
    /usr/bin/defaults write "$domain" OutcomeLedgerGeneration -int "$previous"
    [[ "$(/usr/bin/defaults read "$domain" OutcomeLedgerGeneration)" == "$previous" ]] \
      || { echo "previous Outcome Ledger generation did not persist" >&2; return 1; }
  else
    /usr/bin/defaults delete "$domain" OutcomeLedgerGeneration >/dev/null 2>&1 || true
    if /usr/bin/defaults read "$domain" OutcomeLedgerGeneration >/dev/null 2>&1; then
      echo "new Outcome Ledger generation remained after rollback" >&2
      return 1
    fi
  fi
}

next_unused_outcome_generation() {
  local domain="$1" current="$2" maximum_attempts="${3:-4096}" candidate attempts=0
  local maximum=2147483647
  [[ "$current" == "0" || "$current" =~ ^[1-9][0-9]*$ ]] \
    || { echo "Outcome Ledger generation is not a canonical nonnegative integer" >&2; return 1; }
  [[ ${#current} -le 10 && "$current" -lt "$maximum" ]] \
    || { echo "Outcome Ledger generation has no supported successor" >&2; return 1; }
  [[ "$maximum_attempts" =~ ^[1-9][0-9]*$ && "$maximum_attempts" -le 4096 ]] \
    || { echo "Outcome Ledger generation probe bound is invalid" >&2; return 1; }
  candidate=$((current + 1))
  while [[ "$candidate" -le "$maximum" && "$attempts" -lt "$maximum_attempts" ]]; do
    if ! "$DEFAULTS_COMMAND" read \
        "$domain" "OutcomeLedgerWriteCounts.$candidate" >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return 0
    fi
    candidate=$((candidate + 1))
    attempts=$((attempts + 1))
  done
  echo "no unused Outcome Ledger generation was found within the bounded scan" >&2
  return 1
}

verify_installed_plist() {
  local expected="$1" installed="$2" key
  [[ "$(sha256 "$installed")" == "$(sha256 "$expected")" ]] \
    || { echo "installed Info.plist bytes differ from the candidate" >&2; return 1; }
  for key in \
    TildeSourceCommit \
    TildeSourceTree \
    TildeSourceSnapshotSHA256 \
    TildeSourceState \
    TildeEvidenceClass \
    TildeAppleToolchainSHA256 \
    TildeXcodeVersion \
    TildeXcodeBuild \
    TildeSwiftVersionSHA256 \
    TildeSwiftExecutableSHA256 \
    TildeMacOSSDKVersion \
    TildeMacOSSDKBuild \
    TildeMacOSSDKSettingsSHA256 \
    TildeApprovedHelperInputSHA256 \
    TildeApprovedHelperTeamIdentifier; do
    [[ "$(plist_value "$key" "$installed")" == "$(plist_value "$key" "$expected")" ]] \
      || { echo "installed provenance mismatch: $key" >&2; return 1; }
  done
}

verify_critical_file_invariants() {
  tilde_python_isolated - "$@" <<'PY'
import fcntl
import hashlib
import os
import stat
import sys

if len(sys.argv) != 19:
    raise SystemExit(
        "critical-file validation requires six path/digest/mode triples"
    )

records = [tuple(sys.argv[index:index + 3]) for index in range(1, 19, 3)]
for index, (path, expected_sha, expected_mode_text) in enumerate(records):
    if not os.path.isabs(path):
        raise SystemExit("critical-file path must be absolute")
    if len(expected_sha) != 64 or any(
        character not in "0123456789abcdef" for character in expected_sha
    ):
        raise SystemExit("critical-file digest must be lowercase SHA-256")
    if not expected_mode_text.isdigit() or any(
        character not in "01234567" for character in expected_mode_text
    ):
        raise SystemExit("critical-file mode must be an exact octal token")
    expected_mode = int(expected_mode_text, 8)
    if expected_mode & 0o022:
        raise SystemExit("critical-file expected mode may not be group/world writable")
    if index == len(records) - 1 and expected_mode != 0o600:
        raise RuntimeError("F03 model must be an exact owner-only 0600 file")

    parent_path = os.path.dirname(path)
    components = [component for component in parent_path.split(os.sep) if component]
    directory_descriptors = [
        os.open(
            os.sep,
            os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC,
        )
    ]
    directory_identities = []
    current_path = os.sep
    descriptor = None
    try:
        root_info = os.fstat(directory_descriptors[0])
        root_visible = os.stat(os.sep, follow_symlinks=False)
        directory_identities.append((os.sep, root_info))
        if (
            not stat.S_ISDIR(root_info.st_mode)
            or root_info.st_uid != 0
            or stat.S_IMODE(root_info.st_mode) & 0o022
            or (root_info.st_dev, root_info.st_ino)
                != (root_visible.st_dev, root_visible.st_ino)
        ):
            raise RuntimeError("critical F03 input has an unsafe root directory")
        for component in components:
            parent_descriptor = directory_descriptors[-1]
            child = os.open(
                component,
                os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC,
                dir_fd=parent_descriptor,
            )
            directory_descriptors.append(child)
            info = os.fstat(child)
            visible = os.stat(
                component, dir_fd=parent_descriptor, follow_symlinks=False
            )
            current_path = os.path.join(current_path, component)
            mode = stat.S_IMODE(info.st_mode)
            current_user_safe = info.st_uid == os.getuid() and not (mode & 0o022)
            root_safe = info.st_uid == 0 and (
                not (mode & 0o002) or bool(mode & stat.S_ISVTX)
            )
            if (
                not stat.S_ISDIR(info.st_mode)
                or not stat.S_ISDIR(visible.st_mode)
                or not (current_user_safe or root_safe)
                or (info.st_dev, info.st_ino) != (visible.st_dev, visible.st_ino)
            ):
                raise RuntimeError("critical F03 input has an unsafe parent chain")
            directory_identities.append((current_path, info))

        descriptor = os.open(
            os.path.basename(path),
            os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW | os.O_CLOEXEC,
            dir_fd=directory_descriptors[-1],
        )
        info = os.fstat(descriptor)
        visible = os.stat(
            os.path.basename(path),
            dir_fd=directory_descriptors[-1],
            follow_symlinks=False,
        )
        mode = stat.S_IMODE(info.st_mode)
        if (
            not stat.S_ISREG(info.st_mode)
            or not stat.S_ISREG(visible.st_mode)
            or info.st_uid != os.getuid()
            or visible.st_uid != os.getuid()
            or info.st_nlink != 1
            or visible.st_nlink != 1
            or mode != expected_mode
            or (info.st_dev, info.st_ino) != (visible.st_dev, visible.st_ino)
        ):
            raise RuntimeError("critical F03 input has unsafe file invariants")
        flags = fcntl.fcntl(descriptor, fcntl.F_GETFL)
        fcntl.fcntl(descriptor, fcntl.F_SETFL, flags & ~os.O_NONBLOCK)
        digest = hashlib.sha256()
        size = 0
        while chunk := os.read(descriptor, 1024 * 1024):
            digest.update(chunk)
            size += len(chunk)
        final = os.fstat(descriptor)
        final_visible = os.stat(
            os.path.basename(path),
            dir_fd=directory_descriptors[-1],
            follow_symlinks=False,
        )
        if (
            digest.hexdigest() != expected_sha
            or size != info.st_size
            or (info.st_dev, info.st_ino, info.st_size, info.st_nlink, mode)
            != (
                final.st_dev,
                final.st_ino,
                final.st_size,
                final.st_nlink,
                stat.S_IMODE(final.st_mode),
            )
            or (info.st_dev, info.st_ino)
                != (final_visible.st_dev, final_visible.st_ino)
        ):
            raise RuntimeError("critical F03 input changed during validation")
        for directory_path, initial in directory_identities:
            final_directory = os.stat(directory_path, follow_symlinks=False)
            if (
                not stat.S_ISDIR(final_directory.st_mode)
                or (initial.st_dev, initial.st_ino, initial.st_uid,
                    stat.S_IMODE(initial.st_mode))
                    != (final_directory.st_dev, final_directory.st_ino,
                        final_directory.st_uid, stat.S_IMODE(final_directory.st_mode))
            ):
                raise RuntimeError("critical F03 parent chain changed during validation")
    finally:
        if descriptor is not None:
            os.close(descriptor)
        for directory_descriptor in reversed(directory_descriptors):
            os.close(directory_descriptor)
PY
}

validate_receipt_environment() {
  tilde_python_isolated - "$@" <<'PY'
import re
import sys

(
    version,
    build,
    xcode_version,
    xcode_build,
    sdk_version,
    sdk_build,
    os_version,
    os_build,
    architecture,
    hardware_model,
    power_source,
) = sys.argv[1:]

if not re.fullmatch(r"[0-9A-Za-z+._-]{1,128}", version):
    raise SystemExit("bundle version is not receipt-safe")
if not re.fullmatch(r"[0-9]{1,64}", build):
    raise SystemExit("bundle build is not receipt-safe")
for name, value in (
    ("xcodeVersion", xcode_version),
    ("macOSSDKVersion", sdk_version),
):
    if not re.fullmatch(r"[0-9]+(?:[.][0-9]+){1,3}", value):
        raise SystemExit(f"{name} is not receipt-safe")
for name, value in (("xcodeBuild", xcode_build), ("macOSSDKBuild", sdk_build)):
    if not re.fullmatch(r"[A-Za-z0-9]{1,32}", value):
        raise SystemExit(f"{name} is not receipt-safe")
for name, value in (
    ("operatingSystemVersion", os_version),
    ("operatingSystemBuild", os_build),
    ("architecture", architecture),
    ("hardwareModel", hardware_model),
):
    if (
        not 1 <= len(value.encode("utf-8")) <= 128
        or any(ord(character) < 32 or ord(character) > 126 for character in value)
        or "/" in value
        or "\\" in value
    ):
        raise SystemExit(f"{name} is not receipt-safe")
if power_source not in {"ac", "battery", "unknown"}:
    raise SystemExit("power source is not receipt-safe")
PY
}

codesign_team_identifier() {
  local identifiers count identifier
  identifiers="$(
    /usr/bin/codesign --display --verbose=4 "$1" 2>&1 \
      | /usr/bin/awk -F= '/^TeamIdentifier=/ { print $2 }'
  )"
  count="$(printf '%s\n' "$identifiers" | /usr/bin/awk 'NF { count += 1 } END { print count + 0 }')"
  identifier="$(printf '%s\n' "$identifiers" | /usr/bin/awk 'NF { print; exit }')"
  [[ "$count" == "1" && "$identifier" =~ ^[A-Z0-9]{10}$ ]] \
    || { echo "signed artifact has an absent or ambiguous TeamIdentifier: $1" >&2; return 1; }
  printf '%s\n' "$identifier"
}

verify_installed_signing() {
  local app="$1" ime="$2" helper="$3" expected_team="$4"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$app"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$ime"
  /usr/bin/codesign --verify --strict --verbose=2 "$helper"
  [[ "$(codesign_team_identifier "$app")" == "$expected_team" \
      && "$(codesign_team_identifier "$ime")" == "$expected_team" \
      && "$(codesign_team_identifier "$helper")" == "$expected_team" ]] \
    || { echo "installed app/IME/helper signing-team mismatch" >&2; return 1; }
}

verify_registered_apple_toolchain() {
  tilde_capture_apple_swift_toolchain
  [[ "$TILDE_APPLE_TOOLCHAIN_SHA256" == "$APPLE_TOOLCHAIN_SHA256" \
      && "$TILDE_XCODE_VERSION" == "$XCODE_VERSION" \
      && "$TILDE_XCODE_BUILD" == "$XCODE_BUILD" \
      && "$TILDE_XCODE_CDHASH" == "$XCODE_CDHASH" \
      && "$TILDE_SWIFT_VERSION_SHA256" == "$SWIFT_VERSION_SHA256" \
      && "$TILDE_SWIFT_EXECUTABLE_SHA256" == "$SWIFT_EXECUTABLE_SHA256" \
      && "$TILDE_SWIFT_BUILD_EXECUTABLE_SHA256" == "$SWIFT_BUILD_EXECUTABLE_SHA256" \
      && "$TILDE_SWIFT_DRIVER_EXECUTABLE_SHA256" == "$SWIFT_DRIVER_EXECUTABLE_SHA256" \
      && "$TILDE_CLANG_EXECUTABLE_SHA256" == "$CLANG_EXECUTABLE_SHA256" \
      && "$TILDE_LINKER_EXECUTABLE_SHA256" == "$LINKER_EXECUTABLE_SHA256" \
      && "$TILDE_LIBTOOL_EXECUTABLE_SHA256" == "$LIBTOOL_EXECUTABLE_SHA256" \
      && "$TILDE_ARCHIVER_EXECUTABLE_SHA256" == "$ARCHIVER_EXECUTABLE_SHA256" \
      && "$TILDE_MACOS_SDK_VERSION" == "$MACOS_SDK_VERSION" \
      && "$TILDE_MACOS_SDK_BUILD" == "$MACOS_SDK_BUILD" \
      && "$TILDE_MACOS_SDK_SETTINGS_SHA256" == "$MACOS_SDK_SETTINGS_SHA256" ]] \
    || { echo "active Apple Swift toolchain differs from candidate provenance" >&2; return 1; }
}

verify_preview_input_source_registration() {
  verify_registered_apple_toolchain
  /usr/bin/env -i \
    HOME=/var/empty \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin \
    LC_ALL=C \
    DEVELOPER_DIR="$TILDE_DEVELOPER_DIR" \
    TOOLCHAINS=com.apple.dt.toolchain.XcodeDefault \
    SDKROOT="$TILDE_MACOS_SDK_PATH" \
    /usr/bin/xcrun --no-cache --toolchain com.apple.dt.toolchain.XcodeDefault \
      swift - <<'SWIFT'
import Carbon
import Darwin
import Foundation

let expectedIdentifier = "bar.r3d.inputmethod.InlineGhostPreview9B"

func stringProperty(_ key: CFString, of source: TISInputSource) -> String? {
    guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
    return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
}

func booleanProperty(_ key: CFString, of source: TISInputSource) -> Bool {
    guard let pointer = TISGetInputSourceProperty(source, key) else { return false }
    return Unmanaged<CFBoolean>.fromOpaque(pointer).takeUnretainedValue() == kCFBooleanTrue
}

guard let sources = TISCreateInputSourceList(
    [kTISPropertyInputSourceID: expectedIdentifier] as CFDictionary,
    false
)?.takeRetainedValue() as? [TISInputSource],
      sources.count == 1,
      let source = sources.first,
      stringProperty(kTISPropertyInputSourceID, of: source) == expectedIdentifier,
      stringProperty(kTISPropertyBundleID, of: source) == expectedIdentifier,
      booleanProperty(kTISPropertyInputSourceIsEnabled, of: source),
      booleanProperty(kTISPropertyInputSourceIsSelectCapable, of: source) else {
    fputs("exact Preview9B input source is not registered, enabled, and selectable\n", stderr)
    exit(1)
}
SWIFT
  tilde_assert_apple_swift_toolchain_unchanged
}

write_synthetic_receipt_contract() {
  local output="$1"
  tilde_python_isolated - "$output" <<'PY'
import os
import stat
import sys
import tempfile

output = sys.argv[1]
if not os.path.isabs(output) or os.path.basename(output) in {"", ".", ".."}:
    raise SystemExit("synthetic receipt output must be an absolute file path")
parent = os.path.dirname(output)
parent_name = os.path.basename(parent)
parent_info = os.lstat(parent)
resolved_parent = os.path.realpath(parent)
allowed_roots = {
    os.path.realpath("/private/tmp"),
    os.path.realpath(tempfile.gettempdir()),
}
if (
    not parent_name.startswith("tilde-f03-")
    or not stat.S_ISDIR(parent_info.st_mode)
    or parent_info.st_uid != os.getuid()
    or stat.S_IMODE(parent_info.st_mode) != 0o700
    or not any(
        os.path.commonpath([root, resolved_parent]) == root for root in allowed_roots
    )
):
    raise SystemExit(
        "synthetic receipt output requires an owner-only tilde-f03-* test directory"
    )
PY
  atomic_receipt "$output" \
    11111111-1111-1111-1111-111111111111 \
    0000000000000000000000000000000000000000 \
    1111111111111111111111111111111111111111 \
    2222222222222222222222222222222222222222222222222222222222222222 \
    aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
    26.6 17F113 \
    bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb \
    cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc \
    26.5 25F70 \
    eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee \
    e7b0946d81c2342d0d5afd1639dcb8af444c843b4fb50cef5ceeafa302a80546 \
    XG6WL66WUQ \
    9999999999999999999999999999999999999999999999999999999999999999 \
    preview9b-owner-approved-v1 \
    0.1.0-preview9b 123 \
    3333333333333333333333333333333333333333333333333333333333333333 \
    4444444444444444444444444444444444444444444444444444444444444444 \
    e7b0946d81c2342d0d5afd1639dcb8af444c843b4fb50cef5ceeafa302a80546 \
    6666666666666666666666666666666666666666666666666666666666666666 \
    7777777777777777777777777777777777777777777777777777777777777777 \
    2026-08-30T00:00:00Z 2026-08-30T00:01:00Z absent 0 '' 1 \
    XG6WL66WUQ 4171d5fec62a373744ca4f01ec9e2378c092a65f480c039e9c679d910351fda2 \
    5629109312 26.6.2 25G83 arm64 Mac16,7 ac 1 1 \
    >/dev/null
}

run_selftest() {
  local temporary receipt source target result bytes digest expected link hardlink
  local installed backup failed state plist_expected plist_installed
  local installed_parent transaction_parent
  local collision_source collision_target collision_ready collision_continue
  local collision_pid collision_output
  local fake_defaults generation_state critical target_directory ready continue
  local writer_started writer_acquired rotation_output rotation_pid writer_pid selected_generation
  local journal journal_link journal_stale receipt_pending receipt_final wrong_directory
  local receipt_sha pending_receipt_sha
  local race_pending race_final race_ready race_continue race_pid
  local fifo fifo_target fifo_pid fifo_running=0 wrong_mode_directory phase
  local runner_fixture_sha="9999999999999999999999999999999999999999999999999999999999999999"
  local sealed_directory sealed_runner sealed_sha
  local critical_app critical_ime critical_helper critical_app_plist critical_ime_plist model_fixture
  local -a receipt_arguments
  temporary="$(/usr/bin/mktemp -d /private/tmp/tilde-f03-receipt.XXXXXX)"
  receipt="$temporary/receipt.json"
  /bin/chmod 700 "$temporary"
  selftest_maintenance_lock_contention "$temporary"
  sealed_directory="$(/usr/bin/mktemp -d /private/tmp/tilde-f03-runner.XXXXXX)"
  /bin/chmod 700 "$sealed_directory"
  sealed_runner="$sealed_directory/f03_preview_run.sh"
  /bin/cp "$SCRIPT_PATH" "$sealed_runner"
  /bin/chmod 400 "$sealed_runner"
  sealed_sha="$(sha256 "$sealed_runner")"
  assert_sealed_runner_identity "$sealed_runner" "$sealed_sha"
  /bin/chmod 600 "$sealed_runner"
  printf '\n# mutation fixture\n' >>"$sealed_runner"
  /bin/chmod 400 "$sealed_runner"
  if assert_sealed_runner_identity "$sealed_runner" "$sealed_sha" >/dev/null 2>&1; then
    echo "selftest FAIL: mutated sealed runner retained its identity" >&2
    return 1
  fi
  /bin/rm "$sealed_runner"
  /bin/rmdir "$sealed_directory"
  receipt_arguments=(
    11111111-1111-1111-1111-111111111111 \
    0000000000000000000000000000000000000000 \
    1111111111111111111111111111111111111111 \
    2222222222222222222222222222222222222222222222222222222222222222 \
    aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
    26.6 17F113 \
    bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb \
    cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc \
    26.5 25F70 \
    eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee \
    e7b0946d81c2342d0d5afd1639dcb8af444c843b4fb50cef5ceeafa302a80546 \
    XG6WL66WUQ \
    "$runner_fixture_sha" preview9b-owner-approved-v1 \
    0.1.0-preview9b 123 3333333333333333333333333333333333333333333333333333333333333333 \
    4444444444444444444444444444444444444444444444444444444444444444 \
    e7b0946d81c2342d0d5afd1639dcb8af444c843b4fb50cef5ceeafa302a80546 \
    6666666666666666666666666666666666666666666666666666666666666666 \
    7777777777777777777777777777777777777777777777777777777777777777 \
    2026-08-30T00:00:00Z 2026-08-30T00:01:00Z absent 0 '' 1 \
    XG6WL66WUQ 4171d5fec62a373744ca4f01ec9e2378c092a65f480c039e9c679d910351fda2 \
    5629109312 26.6.2 25G83 arm64 Mac16,7 ac 1 1
  )
  receipt_sha="$(atomic_receipt "$receipt" "${receipt_arguments[@]}")"
  [[ "$receipt_sha" == "$(sha256 "$receipt")" ]]
  [[ "$(/usr/bin/stat -f '%Lp' "$receipt")" == "600" ]]
  tilde_python_isolated - "$receipt" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    value = json.load(handle)
assert value["schema"] == "tilde.f03-local-run-receipt.v1"
assert value["sourceState"] == "clean"
assert value["appleToolchainSHA256"] == "a" * 64
assert value["macOSSDKSettingsSHA256"] == "e" * 64
assert value["approvedHelperTeamIdentifier"] == "XG6WL66WUQ"
assert value["runnerSHA256"] == "9" * 64
assert value["invocationProfile"] == "preview9b-owner-approved-v1"
assert value["previousLedgerSHA256"] is None
assert value["inputMethodRegistrationVerified"] is True
assert all("path" not in key.lower() for key in value)
PY
  if atomic_receipt "$receipt" "${receipt_arguments[@]}" >/dev/null 2>&1; then
    echo "selftest FAIL: existing F03 receipt target was replaced" >&2
    return 1
  fi
  receipt_pending="$temporary/receipt-to-finalize.pending.json"
  receipt_final="$temporary/receipt-to-finalize.json"
  pending_receipt_sha="$(atomic_receipt "$receipt_pending" "${receipt_arguments[@]}")"
  finalize_receipt \
    "$receipt_pending" "$receipt_final" \
    11111111-1111-1111-1111-111111111111 \
    "$runner_fixture_sha" preview9b-owner-approved-v1 "$pending_receipt_sha"
  [[ ! -e "$receipt_pending" && -f "$receipt_final" \
      && "$(/usr/bin/stat -f '%Lp' "$receipt_final")" == "600" ]]
  race_pending="$temporary/receipt-race.pending.json"
  race_final="$temporary/receipt-race.json"
  race_ready="$temporary/receipt-race.ready"
  race_continue="$temporary/receipt-race.continue"
  pending_receipt_sha="$(atomic_receipt "$race_pending" "${receipt_arguments[@]}")"
  RECEIPT_TEST_READY="$race_ready"
  RECEIPT_TEST_CONTINUE="$race_continue"
  finalize_receipt \
    "$race_pending" "$race_final" \
    11111111-1111-1111-1111-111111111111 \
    "$runner_fixture_sha" preview9b-owner-approved-v1 "$pending_receipt_sha" \
    >/dev/null 2>&1 &
  race_pid=$!
  for _ in {1..500}; do
    [[ -e "$race_ready" ]] && break
    if ! kill -0 "$race_pid" 2>/dev/null; then
      break
    fi
    /bin/sleep 0.01
  done
  [[ -e "$race_ready" ]]
  printf 'decoy\n' >"$race_final"
  : >"$race_continue"
  if wait "$race_pid"; then
    echo "selftest FAIL: final receipt race replaced an existing target" >&2
    return 1
  fi
  [[ "$(<"$race_final")" == "decoy" && -f "$race_pending" ]]
  RECEIPT_TEST_READY=""
  RECEIPT_TEST_CONTINUE=""
  receipt_pending="$temporary/receipt-tamper.pending.json"
  receipt_final="$temporary/receipt-tamper.json"
  pending_receipt_sha="$(atomic_receipt "$receipt_pending" "${receipt_arguments[@]}")"
  printf ' ' >>"$receipt_pending"
  if finalize_receipt \
      "$receipt_pending" "$receipt_final" \
      11111111-1111-1111-1111-111111111111 \
      "$runner_fixture_sha" preview9b-owner-approved-v1 "$pending_receipt_sha" \
      >/dev/null 2>&1; then
    echo "selftest FAIL: changed pending receipt retained its commit identity" >&2
    return 1
  fi
  [[ -f "$receipt_pending" && ! -e "$receipt_final" ]]
  wrong_directory="$temporary/wrong-receipt-directory"
  /bin/mkdir -m 755 "$wrong_directory"
  if atomic_receipt "$wrong_directory/receipt.json" \
      "${receipt_arguments[@]}" >/dev/null 2>&1; then
    echo "selftest FAIL: non-0700 receipt directory was accepted" >&2
    return 1
  fi
  printf 'decoy\n' >"$temporary/receipt-decoy"
  /bin/ln -s "$temporary/receipt-decoy" "$temporary/.receipt.tmp"
  if atomic_receipt "$temporary/symlink-race-receipt.json" \
      "${receipt_arguments[@]}" >/dev/null 2>&1; then
    echo "selftest FAIL: linked receipt temporary was accepted" >&2
    return 1
  fi
  /bin/rm "$temporary/.receipt.tmp"

  journal="$temporary/.f03-transaction.json"
  write_transaction_journal \
    create "$journal" 11111111-1111-1111-1111-111111111111 prepared \
    "$temporary/run" "$temporary/app-transaction" "$temporary/ime-transaction" \
    1 present absent 0 0 '' "$temporary/final-receipt.json" \
    "$runner_fixture_sha" preview9b-owner-approved-v1
  [[ "$(/usr/bin/stat -f '%Lp' "$journal")" == "600" ]]
  for phase in app-backup-intent ime-backup-intent rotation-intent receipt-finalize-intent; do
    write_transaction_journal \
      update "$journal" 11111111-1111-1111-1111-111111111111 "$phase" \
      "$temporary/run" "$temporary/app-transaction" "$temporary/ime-transaction" \
      1 present absent 1 4 7 "$temporary/final-receipt.json" \
      "$runner_fixture_sha" preview9b-owner-approved-v1
    tilde_python_isolated - "$journal" "$phase" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
assert payload["schema"] == "tilde.f03-maintenance-transaction.v1"
assert payload["phase"] == sys.argv[2]
assert payload["runnerSHA256"] == "9" * 64
assert payload["invocationProfile"] == "preview9b-owner-approved-v1"
assert payload["commitDurable"] is False
PY
  done
  write_transaction_journal \
    update "$journal" 11111111-1111-1111-1111-111111111111 receipt-durable \
    "$temporary/run" "$temporary/app-transaction" "$temporary/ime-transaction" \
    1 present absent 1 4 7 "$temporary/final-receipt.json" \
    "$runner_fixture_sha" preview9b-owner-approved-v1
  tilde_python_isolated - "$journal" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
assert payload["phase"] == "receipt-durable"
assert payload["commitDurable"] is True
PY
  if write_transaction_journal \
      create "$journal" 11111111-1111-1111-1111-111111111111 prepared \
      "$temporary/run" "$temporary/app-transaction" "$temporary/ime-transaction" \
      1 present absent 0 0 '' "$temporary/final-receipt.json" \
      "$runner_fixture_sha" preview9b-owner-approved-v1 >/dev/null 2>&1; then
    echo "selftest FAIL: unfinished transaction journal did not block a new run" >&2
    return 1
  fi
  journal_link="$temporary/journal-hardlink"
  /bin/ln "$journal" "$journal_link"
  if write_transaction_journal \
      update "$journal" 11111111-1111-1111-1111-111111111111 rollback-intent \
      "$temporary/run" "$temporary/app-transaction" "$temporary/ime-transaction" \
      1 present absent 1 4 7 "$temporary/final-receipt.json" \
      "$runner_fixture_sha" preview9b-owner-approved-v1 >/dev/null 2>&1; then
    echo "selftest FAIL: multiply-linked transaction journal was accepted" >&2
    return 1
  fi
  /bin/rm "$journal_link"
  write_transaction_journal \
    update "$journal" 11111111-1111-1111-1111-111111111111 rollback-complete \
    "$temporary/run" "$temporary/app-transaction" "$temporary/ime-transaction" \
    1 present absent 1 4 7 "$temporary/final-receipt.json" \
    "$runner_fixture_sha" preview9b-owner-approved-v1
  remove_transaction_journal \
    "$journal" 11111111-1111-1111-1111-111111111111 rollback-complete
  journal_stale="$temporary/.f03-transaction.tmp"
  printf 'interrupted\n' >"$journal_stale"
  if write_transaction_journal \
      create "$journal" 11111111-1111-1111-1111-111111111111 prepared \
      "$temporary/run" "$temporary/app-transaction" "$temporary/ime-transaction" \
      1 present absent 0 0 '' "$temporary/final-receipt.json" \
      "$runner_fixture_sha" preview9b-owner-approved-v1 >/dev/null 2>&1; then
    echo "selftest FAIL: stale journal temporary did not fail closed" >&2
    return 1
  fi
  /bin/rm "$journal_stale"

  source="$temporary/events.jsonl"
  target="$temporary/previous-events.pending.jsonl"
  printf '{"aggregate":"fixture"}\n' >"$source"
  expected="$(sha256 "$source")"
  IFS=$'\t' read -r result bytes digest < <(rotate_event_file "$source" "$target")
  [[ "$result" == "rotated" && "$bytes" -gt 0 && "$digest" == "$expected" ]]
  [[ ! -e "$source" && -f "$target" && "$(/usr/bin/stat -f '%Lp' "$target")" == "600" ]]
  printf '{"aggregate":"new-run"}\n' >"$source"
  restore_event_rotation \
    "$source" "$target" "$temporary/failed-run-events.jsonl" rotated
  [[ "$(<"$source")" == '{"aggregate":"fixture"}' \
      && "$(<"$temporary/failed-run-events.jsonl")" == '{"aggregate":"new-run"}' \
      && ! -e "$target" ]]

  IFS=$'\t' read -r result bytes digest < <(
    rotate_event_file "$temporary/absent.jsonl" "$temporary/absent-target.jsonl"
  )
  [[ "$result" == "absent" && "$bytes" == "0" && -z "$digest" ]]

  fake_defaults="$temporary/defaults"
  generation_state="$temporary/generation"
  tilde_python_isolated - "$fake_defaults" "$generation_state" <<'PY'
import os
import sys

script, state = sys.argv[1:]
with open(script, "w", encoding="utf-8") as handle:
    handle.write("#!/bin/bash\nset -euo pipefail\n")
    handle.write(f"state={state!r}\n")
    handle.write('key="$3"\n')
    handle.write('target="$state"\n')
    handle.write('[[ "$key" == "OutcomeLedgerGeneration" ]] || target="$state.$key"\n')
    handle.write('case "$1" in\n')
    handle.write('  write) printf "%s\\n" "$5" >"$target" ;;\n')
    handle.write('  read) /bin/cat "$target" ;;\n')
    handle.write('  delete) /bin/rm -f "$target" ;;\n')
    handle.write('  *) exit 2 ;;\n')
    handle.write('esac\n')
os.chmod(script, 0o700)
PY
  printf '4\n' >"$generation_state"
  printf '{}\n' >"$generation_state.OutcomeLedgerWriteCounts.5"
  printf '{}\n' >"$generation_state.OutcomeLedgerWriteCounts.6"
  DEFAULTS_COMMAND="$fake_defaults"
  selected_generation="$(next_unused_outcome_generation test.domain 4)"
  [[ "$selected_generation" == "7" ]]
  printf '{}\n' >"$generation_state.OutcomeLedgerWriteCounts.7"
  if next_unused_outcome_generation test.domain 4 3 >/dev/null 2>&1; then
    echo "selftest FAIL: bounded used-generation scan did not fail closed" >&2
    return 1
  fi
  /bin/rm "$generation_state.OutcomeLedgerWriteCounts.7"
  if next_unused_outcome_generation test.domain 2147483647 >/dev/null 2>&1; then
    echo "selftest FAIL: generation integer overflow was accepted" >&2
    return 1
  fi

  fifo="$temporary/events.fifo"
  fifo_target="$temporary/fifo-target.jsonl"
  /usr/bin/mkfifo "$fifo"
  rotate_event_file "$fifo" "$fifo_target" test.domain 1 4 7 >/dev/null 2>&1 &
  fifo_pid=$!
  fifo_running=1
  for _ in {1..100}; do
    if ! kill -0 "$fifo_pid" 2>/dev/null; then
      fifo_running=0
      break
    fi
    /bin/sleep 0.01
  done
  if [[ "$fifo_running" == "1" ]]; then
    kill -TERM "$fifo_pid" 2>/dev/null || true
    wait "$fifo_pid" 2>/dev/null || true
    echo "selftest FAIL: FIFO Outcome Ledger blocked rotation" >&2
    return 1
  fi
  if wait "$fifo_pid"; then
    echo "selftest FAIL: FIFO Outcome Ledger was accepted" >&2
    return 1
  fi
  [[ "$(<"$generation_state")" == "4" && ! -e "$fifo_target" ]]

  source="$temporary/wrong-mode-events.jsonl"
  printf 'fixture\n' >"$source"
  /bin/chmod 644 "$source"
  if rotate_event_file "$source" "$temporary/wrong-mode-target.jsonl" \
      test.domain 1 4 7 >/dev/null 2>&1; then
    echo "selftest FAIL: non-0600 Outcome Ledger was accepted" >&2
    return 1
  fi
  [[ "$(<"$generation_state")" == "4" ]]

  wrong_mode_directory="$temporary/wrong-mode-outcome"
  /bin/mkdir -m 755 "$wrong_mode_directory"
  source="$wrong_mode_directory/events.jsonl"
  printf 'fixture\n' >"$source"
  /bin/chmod 600 "$source"
  if rotate_event_file "$source" "$temporary/wrong-directory-target.jsonl" \
      test.domain 1 4 7 >/dev/null 2>&1; then
    echo "selftest FAIL: non-0700 Outcome Ledger directory was accepted" >&2
    return 1
  fi
  [[ "$(<"$generation_state")" == "4" ]]

  critical="$temporary/critical"
  target_directory="$temporary/critical-target"
  /bin/mkdir -m 700 "$critical" "$target_directory"
  source="$critical/events.jsonl"
  target="$target_directory/previous-events.pending.jsonl"
  printf 'old\n' >"$source"
  ready="$temporary/rotation-ready"
  continue="$temporary/rotation-continue"
  writer_started="$temporary/writer-started"
  writer_acquired="$temporary/writer-acquired"
  rotation_output="$temporary/rotation-output"
  ROTATION_TEST_READY="$ready"
  ROTATION_TEST_CONTINUE="$continue"
  rotate_event_file \
    "$source" "$target" test.domain 1 4 "$selected_generation" >"$rotation_output" &
  rotation_pid=$!
  for _ in {1..500}; do
    [[ -e "$ready" ]] && break
    /bin/sleep 0.01
  done
  [[ -e "$ready" ]]
  tilde_python_isolated - "$critical" "$source" "$writer_started" "$writer_acquired" <<'PY' &
import fcntl
import os
import sys

directory_path, event_path, started, acquired = sys.argv[1:]
with open(started, "x", encoding="utf-8") as handle:
    handle.write("started\n")
directory = os.open(directory_path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
try:
    fcntl.flock(directory, fcntl.LOCK_EX)
    with open(acquired, "x", encoding="utf-8") as handle:
        handle.write("acquired\n")
    descriptor = os.open(
        event_path,
        os.O_WRONLY | os.O_CREAT | os.O_APPEND | os.O_NOFOLLOW,
        0o600,
    )
    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX)
        os.write(descriptor, b"new\n")
        os.fsync(descriptor)
    finally:
        os.close(descriptor)
finally:
    os.close(directory)
PY
  writer_pid=$!
  for _ in {1..500}; do
    [[ -e "$writer_started" ]] && break
    /bin/sleep 0.01
  done
  [[ -e "$writer_started" && ! -e "$writer_acquired" ]]
  : >"$continue"
  wait "$rotation_pid"
  wait "$writer_pid"
  [[ -e "$writer_acquired" && "$(<"$generation_state")" == "$selected_generation" ]]
  [[ "$(<"$target")" == "old" && "$(<"$source")" == "new" ]]
  [[ "$(<"$rotation_output")" == rotated$'\t'* ]]
  DEFAULTS_COMMAND="/usr/bin/defaults"
  ROTATION_TEST_READY=""
  ROTATION_TEST_CONTINUE=""

  link="$temporary/link.jsonl"
  /bin/ln -s "$target" "$link"
  if rotate_event_file "$link" "$temporary/link-target.jsonl" >/dev/null 2>&1; then
    echo "selftest FAIL: linked Outcome Ledger was accepted" >&2
    return 1
  fi
  hardlink="$temporary/hardlink.jsonl"
  /bin/ln "$target" "$hardlink"
  if rotate_event_file "$hardlink" "$temporary/hardlink-target.jsonl" >/dev/null 2>&1; then
    echo "selftest FAIL: multiply-linked Outcome Ledger was accepted" >&2
    return 1
  fi

  printf 'archive\n' >"$temporary/events-to-archive.pending.jsonl"
  finalize_previous_events \
    "$temporary/events-to-archive.pending.jsonl" \
    "$temporary/events-to-archive.jsonl" archive
  [[ ! -e "$temporary/events-to-archive.pending.jsonl" \
      && "$(<"$temporary/events-to-archive.jsonl")" == "archive" ]]
  printf 'delete\n' >"$temporary/events-to-delete.pending.jsonl"
  finalize_previous_events \
    "$temporary/events-to-delete.pending.jsonl" \
    "$temporary/events-to-delete.jsonl" delete
  [[ ! -e "$temporary/events-to-delete.pending.jsonl" \
      && ! -e "$temporary/events-to-delete.jsonl" ]]

  installed_parent="$temporary/installed-parent"
  transaction_parent="$temporary/transaction-parent"
  /bin/mkdir "$installed_parent" "$transaction_parent"
  installed="$installed_parent/Installed.app"
  backup="$transaction_parent/Backup.app"
  failed="$transaction_parent/Failed.app"
  /bin/mkdir -p "$installed"
  printf 'old\n' >"$installed/version"
  state="$(backup_bundle_for_transaction "$installed" "$backup")"
  [[ "$state" == "present" && ! -e "$installed" && -e "$backup" ]]
  /bin/mkdir -p "$installed"
  printf 'new\n' >"$installed/version"
  restore_bundle_state "$installed" "$backup" "$failed" present 1
  [[ "$(<"$installed/version")" == "old" && "$(<"$failed/version")" == "new" ]]
  /bin/rm -rf "$installed" "$failed"
  state="$(backup_bundle_for_transaction "$installed" "$backup")"
  [[ "$state" == "absent" ]]
  /bin/mkdir -p "$installed"
  restore_bundle_state "$installed" "$backup" "$failed" absent 1
  [[ ! -e "$installed" && -e "$failed" ]]
  /bin/rm -rf "$failed"
  /bin/mkdir -p "$installed"
  if restore_bundle_state "$installed" "$backup" "$failed" present 1 \
      >/dev/null 2>&1; then
    echo "selftest FAIL: completed prior-bundle backup could disappear silently" >&2
    return 1
  fi
  /bin/rm -rf "$installed" "$failed"
  collision_source="$temporary/CollisionSource.app"
  collision_target="$temporary/CollisionTarget.app"
  collision_ready="$temporary/bundle-move-ready"
  collision_continue="$temporary/bundle-move-continue"
  collision_output="$temporary/bundle-move-output"
  /bin/mkdir "$collision_source"
  printf 'source\n' >"$collision_source/version"
  BUNDLE_MOVE_TEST_READY="$collision_ready"
  BUNDLE_MOVE_TEST_CONTINUE="$collision_continue"
  move_bundle_exclusive "$collision_source" "$collision_target" \
    >"$collision_output" 2>&1 &
  collision_pid=$!
  for _ in {1..500}; do
    [[ -e "$collision_ready" ]] && break
    /bin/sleep 0.01
  done
  [[ -e "$collision_ready" ]]
  /bin/mkdir "$collision_target"
  printf 'collision\n' >"$collision_target/version"
  : >"$collision_continue"
  if wait "$collision_pid"; then
    echo "selftest FAIL: bundle target race replaced an existing target" >&2
    return 1
  fi
  /usr/bin/grep -q '\[Errno 17\]' "$collision_output"
  [[ "$(<"$collision_source/version")" == "source" \
      && "$(<"$collision_target/version")" == "collision" ]]
  BUNDLE_MOVE_TEST_READY=""
  BUNDLE_MOVE_TEST_CONTINUE=""
  /bin/rm -rf "$collision_source" "$collision_target"
  /bin/rm -f "$collision_ready" "$collision_continue" "$collision_output"
  [[ "$(generation_restore_action 1 7)" == $'write\t7' ]]
  [[ "$(generation_restore_action 0 0)" == "delete" ]]

  plist_expected="$temporary/expected.plist"
  plist_installed="$temporary/installed.plist"
  tilde_python_isolated - "$plist_expected" <<'PY'
import plistlib, sys
value = {
    "TildeSourceCommit": "0" * 40,
    "TildeSourceTree": "1" * 40,
    "TildeSourceSnapshotSHA256": "2" * 64,
    "TildeSourceState": "clean",
    "TildeEvidenceClass": "decision-grade",
    "TildeAppleToolchainSHA256": "a" * 64,
    "TildeXcodeVersion": "26.6",
    "TildeXcodeBuild": "17F113",
    "TildeSwiftVersionSHA256": "b" * 64,
    "TildeSwiftExecutableSHA256": "c" * 64,
    "TildeMacOSSDKVersion": "26.5",
    "TildeMacOSSDKBuild": "25F70",
    "TildeMacOSSDKSettingsSHA256": "e" * 64,
    "TildeApprovedHelperInputSHA256": "d" * 64,
    "TildeApprovedHelperTeamIdentifier": "TEAMID1234",
}
with open(sys.argv[1], "wb") as handle:
    plistlib.dump(value, handle, sort_keys=True)
PY
  /bin/cp "$plist_expected" "$plist_installed"
  verify_installed_plist "$plist_expected" "$plist_installed"
  /usr/libexec/PlistBuddy -c 'Set :TildeSourceTree 3333333333333333333333333333333333333333' "$plist_installed"
  if verify_installed_plist "$plist_expected" "$plist_installed" >/dev/null 2>&1; then
    echo "selftest FAIL: installed provenance mismatch was accepted" >&2
    return 1
  fi
  critical_app="$temporary/critical-app"
  critical_ime="$temporary/critical-ime"
  critical_helper="$temporary/critical-helper"
  critical_app_plist="$temporary/critical-app.plist"
  critical_ime_plist="$temporary/critical-ime.plist"
  model_fixture="$temporary/model.gguf"
  for critical in \
    "$critical_app" "$critical_ime" "$critical_helper" \
    "$critical_app_plist" "$critical_ime_plist" "$model_fixture"; do
    printf 'fixture\n' >"$critical"
    /bin/chmod 600 "$critical"
  done
  verify_critical_file_invariants \
    "$critical_app" "$(sha256 "$critical_app")" 600 \
    "$critical_ime" "$(sha256 "$critical_ime")" 600 \
    "$critical_helper" "$(sha256 "$critical_helper")" 600 \
    "$critical_app_plist" "$(sha256 "$critical_app_plist")" 600 \
    "$critical_ime_plist" "$(sha256 "$critical_ime_plist")" 600 \
    "$model_fixture" "$(sha256 "$model_fixture")" 600
  /bin/chmod 620 "$critical_helper"
  if verify_critical_file_invariants \
      "$critical_app" "$(sha256 "$critical_app")" 600 \
      "$critical_ime" "$(sha256 "$critical_ime")" 600 \
      "$critical_helper" "$(sha256 "$critical_helper")" 600 \
      "$critical_app_plist" "$(sha256 "$critical_app_plist")" 600 \
      "$critical_ime_plist" "$(sha256 "$critical_ime_plist")" 600 \
      "$model_fixture" "$(sha256 "$model_fixture")" 600 \
      >/dev/null 2>&1; then
    echo "selftest FAIL: group-writable critical artifact was accepted" >&2
    return 1
  fi
  /bin/chmod 600 "$critical_helper"
  validate_receipt_environment \
    0.1.0-preview9b 123 26.6 17F113 26.5 25F70 \
    26.6.2 25G83 arm64 Mac16,7 ac
  if validate_receipt_environment \
      0.1.0-preview9b 123 26.6 17F113 26.5 25F70 \
      26.6.2 25G83 arm64 'unsafe/path' ac >/dev/null 2>&1; then
    echo "selftest FAIL: unsafe receipt environment token was accepted" >&2
    return 1
  fi
  /bin/rm -rf "$temporary"
  echo "selftest OK: F03 receipt/rotation/rollback is locked, atomic, owner-only, path-free, and link-safe"
}

if [[ -n "$SELFTEST_RECEIPT_OUTPUT" ]]; then
  [[ "$SELFTEST" == "0" && "$OWNER_APPROVED" == "0" \
      && -z "$CANDIDATE" && -z "$PREVIOUS_LEDGER" ]] \
    || { echo "--selftest-write-receipt cannot be combined with maintenance arguments" >&2; exit 2; }
  write_synthetic_receipt_contract "$SELFTEST_RECEIPT_OUTPUT"
  exit 0
fi

if [[ "$SELFTEST" == "1" ]]; then
  [[ "$OWNER_APPROVED" == "0" && -z "$CANDIDATE" && -z "$PREVIOUS_LEDGER" \
      && -z "$SELFTEST_RECEIPT_OUTPUT" ]] \
    || { echo "--selftest cannot be combined with maintenance arguments" >&2; exit 2; }
  run_selftest
  exit 0
fi

[[ "$OWNER_APPROVED" == "1" ]] || {
  echo "refusing install/rotation: --owner-approved is required for this maintenance window" >&2
  exit 2
}
[[ "$PREVIOUS_LEDGER" == "archive" || "$PREVIOUS_LEDGER" == "delete" ]] || {
  echo "--previous-ledger must explicitly choose archive or delete" >&2
  exit 2
}
[[ -d "$CANDIDATE" ]] || { echo "missing candidate app: $CANDIDATE" >&2; exit 2; }
CANDIDATE="$(cd "$(/usr/bin/dirname "$CANDIDATE")" && pwd -P)/$(/usr/bin/basename "$CANDIDATE")"
[[ ! -L "$CANDIDATE" ]] || { echo "refusing linked candidate app" >&2; exit 1; }

APP_PLIST="$CANDIDATE/Contents/Info.plist"
EMBEDDED_IME="$CANDIDATE/Contents/Library/InlineGhostIME.app"
IME_PLIST="$EMBEDDED_IME/Contents/Info.plist"
[[ "$(plist_value CFBundleIdentifier "$APP_PLIST")" == "bar.r3d.tilde.preview9b" ]]
[[ "$(plist_value TildeProductProfile "$APP_PLIST")" == "preview-9b" ]]
[[ "$(plist_value CFBundleIdentifier "$IME_PLIST")" == "bar.r3d.inputmethod.InlineGhostPreview9B" ]]
[[ "$(plist_value TildeProductProfile "$IME_PLIST")" == "preview-9b" ]]
for key in \
  TildeSourceCommit TildeSourceTree TildeSourceSnapshotSHA256 \
  TildeSourceState TildeEvidenceClass TildeAppleToolchainSHA256 \
  TildeAppleToolchainIdentitySchema \
  TildeXcodeVersion TildeXcodeBuild TildeXcodeCDHash TildeSwiftVersionSHA256 \
  TildeSwiftExecutableSHA256 TildeSwiftBuildExecutableSHA256 \
  TildeSwiftDriverExecutableSHA256 TildeClangExecutableSHA256 \
  TildeLinkerExecutableSHA256 TildeLibtoolExecutableSHA256 \
  TildeArchiverExecutableSHA256 TildeMacOSSDKVersion TildeMacOSSDKBuild \
  TildeMacOSSDKSettingsSHA256 TildeApprovedHelperInputSHA256 \
  TildeApprovedHelperTeamIdentifier TildeF03RunnerSHA256; do
  [[ "$(plist_value "$key" "$APP_PLIST")" == "$(plist_value "$key" "$IME_PLIST")" ]] \
    || { echo "candidate app/IME provenance mismatch: $key" >&2; exit 1; }
done
[[ "$(plist_value TildeSourceState "$APP_PLIST")" == "clean" ]]
[[ "$(plist_value TildeEvidenceClass "$APP_PLIST")" == "decision-grade" ]]
/usr/bin/codesign --verify --deep --strict --verbose=2 "$CANDIDATE"
REGISTERED_HELPER_INPUT_SHA256="e7b0946d81c2342d0d5afd1639dcb8af444c843b4fb50cef5ceeafa302a80546"
REGISTERED_HELPER_TEAM="XG6WL66WUQ"
APP_TEAM="$(codesign_team_identifier "$CANDIDATE")" \
  || { echo "candidate app has no unambiguous signing team" >&2; exit 1; }
IME_TEAM="$(codesign_team_identifier "$EMBEDDED_IME")" \
  || { echo "candidate IME has no unambiguous signing team" >&2; exit 1; }
HELPER_TEAM="$(codesign_team_identifier "$CANDIDATE/Contents/Helpers/llama-server")" \
  || { echo "candidate helper has no unambiguous signing team" >&2; exit 1; }
[[ "$APP_TEAM" == "$REGISTERED_HELPER_TEAM" \
    && "$IME_TEAM" == "$REGISTERED_HELPER_TEAM" \
    && "$HELPER_TEAM" == "$REGISTERED_HELPER_TEAM" ]] \
  || { echo "F03 candidate signing teams do not match the registered helper team" >&2; exit 1; }

SOURCE_COMMIT="$(plist_value TildeSourceCommit "$APP_PLIST")"
SOURCE_TREE="$(plist_value TildeSourceTree "$APP_PLIST")"
SOURCE_SNAPSHOT="$(plist_value TildeSourceSnapshotSHA256 "$APP_PLIST")"
APPLE_TOOLCHAIN_SHA256="$(plist_value TildeAppleToolchainSHA256 "$APP_PLIST")"
XCODE_VERSION="$(plist_value TildeXcodeVersion "$APP_PLIST")"
XCODE_BUILD="$(plist_value TildeXcodeBuild "$APP_PLIST")"
XCODE_CDHASH="$(plist_value TildeXcodeCDHash "$APP_PLIST")"
SWIFT_VERSION_SHA256="$(plist_value TildeSwiftVersionSHA256 "$APP_PLIST")"
SWIFT_EXECUTABLE_SHA256="$(plist_value TildeSwiftExecutableSHA256 "$APP_PLIST")"
SWIFT_BUILD_EXECUTABLE_SHA256="$(plist_value TildeSwiftBuildExecutableSHA256 "$APP_PLIST")"
SWIFT_DRIVER_EXECUTABLE_SHA256="$(plist_value TildeSwiftDriverExecutableSHA256 "$APP_PLIST")"
CLANG_EXECUTABLE_SHA256="$(plist_value TildeClangExecutableSHA256 "$APP_PLIST")"
LINKER_EXECUTABLE_SHA256="$(plist_value TildeLinkerExecutableSHA256 "$APP_PLIST")"
LIBTOOL_EXECUTABLE_SHA256="$(plist_value TildeLibtoolExecutableSHA256 "$APP_PLIST")"
ARCHIVER_EXECUTABLE_SHA256="$(plist_value TildeArchiverExecutableSHA256 "$APP_PLIST")"
MACOS_SDK_VERSION="$(plist_value TildeMacOSSDKVersion "$APP_PLIST")"
MACOS_SDK_BUILD="$(plist_value TildeMacOSSDKBuild "$APP_PLIST")"
MACOS_SDK_SETTINGS_SHA256="$(plist_value TildeMacOSSDKSettingsSHA256 "$APP_PLIST")"
APPROVED_HELPER_INPUT_SHA256="$(plist_value TildeApprovedHelperInputSHA256 "$APP_PLIST")"
APPROVED_HELPER_TEAM="$(plist_value TildeApprovedHelperTeamIdentifier "$APP_PLIST")"
EMBEDDED_RUNNER_SHA256="$(plist_value TildeF03RunnerSHA256 "$APP_PLIST")"
VERSION="$(plist_value CFBundleShortVersionString "$APP_PLIST")"
BUILD="$(plist_value CFBundleVersion "$APP_PLIST")"
[[ "$SOURCE_COMMIT" =~ ^[0-9a-f]{40}$ && "$SOURCE_TREE" =~ ^[0-9a-f]{40}$ \
    && "$SOURCE_SNAPSHOT" =~ ^[0-9a-f]{64}$ \
    && "$APPLE_TOOLCHAIN_SHA256" =~ ^[0-9a-f]{64}$ \
    && "$XCODE_CDHASH" =~ ^[0-9a-f]{40}([0-9a-f]{24})?$ \
    && "$SWIFT_VERSION_SHA256" =~ ^[0-9a-f]{64}$ \
    && "$SWIFT_EXECUTABLE_SHA256" =~ ^[0-9a-f]{64}$ \
    && "$SWIFT_BUILD_EXECUTABLE_SHA256" =~ ^[0-9a-f]{64}$ \
    && "$SWIFT_DRIVER_EXECUTABLE_SHA256" =~ ^[0-9a-f]{64}$ \
    && "$CLANG_EXECUTABLE_SHA256" =~ ^[0-9a-f]{64}$ \
    && "$LINKER_EXECUTABLE_SHA256" =~ ^[0-9a-f]{64}$ \
    && "$LIBTOOL_EXECUTABLE_SHA256" =~ ^[0-9a-f]{64}$ \
    && "$ARCHIVER_EXECUTABLE_SHA256" =~ ^[0-9a-f]{64}$ \
    && "$MACOS_SDK_SETTINGS_SHA256" =~ ^[0-9a-f]{64}$ \
    && "$EMBEDDED_RUNNER_SHA256" =~ ^[0-9a-f]{64}$ \
    && "$APPROVED_HELPER_INPUT_SHA256" == "$REGISTERED_HELPER_INPUT_SHA256" \
    && "$APPROVED_HELPER_TEAM" == "$REGISTERED_HELPER_TEAM" \
    && "$BUILD" =~ ^[0-9]+$ ]] \
  || { echo "candidate build provenance is malformed or not registered for F03" >&2; exit 1; }
PLIST_TOOLCHAIN_IDENTITY="$(
  tilde_toolchain_identity_sha256 \
    "$XCODE_VERSION" "$XCODE_BUILD" "$XCODE_CDHASH" \
    "$MACOS_SDK_VERSION" "$MACOS_SDK_BUILD" "$MACOS_SDK_SETTINGS_SHA256" \
    "$SWIFT_EXECUTABLE_SHA256" "$SWIFT_VERSION_SHA256" \
    "$SWIFT_BUILD_EXECUTABLE_SHA256" "$SWIFT_DRIVER_EXECUTABLE_SHA256" \
    "$CLANG_EXECUTABLE_SHA256" "$LINKER_EXECUTABLE_SHA256" \
    "$LIBTOOL_EXECUTABLE_SHA256" "$ARCHIVER_EXECUTABLE_SHA256"
)"
[[ "$PLIST_TOOLCHAIN_IDENTITY" == "$APPLE_TOOLCHAIN_SHA256" ]] \
  || { echo "candidate toolchain fields do not derive its registered identity" >&2; exit 1; }
tilde_capture_source_provenance "$ROOT_DIR" decision-grade
LIVE_HEAD_TREE="$(tilde_git_raw "$ROOT_DIR" rev-parse --verify 'HEAD^{tree}')"
[[ "$SOURCE_COMMIT" == "$TILDE_SOURCE_COMMIT" \
    && "$SOURCE_TREE" == "$TILDE_SOURCE_TREE" \
    && "$SOURCE_TREE" == "$LIVE_HEAD_TREE" \
    && "$SOURCE_SNAPSHOT" == "$TILDE_SOURCE_SNAPSHOT_SHA256" \
    && "$TILDE_SOURCE_STATE" == "clean" \
    && "$TILDE_SOURCE_EVIDENCE_CLASS" == "decision-grade" ]] \
  || { echo "candidate lineage does not exactly match the current clean repository" >&2; exit 1; }
tilde_assert_source_provenance_unchanged "$ROOT_DIR"

COMMITTED_RUNNER_SHA="$(
  tilde_git_raw "$ROOT_DIR" show "$SOURCE_COMMIT:script/f03_preview_run.sh" \
    | /usr/bin/shasum -a 256 \
    | /usr/bin/awk '{ print $1 }'
)"
COMMITTED_PROVENANCE_SHA="$(
  tilde_git_raw "$ROOT_DIR" show "$SOURCE_COMMIT:script/source_provenance.sh" \
    | /usr/bin/shasum -a 256 \
    | /usr/bin/awk '{ print $1 }'
)"
[[ "$COMMITTED_RUNNER_SHA" =~ ^[0-9a-f]{64}$ \
    && "$COMMITTED_PROVENANCE_SHA" =~ ^[0-9a-f]{64}$ \
    && "$EMBEDDED_RUNNER_SHA256" == "$COMMITTED_RUNNER_SHA" \
    && "$(sha256 "$SCRIPT_PATH")" == "$COMMITTED_RUNNER_SHA" ]] \
  || { echo "F03 runner bytes do not match the candidate source commit" >&2; exit 1; }
seal_and_reexec_runner \
  "$SOURCE_COMMIT" "$COMMITTED_RUNNER_SHA" "$COMMITTED_PROVENANCE_SHA"
RUNNER_SHA256="$COMMITTED_RUNNER_SHA"
INVOCATION_PROFILE="preview9b-owner-approved-v1"
assert_sealed_runner_identity "$SCRIPT_PATH" "$RUNNER_SHA256"
assert_sealed_runner_identity "$SOURCE_PROVENANCE_PATH" "$COMMITTED_PROVENANCE_SHA"
trap 'cleanup_sealed_runner >/dev/null 2>&1 || true' EXIT

USER_HOME="$(tilde_python_isolated - <<'PY'
import os, pwd
print(pwd.getpwuid(os.getuid()).pw_dir)
PY
)"
[[ "$USER_HOME" == /Users/* && -d "$USER_HOME" && ! -L "$USER_HOME" ]] \
  || { echo "refusing unresolved or linked user home" >&2; exit 1; }

RUN_ID="$(/usr/bin/uuidgen | /usr/bin/tr '[:upper:]' '[:lower:]')"
TILDE_LAB_SUPPORT="$USER_HOME/Library/Application Support/Tilde Lab"
RUN_ROOT="$USER_HOME/Library/Application Support/Tilde Lab/F03 Runs"
RUN_DIR="$RUN_ROOT/$RUN_ID"
SUPPORT_DIR="$USER_HOME/Library/Application Support/Tilde 9B Preview"
OUTCOME_DIR="$SUPPORT_DIR/Outcome Ledger"
EVENT_FILE="$OUTCOME_DIR/events.jsonl"
PENDING_EVENTS="$RUN_DIR/previous-events.pending.jsonl"
ARCHIVED_EVENTS="$RUN_DIR/previous-events.jsonl"
RECEIPT="$RUN_DIR/receipt.json"
PENDING_RECEIPT="$RUN_DIR/receipt.pending.json"
JOURNAL_PATH="$SUPPORT_DIR/.f03-transaction.json"
INSTALLED_APP="/Applications/Tilde 9B Preview.app"
INSTALLED_APP_BINARY="$INSTALLED_APP/Contents/MacOS/Tilde"
INSTALLED_HELPER="$INSTALLED_APP/Contents/Helpers/llama-server"
INSTALLED_IME="$USER_HOME/Library/Input Methods/InlineGhostIME 9B Preview.app"
INSTALLED_IME_BINARY="$INSTALLED_IME/Contents/MacOS/InlineGhostIME"
DOMAIN="bar.r3d.inputmethod.InlineGhostPreview9B"
MODEL_PATH="$SUPPORT_DIR/Models/qwen3.5-9b-base-q4km-preview/model.gguf"
MODEL_BYTES=5629109312
MODEL_SHA256="4171d5fec62a373744ca4f01ec9e2378c092a65f480c039e9c679d910351fda2"

for existing in \
  "$USER_HOME/Library" \
  "$USER_HOME/Library/Application Support" \
  "$TILDE_LAB_SUPPORT" \
  "$RUN_ROOT" \
  "$SUPPORT_DIR" \
  "$OUTCOME_DIR" \
  "$USER_HOME/Library/Input Methods" \
  "$INSTALLED_APP" \
  "$INSTALLED_IME"; do
  [[ ! -L "$existing" ]] || { echo "refusing linked local F03 directory" >&2; exit 1; }
done
[[ -d "$SUPPORT_DIR" ]] \
  || { echo "Preview9B support directory must exist before F03 maintenance" >&2; exit 1; }
[[ -f "$MODEL_PATH" && ! -L "$MODEL_PATH" ]] \
  || { echo "missing or linked Preview9B model" >&2; exit 1; }
[[ "$(/usr/bin/stat -f '%z' "$MODEL_PATH")" == "$MODEL_BYTES" \
    && "$(/usr/bin/stat -f '%l' "$MODEL_PATH")" == "1" \
    && "$(sha256 "$MODEL_PATH")" == "$MODEL_SHA256" ]] \
  || { echo "Preview9B model identity mismatch" >&2; exit 1; }

EXPECTED_APP_SHA="$(sha256 "$CANDIDATE/Contents/MacOS/Tilde")"
EXPECTED_IME_SHA="$(sha256 "$EMBEDDED_IME/Contents/MacOS/InlineGhostIME")"
EXPECTED_HELPER_SHA="$(sha256 "$CANDIDATE/Contents/Helpers/llama-server")"
EXPECTED_APP_PLIST_SHA="$(sha256 "$APP_PLIST")"
EXPECTED_IME_PLIST_SHA="$(sha256 "$IME_PLIST")"
EXPECTED_APP_MODE="$(/usr/bin/stat -f '%Lp' "$CANDIDATE/Contents/MacOS/Tilde")"
EXPECTED_IME_MODE="$(/usr/bin/stat -f '%Lp' "$EMBEDDED_IME/Contents/MacOS/InlineGhostIME")"
EXPECTED_HELPER_MODE="$(/usr/bin/stat -f '%Lp' "$CANDIDATE/Contents/Helpers/llama-server")"
EXPECTED_APP_PLIST_MODE="$(/usr/bin/stat -f '%Lp' "$APP_PLIST")"
EXPECTED_IME_PLIST_MODE="$(/usr/bin/stat -f '%Lp' "$IME_PLIST")"
[[ "$EXPECTED_HELPER_SHA" == "$REGISTERED_HELPER_INPUT_SHA256" ]] \
  || { echo "candidate helper bytes differ from the registered approved input" >&2; exit 1; }
OS_VERSION="$(/usr/bin/sw_vers -productVersion)"
OS_BUILD="$(/usr/bin/sw_vers -buildVersion)"
ARCHITECTURE="$(/usr/bin/uname -m)"
HARDWARE_MODEL="$(/usr/sbin/sysctl -n hw.model)"
POWER_LINE="$(/usr/bin/pmset -g batt | /usr/bin/head -n 1)"
case "$POWER_LINE" in
  *"AC Power"*) POWER_SOURCE="ac" ;;
  *"Battery Power"*) POWER_SOURCE="battery" ;;
  *) POWER_SOURCE="unknown" ;;
esac
validate_receipt_environment \
  "$VERSION" "$BUILD" "$XCODE_VERSION" "$XCODE_BUILD" \
  "$MACOS_SDK_VERSION" "$MACOS_SDK_BUILD" \
  "$OS_VERSION" "$OS_BUILD" "$ARCHITECTURE" "$HARDWARE_MODEL" "$POWER_SOURCE"
verify_registered_apple_toolchain
verify_critical_file_invariants \
  "$CANDIDATE/Contents/MacOS/Tilde" "$EXPECTED_APP_SHA" "$EXPECTED_APP_MODE" \
  "$EMBEDDED_IME/Contents/MacOS/InlineGhostIME" "$EXPECTED_IME_SHA" "$EXPECTED_IME_MODE" \
  "$CANDIDATE/Contents/Helpers/llama-server" "$EXPECTED_HELPER_SHA" "$EXPECTED_HELPER_MODE" \
  "$APP_PLIST" "$EXPECTED_APP_PLIST_SHA" "$EXPECTED_APP_PLIST_MODE" \
  "$IME_PLIST" "$EXPECTED_IME_PLIST_SHA" "$EXPECTED_IME_PLIST_MODE" \
  "$MODEL_PATH" "$MODEL_SHA256" 600
tilde_assert_source_provenance_unchanged "$ROOT_DIR"
ensure_maintenance_lock "$SUPPORT_DIR" ".f03-maintenance.lock"
OLD_APP_WAS_RUNNING=0
[[ -x "$INSTALLED_APP_BINARY" && -n "$(pids_for_binary "$INSTALLED_APP_BINARY")" ]] \
  && OLD_APP_WAS_RUNNING=1
APP_BACKUP_STATE="absent"
IME_BACKUP_STATE="absent"
[[ -e "$INSTALLED_APP" ]] && APP_BACKUP_STATE="present"
[[ -e "$INSTALLED_IME" ]] && IME_BACKUP_STATE="present"

TRANSACTION_DIR="/Applications/.tilde-f03-run.$RUN_ID"
IME_TRANSACTION_DIR="$USER_HOME/Library/Input Methods/.tilde-f03-run.$RUN_ID"
BACKUP_APP="$TRANSACTION_DIR/previous.app"
STAGED_APP="$TRANSACTION_DIR/candidate.app"
FAILED_APP="$TRANSACTION_DIR/failed.app"
BACKUP_IME="$IME_TRANSACTION_DIR/previous.app"
FAILED_IME="$IME_TRANSACTION_DIR/failed.app"
SUCCESS=0
COMMIT_STARTED=0
COMMIT_FINALIZATION_STARTED=0
JOURNAL_ACTIVE=0
JOURNAL_PHASE="prepared"
GENERATION_CHANGED=0
GENERATION_WAS_PRESENT=0
CURRENT_GENERATION=0
NEXT_GENERATION=""
ROTATION_RESULT=""
LEDGER_ROTATION_STARTED=0
LEDGER_ROTATION_FINISHED=0
APP_BUNDLE_TRANSACTION_STARTED=0
IME_BUNDLE_TRANSACTION_STARTED=0
APP_BACKUP_COMPLETED=0
IME_BACKUP_COMPLETED=0
APP_INSTALL_STARTED=0
SHUTDOWN_STARTED=0
FIRST_LAUNCH_STARTED=0
FINAL_LAUNCH_STARTED=0
FIRST_INPUT_METHOD_REGISTRATION_VERIFIED=0
FINAL_INPUT_METHOD_REGISTRATION_VERIFIED=0

journal_phase() {
  local phase="$1"
  write_transaction_journal \
    update "$JOURNAL_PATH" "$RUN_ID" "$phase" "$RUN_DIR" \
    "$TRANSACTION_DIR" "$IME_TRANSACTION_DIR" "$OLD_APP_WAS_RUNNING" \
    "$APP_BACKUP_STATE" "$IME_BACKUP_STATE" "$GENERATION_WAS_PRESENT" \
    "$CURRENT_GENERATION" "$NEXT_GENERATION" "$RECEIPT" \
    "$RUNNER_SHA256" "$INVOCATION_PROFILE"
  JOURNAL_PHASE="$phase"
}

rollback() {
  local rc=$?
  local rollback_failed=0 ledger_state="unknown"
  [[ "$rc" != "0" ]] || rc=1
  trap - EXIT INT TERM
  if [[ "$SUCCESS" != "1" ]]; then
    if [[ "$COMMIT_STARTED" == "1" ]]; then
      echo "F03 committed its verified receipt, but post-commit cleanup was interrupted." >&2
      echo "The new app/rotation remain in place; the durable journal and recovery material must be inspected before another run: $JOURNAL_PATH" >&2
      cleanup_sealed_runner >/dev/null 2>&1 || true
      exit "$rc"
    fi
    if [[ "$COMMIT_FINALIZATION_STARTED" == "1" \
        && ( -e "$RECEIPT" || -L "$RECEIPT" \
          || ( ! -e "$PENDING_RECEIPT" && ! -L "$PENDING_RECEIPT" ) ) ]]; then
      journal_phase rollback-incomplete >/dev/null 2>&1 || true
      echo "F03 receipt finalization has an indeterminate durable boundary; refusing automatic rollback or relaunch." >&2
      echo "Inspect $JOURNAL_PATH and $RUN_DIR before another owner-approved run." >&2
      cleanup_sealed_runner >/dev/null 2>&1 || true
      exit "$rc"
    fi
    if [[ "$JOURNAL_ACTIVE" == "1" ]]; then
      journal_phase rollback-intent || rollback_failed=1
    fi
    if [[ "$SHUTDOWN_STARTED" == "1" || "$APP_BUNDLE_TRANSACTION_STARTED" == "1" \
        || "$FIRST_LAUNCH_STARTED" == "1" || "$FINAL_LAUNCH_STARTED" == "1" ]]; then
      stop_exact_binary "$INSTALLED_APP_BINARY" "failed Preview9B candidate" \
        || rollback_failed=1
      stop_exact_binary "$INSTALLED_HELPER" "failed Preview9B helper" \
        || rollback_failed=1
    fi
    if [[ "$SHUTDOWN_STARTED" == "1" || "$IME_BUNDLE_TRANSACTION_STARTED" == "1" \
        || "$FIRST_LAUNCH_STARTED" == "1" || "$FINAL_LAUNCH_STARTED" == "1" ]]; then
      stop_exact_binary "$INSTALLED_IME_BINARY" "failed Preview9B IME" \
        || rollback_failed=1
    fi
    if [[ "$SHUTDOWN_STARTED" == "1" ]] && ! refuse_remaining_preview_processes; then
      rollback_failed=1
    fi
    if [[ "$rollback_failed" == "0" \
        && ( "$LEDGER_ROTATION_STARTED" == "1" || "$GENERATION_CHANGED" == "1" \
          || -e "$PENDING_EVENTS" || -L "$PENDING_EVENTS" ) ]]; then
      journal_phase rollback-ledger-intent || rollback_failed=1
      if [[ "$rollback_failed" == "0" \
          && ( "$LEDGER_ROTATION_FINISHED" == "1" || -e "$PENDING_EVENTS" \
            || -L "$PENDING_EVENTS" ) ]]; then
        [[ -n "$ROTATION_RESULT" ]] && ledger_state="$ROTATION_RESULT"
        restore_event_rotation \
          "$EVENT_FILE" "$PENDING_EVENTS" "$RUN_DIR/failed-run-events.jsonl" \
          "$ledger_state" || rollback_failed=1
      fi
      if [[ "$rollback_failed" == "0" && "$GENERATION_CHANGED" == "1" ]]; then
        restore_generation "$DOMAIN" "$GENERATION_WAS_PRESENT" "$CURRENT_GENERATION" \
          || rollback_failed=1
      fi
    fi
    if [[ "$rollback_failed" == "0" && "$IME_BUNDLE_TRANSACTION_STARTED" == "1" ]]; then
      journal_phase rollback-ime-intent || rollback_failed=1
      [[ "$rollback_failed" == "0" ]] \
        && restore_bundle_state \
          "$INSTALLED_IME" "$BACKUP_IME" "$FAILED_IME" \
          "$IME_BACKUP_STATE" "$IME_BACKUP_COMPLETED" || rollback_failed=1
    fi
    if [[ "$rollback_failed" == "0" && "$APP_BUNDLE_TRANSACTION_STARTED" == "1" ]]; then
      journal_phase rollback-app-intent || rollback_failed=1
      [[ "$rollback_failed" == "0" ]] \
        && restore_bundle_state \
          "$INSTALLED_APP" "$BACKUP_APP" "$FAILED_APP" \
          "$APP_BACKUP_STATE" "$APP_BACKUP_COMPLETED" || rollback_failed=1
    fi
    if [[ "$rollback_failed" == "0" && "$JOURNAL_ACTIVE" == "1" ]]; then
      if journal_phase rollback-complete \
          && remove_transaction_journal "$JOURNAL_PATH" "$RUN_ID" rollback-complete; then
        JOURNAL_ACTIVE=0
      else
        rollback_failed=1
      fi
    fi
    if [[ "$rollback_failed" == "1" ]]; then
      [[ "$JOURNAL_ACTIVE" == "1" ]] \
        && journal_phase rollback-incomplete >/dev/null 2>&1 || true
      echo "F03 rollback is incomplete; refusing automatic relaunch and any new maintenance." >&2
      echo "Recovery material and the durable journal remain at $RUN_DIR, $TRANSACTION_DIR, $IME_TRANSACTION_DIR, and $JOURNAL_PATH" >&2
    else
      echo "F03 transaction failed; prior bundles, generation, and ledger were restored. The prior app was intentionally left stopped." >&2
      echo "Owner-only failed-run material remains at $RUN_DIR, $TRANSACTION_DIR, and $IME_TRANSACTION_DIR" >&2
    fi
  fi
  cleanup_sealed_runner >/dev/null 2>&1 || true
  exit "$rc"
}

assert_sealed_runner_identity "$SCRIPT_PATH" "$RUNNER_SHA256"
write_transaction_journal \
  create "$JOURNAL_PATH" "$RUN_ID" prepared "$RUN_DIR" \
  "$TRANSACTION_DIR" "$IME_TRANSACTION_DIR" "$OLD_APP_WAS_RUNNING" \
  "$APP_BACKUP_STATE" "$IME_BACKUP_STATE" "$GENERATION_WAS_PRESENT" \
  "$CURRENT_GENERATION" "$NEXT_GENERATION" "$RECEIPT" \
  "$RUNNER_SHA256" "$INVOCATION_PROFILE" \
  || { echo "refusing F03 maintenance while an unfinished transaction exists" >&2; exit 1; }
JOURNAL_ACTIVE=1
trap rollback EXIT INT TERM

journal_phase directories-intent
ensure_owner_only_directory "$TILDE_LAB_SUPPORT" 1
ensure_owner_only_directory "$RUN_ROOT" 1
ensure_owner_only_directory "$RUN_DIR" 1 1
ensure_owner_only_directory "$OUTCOME_DIR" 1
ensure_owner_only_directory "$USER_HOME/Library/Input Methods" 1
ensure_owner_only_directory "$TRANSACTION_DIR" 1 1
ensure_owner_only_directory "$IME_TRANSACTION_DIR" 1 1
journal_phase directories-ready

journal_phase staging-intent
/usr/bin/ditto "$CANDIDATE" "$STAGED_APP"
verify_installed_signing \
  "$STAGED_APP" \
  "$STAGED_APP/Contents/Library/InlineGhostIME.app" \
  "$STAGED_APP/Contents/Helpers/llama-server" \
  "$APPROVED_HELPER_TEAM"
[[ "$(sha256 "$STAGED_APP/Contents/MacOS/Tilde")" == "$EXPECTED_APP_SHA" ]]
[[ "$(sha256 "$STAGED_APP/Contents/Library/InlineGhostIME.app/Contents/MacOS/InlineGhostIME")" == "$EXPECTED_IME_SHA" ]]
[[ "$(sha256 "$STAGED_APP/Contents/Helpers/llama-server")" == "$EXPECTED_HELPER_SHA" ]]
[[ "$(sha256 "$STAGED_APP/Contents/Info.plist")" == "$EXPECTED_APP_PLIST_SHA" ]]
[[ "$(sha256 "$STAGED_APP/Contents/Library/InlineGhostIME.app/Contents/Info.plist")" == "$EXPECTED_IME_PLIST_SHA" ]]
verify_critical_file_invariants \
  "$STAGED_APP/Contents/MacOS/Tilde" "$EXPECTED_APP_SHA" "$EXPECTED_APP_MODE" \
  "$STAGED_APP/Contents/Library/InlineGhostIME.app/Contents/MacOS/InlineGhostIME" "$EXPECTED_IME_SHA" "$EXPECTED_IME_MODE" \
  "$STAGED_APP/Contents/Helpers/llama-server" "$EXPECTED_HELPER_SHA" "$EXPECTED_HELPER_MODE" \
  "$STAGED_APP/Contents/Info.plist" "$EXPECTED_APP_PLIST_SHA" "$EXPECTED_APP_PLIST_MODE" \
  "$STAGED_APP/Contents/Library/InlineGhostIME.app/Contents/Info.plist" "$EXPECTED_IME_PLIST_SHA" "$EXPECTED_IME_PLIST_MODE" \
  "$MODEL_PATH" "$MODEL_SHA256" 600
verify_installed_plist "$APP_PLIST" "$STAGED_APP/Contents/Info.plist"
verify_installed_plist "$IME_PLIST" "$STAGED_APP/Contents/Library/InlineGhostIME.app/Contents/Info.plist"
[[ "$(plist_value TildeSourceCommit "$STAGED_APP/Contents/Info.plist")" == "$SOURCE_COMMIT" ]]
[[ "$(plist_value TildeSourceTree "$STAGED_APP/Contents/Info.plist")" == "$SOURCE_TREE" ]]
[[ "$(plist_value TildeSourceSnapshotSHA256 "$STAGED_APP/Contents/Info.plist")" == "$SOURCE_SNAPSHOT" ]]
[[ "$(plist_value TildeSourceState "$STAGED_APP/Contents/Info.plist")" == "clean" ]]
[[ "$(plist_value TildeEvidenceClass "$STAGED_APP/Contents/Info.plist")" == "decision-grade" ]]
[[ "$(plist_value CFBundleShortVersionString "$STAGED_APP/Contents/Info.plist")" == "$VERSION" ]]
[[ "$(plist_value CFBundleVersion "$STAGED_APP/Contents/Info.plist")" == "$BUILD" ]]
[[ "$(plist_value TildeSourceCommit "$STAGED_APP/Contents/Library/InlineGhostIME.app/Contents/Info.plist")" == "$SOURCE_COMMIT" ]]
[[ "$(plist_value TildeSourceTree "$STAGED_APP/Contents/Library/InlineGhostIME.app/Contents/Info.plist")" == "$SOURCE_TREE" ]]
[[ "$(plist_value TildeSourceSnapshotSHA256 "$STAGED_APP/Contents/Library/InlineGhostIME.app/Contents/Info.plist")" == "$SOURCE_SNAPSHOT" ]]
[[ "$(plist_value TildeSourceState "$STAGED_APP/Contents/Library/InlineGhostIME.app/Contents/Info.plist")" == "clean" ]]
[[ "$(plist_value TildeEvidenceClass "$STAGED_APP/Contents/Library/InlineGhostIME.app/Contents/Info.plist")" == "decision-grade" ]]
journal_phase staging-ready
tilde_assert_source_provenance_unchanged "$ROOT_DIR"
journal_phase shutdown-intent
SHUTDOWN_STARTED=1
stop_exact_binary "$INSTALLED_APP_BINARY" "installed Preview9B app"
stop_exact_binary "$INSTALLED_HELPER" "installed Preview9B helper"
stop_exact_binary "$INSTALLED_IME_BINARY" "installed Preview9B IME"
refuse_remaining_preview_processes
journal_phase shutdown-complete

APP_BUNDLE_TRANSACTION_STARTED=1
journal_phase app-backup-intent
OBSERVED_APP_BACKUP_STATE="$(backup_bundle_for_transaction "$INSTALLED_APP" "$BACKUP_APP")"
[[ "$OBSERVED_APP_BACKUP_STATE" == "$APP_BACKUP_STATE" ]]
APP_BACKUP_COMPLETED=1
journal_phase app-backup-complete

IME_BUNDLE_TRANSACTION_STARTED=1
journal_phase ime-backup-intent
OBSERVED_IME_BACKUP_STATE="$(backup_bundle_for_transaction "$INSTALLED_IME" "$BACKUP_IME")"
[[ "$OBSERVED_IME_BACKUP_STATE" == "$IME_BACKUP_STATE" ]]
IME_BACKUP_COMPLETED=1
journal_phase ime-backup-complete

stop_exact_binary "$BACKUP_APP/Contents/MacOS/Tilde" "backed-up Preview9B app"
stop_exact_binary "$BACKUP_APP/Contents/Helpers/llama-server" "backed-up Preview9B helper"
stop_exact_binary "$BACKUP_IME/Contents/MacOS/InlineGhostIME" "backed-up Preview9B IME"
refuse_remaining_preview_processes
APP_INSTALL_STARTED=1
journal_phase app-install-intent
move_bundle_exclusive "$STAGED_APP" "$INSTALLED_APP"
verify_installed_signing \
  "$INSTALLED_APP" \
  "$INSTALLED_APP/Contents/Library/InlineGhostIME.app" \
  "$INSTALLED_HELPER" \
  "$APPROVED_HELPER_TEAM"
[[ "$(sha256 "$INSTALLED_APP_BINARY")" == "$EXPECTED_APP_SHA" ]]
[[ "$(sha256 "$INSTALLED_APP/Contents/Library/InlineGhostIME.app/Contents/MacOS/InlineGhostIME")" == "$EXPECTED_IME_SHA" ]]
[[ "$(sha256 "$INSTALLED_HELPER")" == "$EXPECTED_HELPER_SHA" ]]
[[ "$(sha256 "$INSTALLED_APP/Contents/Info.plist")" == "$EXPECTED_APP_PLIST_SHA" ]]
[[ "$(sha256 "$INSTALLED_APP/Contents/Library/InlineGhostIME.app/Contents/Info.plist")" == "$EXPECTED_IME_PLIST_SHA" ]]
verify_installed_plist "$APP_PLIST" "$INSTALLED_APP/Contents/Info.plist"
journal_phase app-install-complete

# First launch lets the app perform its already-tested atomic IME replacement.
FIRST_LAUNCH_STARTED=1
journal_phase first-launch-intent
/usr/bin/open -n -F "$INSTALLED_APP"
wait_for_preview_ready \
  "$INSTALLED_APP_BINARY" "$INSTALLED_HELPER" "$INSTALLED_IME_BINARY" "$EXPECTED_IME_SHA"
verify_installed_signing "$INSTALLED_APP" "$INSTALLED_IME" "$INSTALLED_HELPER" "$APP_TEAM"
[[ "$(sha256 "$INSTALLED_APP_BINARY")" == "$EXPECTED_APP_SHA" ]]
[[ "$(sha256 "$INSTALLED_HELPER")" == "$EXPECTED_HELPER_SHA" ]]
[[ "$(sha256 "$INSTALLED_IME_BINARY")" == "$EXPECTED_IME_SHA" ]]
[[ "$(sha256 "$INSTALLED_APP/Contents/Info.plist")" == "$EXPECTED_APP_PLIST_SHA" ]]
[[ "$(sha256 "$INSTALLED_IME/Contents/Info.plist")" == "$EXPECTED_IME_PLIST_SHA" ]]
verify_installed_plist "$APP_PLIST" "$INSTALLED_APP/Contents/Info.plist"
verify_installed_plist "$IME_PLIST" "$INSTALLED_IME/Contents/Info.plist"
verify_preview_input_source_registration
FIRST_INPUT_METHOD_REGISTRATION_VERIFIED=1
journal_phase first-launch-verified
journal_phase first-shutdown-intent
stop_exact_binary "$INSTALLED_APP_BINARY" "new Preview9B app"
stop_exact_binary "$INSTALLED_HELPER" "new Preview9B helper"
stop_exact_binary "$INSTALLED_IME_BINARY" "new Preview9B IME"
refuse_remaining_preview_processes
journal_phase first-shutdown-complete

PREVIOUS_BYTES=0
PREVIOUS_SHA=""
PREVIOUS_DISPOSITION="absent"
if CURRENT_GENERATION="$(/usr/bin/defaults read "$DOMAIN" OutcomeLedgerGeneration 2>/dev/null)"; then
  GENERATION_WAS_PRESENT=1
  [[ ( "$CURRENT_GENERATION" == "0" || "$CURRENT_GENERATION" =~ ^[1-9][0-9]*$ ) \
      && ${#CURRENT_GENERATION} -le 10 \
      && "$CURRENT_GENERATION" -le 2147483647 ]] \
    || { echo "existing OutcomeLedgerGeneration is outside the supported integer domain" >&2; exit 1; }
else
  GENERATION_WAS_PRESENT=0
  CURRENT_GENERATION=0
fi
NEXT_GENERATION="$(next_unused_outcome_generation "$DOMAIN" "$CURRENT_GENERATION")" \
  || { echo "no unused Outcome Ledger generation is safely available" >&2; exit 1; }
GENERATION_CHANGED=1
LEDGER_ROTATION_STARTED=1
ROTATION_AT="$(tilde_python_isolated - <<'PY'
from datetime import datetime, timezone
print(datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z"))
PY
)"
journal_phase rotation-intent
ROTATION_OUTPUT="$(
  rotate_event_file \
    "$EVENT_FILE" "$PENDING_EVENTS" "$DOMAIN" "$GENERATION_WAS_PRESENT" \
    "$CURRENT_GENERATION" "$NEXT_GENERATION"
)"
LEDGER_ROTATION_FINISHED=1
IFS=$'\t' read -r ROTATION_RESULT PREVIOUS_BYTES PREVIOUS_SHA <<<"$ROTATION_OUTPUT"
[[ "$(/usr/bin/defaults read "$DOMAIN" OutcomeLedgerGeneration)" == "$NEXT_GENERATION" ]] \
  || { echo "Outcome Ledger generation changed after locked rotation" >&2; exit 1; }
if [[ "$ROTATION_RESULT" == "rotated" ]]; then
  PREVIOUS_DISPOSITION="$PREVIOUS_LEDGER"
elif [[ "$ROTATION_RESULT" != "absent" ]]; then
  echo "unexpected Outcome Ledger rotation result" >&2
  exit 1
fi
journal_phase rotation-complete

FINAL_LAUNCH_STARTED=1
journal_phase final-launch-intent
/usr/bin/open -n -F "$INSTALLED_APP"
wait_for_preview_ready \
  "$INSTALLED_APP_BINARY" "$INSTALLED_HELPER" "$INSTALLED_IME_BINARY" "$EXPECTED_IME_SHA"
verify_installed_signing "$INSTALLED_APP" "$INSTALLED_IME" "$INSTALLED_HELPER" "$APP_TEAM"
[[ "$(sha256 "$INSTALLED_APP_BINARY")" == "$EXPECTED_APP_SHA" ]]
[[ "$(sha256 "$INSTALLED_HELPER")" == "$EXPECTED_HELPER_SHA" ]]
[[ "$(sha256 "$INSTALLED_IME_BINARY")" == "$EXPECTED_IME_SHA" ]]
[[ "$(sha256 "$INSTALLED_APP/Contents/Info.plist")" == "$EXPECTED_APP_PLIST_SHA" ]]
[[ "$(sha256 "$INSTALLED_IME/Contents/Info.plist")" == "$EXPECTED_IME_PLIST_SHA" ]]
verify_installed_plist "$APP_PLIST" "$INSTALLED_APP/Contents/Info.plist"
verify_installed_plist "$IME_PLIST" "$INSTALLED_IME/Contents/Info.plist"
verify_preview_input_source_registration
FINAL_INPUT_METHOD_REGISTRATION_VERIFIED=1
[[ "$(sha256 "$MODEL_PATH")" == "$MODEL_SHA256" ]]
verify_critical_file_invariants \
  "$INSTALLED_APP_BINARY" "$EXPECTED_APP_SHA" "$EXPECTED_APP_MODE" \
  "$INSTALLED_IME_BINARY" "$EXPECTED_IME_SHA" "$EXPECTED_IME_MODE" \
  "$INSTALLED_HELPER" "$EXPECTED_HELPER_SHA" "$EXPECTED_HELPER_MODE" \
  "$INSTALLED_APP/Contents/Info.plist" "$EXPECTED_APP_PLIST_SHA" "$EXPECTED_APP_PLIST_MODE" \
  "$INSTALLED_IME/Contents/Info.plist" "$EXPECTED_IME_PLIST_SHA" "$EXPECTED_IME_PLIST_MODE" \
  "$MODEL_PATH" "$MODEL_SHA256" 600
tilde_assert_source_provenance_unchanged "$ROOT_DIR"
journal_phase final-launch-verified
validate_receipt_environment \
  "$VERSION" "$BUILD" "$XCODE_VERSION" "$XCODE_BUILD" \
  "$MACOS_SDK_VERSION" "$MACOS_SDK_BUILD" \
  "$OS_VERSION" "$OS_BUILD" "$ARCHITECTURE" "$HARDWARE_MODEL" "$POWER_SOURCE"
COMPLETED_AT="$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)"

journal_phase receipt-write-intent
assert_sealed_runner_identity "$SCRIPT_PATH" "$RUNNER_SHA256"
PENDING_RECEIPT_SHA="$(atomic_receipt "$PENDING_RECEIPT" \
  "$RUN_ID" "$SOURCE_COMMIT" "$SOURCE_TREE" "$SOURCE_SNAPSHOT" \
  "$APPLE_TOOLCHAIN_SHA256" "$XCODE_VERSION" "$XCODE_BUILD" \
  "$SWIFT_VERSION_SHA256" "$SWIFT_EXECUTABLE_SHA256" \
  "$MACOS_SDK_VERSION" "$MACOS_SDK_BUILD" "$MACOS_SDK_SETTINGS_SHA256" \
  "$APPROVED_HELPER_INPUT_SHA256" "$APPROVED_HELPER_TEAM" \
  "$RUNNER_SHA256" "$INVOCATION_PROFILE" \
  "$VERSION" "$BUILD" "$EXPECTED_APP_SHA" "$EXPECTED_IME_SHA" "$EXPECTED_HELPER_SHA" \
  "$EXPECTED_APP_PLIST_SHA" "$EXPECTED_IME_PLIST_SHA" \
  "$ROTATION_AT" "$COMPLETED_AT" "$PREVIOUS_DISPOSITION" \
  "$PREVIOUS_BYTES" "$PREVIOUS_SHA" "$NEXT_GENERATION" \
  "$APP_TEAM" "$MODEL_SHA256" "$MODEL_BYTES" "$OS_VERSION" "$OS_BUILD" \
  "$ARCHITECTURE" "$HARDWARE_MODEL" "$POWER_SOURCE" \
  "$FIRST_INPUT_METHOD_REGISTRATION_VERIFIED" \
  "$FINAL_INPUT_METHOD_REGISTRATION_VERIFIED")"
[[ "$PENDING_RECEIPT_SHA" =~ ^[0-9a-f]{64}$ ]]
journal_phase receipt-pending

journal_phase receipt-finalize-intent
COMMIT_FINALIZATION_STARTED=1
finalize_receipt \
  "$PENDING_RECEIPT" "$RECEIPT" "$RUN_ID" \
  "$RUNNER_SHA256" "$INVOCATION_PROFILE" "$PENDING_RECEIPT_SHA"
journal_phase receipt-durable
COMMIT_STARTED=1

journal_phase cleanup-intent
finalize_previous_events "$PENDING_EVENTS" "$ARCHIVED_EVENTS" "$PREVIOUS_LEDGER"
ensure_owner_only_directory "$TRANSACTION_DIR"
ensure_owner_only_directory "$IME_TRANSACTION_DIR"
/bin/rm -rf "$TRANSACTION_DIR" "$IME_TRANSACTION_DIR"
journal_phase cleanup-complete
remove_transaction_journal "$JOURNAL_PATH" "$RUN_ID" cleanup-complete
JOURNAL_ACTIVE=0
SUCCESS=1
trap - EXIT INT TERM
cleanup_sealed_runner >/dev/null 2>&1 || true

echo "F03 Preview9B run is ready. Local aggregate receipt: $RECEIPT"
echo "No diary, prompt, candidate, or writing content was copied into the receipt."
