#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p \
  "$TMP_DIR/Sources/AutocompleteLabApp/App" \
  "$TMP_DIR/Sources/AutocompleteLabApp/Runtime" \
  "$TMP_DIR/Sources/AutocompleteLabCore/Experiments" \
  "$TMP_DIR/Sources/AutocompleteLabCore/Runtime"

cat >"$TMP_DIR/Sources/AutocompleteLabApp/Runtime/ModelAssetInstaller.swift" <<'SWIFT'
let hub = HubApi(downloadBase: scratchURL, useBackgroundSession: false)
let snapshotURL = try await hub.snapshot(from: source)
SWIFT

cat >"$TMP_DIR/Sources/AutocompleteLabApp/Runtime/LocalModelAssetInstaller.swift" <<'SWIFT'
let downloadedURL = try await HubClient.default.downloadSnapshot(of: repoID)
SWIFT

cat >"$TMP_DIR/Sources/AutocompleteLabApp/Runtime/MLXModelRuntime.swift" <<'SWIFT'
import MLXHuggingFace
SWIFT

cat >"$TMP_DIR/Sources/AutocompleteLabCore/Runtime/RuntimeBootstrapPlan.swift" <<'SWIFT'
let licenseURL = "https://huggingface.co/mlx-community/Qwen3.5-4B-MLX-4bit"
SWIFT

cat >"$TMP_DIR/Sources/AutocompleteLabCore/Experiments/EvalV2BlindCorpus.swift" <<'SWIFT'
let gutenbergCitation = EvalV2PublicDomainSource(
    url: "https://www.gutenberg.org/ebooks/11",
)
let archivesCitation = EvalV2PublicDomainSource(
    url: "https://www.archives.gov/founding-docs/constitution-transcript",
)
if !source.url.hasPrefix("https://") {
}
let liveCorpusFetchURL = "https://example.com/live-eval-download"
let citation = (url: "https://www.gutenberg.org/ebooks/11"); let mixedEvalFetch = URLSession.shared.dataTask(with: request)
SWIFT

cat >"$TMP_DIR/Sources/AutocompleteLabApp/App/AppDelegate.swift" <<'SWIFT'
let task = URLSession.shared.dataTask(with: url)
SWIFT

if script/check_local_only_network_surface.sh --root "$TMP_DIR" >/tmp/local-only-network-fail.out 2>&1; then
  echo "network surface self-test expected URLSession in AppDelegate to fail" >&2
  exit 1
fi

if ! grep -F "Sources/AutocompleteLabApp/App/AppDelegate.swift" /tmp/local-only-network-fail.out >/dev/null; then
  echo "network surface self-test did not report the unsafe source file" >&2
  cat /tmp/local-only-network-fail.out >&2
  exit 1
fi

if ! grep -F "Sources/AutocompleteLabCore/Experiments/EvalV2BlindCorpus.swift" /tmp/local-only-network-fail.out >/dev/null; then
  echo "network surface self-test did not report the unsafe eval corpus URL" >&2
  cat /tmp/local-only-network-fail.out >&2
  exit 1
fi

if ! grep -F "mixedEvalFetch" /tmp/local-only-network-fail.out >/dev/null; then
  echo "network surface self-test did not reject a forbidden call sharing an allowed citation line" >&2
  cat /tmp/local-only-network-fail.out >&2
  exit 1
fi

cat >"$TMP_DIR/Sources/AutocompleteLabApp/App/AppDelegate.swift" <<'SWIFT'
let localOnlyTypingPath = true
SWIFT

cat >"$TMP_DIR/Sources/AutocompleteLabCore/Experiments/EvalV2BlindCorpus.swift" <<'SWIFT'
let gutenbergCitation = EvalV2PublicDomainSource(
    url: "https://www.gutenberg.org/ebooks/11",
)
let archivesCitation = EvalV2PublicDomainSource(
    url: "https://www.archives.gov/milestone-documents/gettysburg-address",
)
if !source.url.hasPrefix("https://") {
}
SWIFT

script/check_local_only_network_surface.sh --root "$TMP_DIR" >/tmp/local-only-network-pass.out

if ! grep -F "Local-only network surface verified." /tmp/local-only-network-pass.out >/dev/null; then
  echo "network surface self-test did not pass allowed references" >&2
  cat /tmp/local-only-network-pass.out >&2
  exit 1
fi

echo "Local-only network surface self-test passed."
