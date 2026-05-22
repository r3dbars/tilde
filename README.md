# SteadyType

![SteadyType cover](Assets/GitHub/steadytype-cover.png)

SteadyType is a small Mac app for quiet writing suggestions near your cursor.

It watches the active text field, shows a short suggestion, and only inserts text when you accept it. The question for this beta is simple: does this make writing feel easier, or does it get in the way?

Current proof truth: the private beta is still blocked until the live proof
gates are green. `./script/manual_smoke_status.sh --strict` currently reports
35 stale or pending target-app rows, and `./script/check_proof_manifest.sh
--require-all` still has 6 partial surfaces. Recorded proof exists, but broad
support is not ready to claim.

## What It Does

- runs as a macOS menu bar app
- reads the focused text field through Accessibility
- shows a small suggestion near the cursor
- uses `Tab` to accept one word
- uses `Esc` to dismiss
- runs local-first by default
- keeps app support proof-gated instead of pretending it works everywhere

## Current Beta Scope

Write-test only in these proof-gated lanes:

- TextEdit
- Apple Notes title, body, and checklist surfaces
- Obsidian disposable proof lanes, when current proof is green
- Chrome local/public text fields and included local fixtures

These are beta targets, not a broad compatibility promise. Chrome is not broad
browser support: Google Docs, Notion, browser ChatGPT, Slack, Discord,
production Monaco, and production CodeMirror stay blocked or partial until each
has its own disposable proof.

Prompt apps stay tighter:

- Codex is a word-only dogfood lane. Default one-word no-submit proof exists,
  but current-head refresh, more prompt layouts, and full-accept no-submit
  proof are still gaps.
- Claude desktop is word-only until more prompt layouts pass and full accept
  has separate no-submit proof.
- Claude Code is proof-only through an explicit terminal-host lane. The direct
  `com.anthropic.claude-code` bundle is diagnostics-only because real typing
  happens in terminal hosts.

## Privacy

SteadyType is local-first. Typed text, prompts, model output, accepted text, screenshots, document names, URLs, recipients, and subject lines are not uploaded by default.

Diagnostics are local and redacted unless a tester explicitly opts into a short-lived raw or screenshot trace for debugging.

Useful docs:

- [Beta privacy](PRIVACY-BETA.md)
- [Known limitations](KNOWN-LIMITATIONS.md)
- [Diagnostic export](DIAGNOSTIC-EXPORT.md)
- [Uninstall and delete data](UNINSTALL-DELETE-DATA.md)

## Runtime

The app owns the model runtime. Testers should not need to start Ollama, llama.cpp, Python, or any other server.

The current local runtime path uses MLX on Apple Silicon and downloads one pinned default model revision once. The beta gate checks the local checksum receipt before calling the model ready.

## What This Is Not

- not part of another product yet
- not a cloud-first writing assistant
- not personalization
- not a broad compatibility claim
- not a full release

## Development

```bash
swift test
./script/check_test_coverage_manifest.sh
./script/build_and_run.sh --verify
```

Full private beta validation lives in:

```bash
./script/beta_readiness.sh
```

The repo also includes smoke tests, privacy checks, runtime checks, proof manifests, and visual placement evidence under `script/` and `docs/product/`.
