# Onboarding Walkthrough Proof

This is the runbook for the `Guided TextEdit Walkthrough Proof` table in `onboarding-permission-qa-checklist.md`.

The gate is manual on purpose. Do not turn a placeholder into `pass` unless a clean macOS tester account actually completed the flow.

## Before The Run

- Build or verify the current app:

```bash
./script/build_and_run.sh --verify
```

- Use a clean macOS user account.
- Keep all typed text disposable.
- Do not paste raw typed text, private document names, prompts, URLs, or clipboard contents into docs.
- Record line numbers, counters, hashes, or command output instead of raw content.
- Keep these evidence locations handy:
  - `~/Library/Logs/SteadyType/diagnostics.log`
  - `~/Library/Logs/SteadyType/traces.jsonl`

## Passing Evidence

Each passing row must prove all of this in one clean-user walkthrough:

- Accessibility was granted or allowed after app-owned, user-triggered Settings copy.
- Runtime was ready through the app-owned local MLX path.
- Runtime did not use Ollama, llama.cpp, a separate server, or mock fallback.
- TextEdit practice opened a disposable local practice file.
- `Tab` inserted one word or the next word and the insert was verified.
- `Shift-Tab` accepted the whole visible suggestion and the insert was verified.
- `Esc` dismissed a visible suggestion with no text change.
- Pause stopped suggestions.
- Delete traces removed local trace or log files.
- Evidence cites command output, diagnostics lines, trace lines, or a manual gate row.

If any item is missing, keep the proof row as pending or blocked. Do not mark it `pass`.

## Row Template

Run this to print a row with the current commit token:

```bash
./script/check_onboarding_walkthrough_proof.py --print-template
```

The row still needs real observed values. Update the time, clean macOS user, and evidence line numbers from the actual run.

## Recording Flow

1. Run `./script/build_and_run.sh --verify`.
2. Open Settings and complete Practice in TextEdit.
3. Confirm Accessibility, local model ready, TextEdit enabled, global pause off, TextEdit opened, `Tab`, `Shift-Tab`, `Esc`, and Pause.
4. Before clicking Delete Local Logs, run:

```bash
./script/onboarding_walkthrough_evidence_helper.py --mode before-delete --require-ready
```

5. Click Delete Local Logs from Practice.
6. After deletion, run:

```bash
./script/onboarding_walkthrough_evidence_helper.py --mode after-delete --require-ready
```

7. Add one real row to the checklist using helper line ranges or counters, not raw typed text. The before-delete helper must show model ready, TextEdit enabled, suggestions unpaused at practice start, and Tab/Shift-Tab/Esc/Pause evidence after the latest TextEdit practice-start line.
8. Run `./script/check_onboarding_walkthrough_proof.py`.

## Useful Commands

```bash
date -u +"%Y-%m-%dT%H:%M:%SZ"
git rev-parse --short=12 HEAD
./script/onboarding_walkthrough_evidence_helper.py --print-commands
./script/check_onboarding_walkthrough_proof.py --print-template
./script/check_onboarding_walkthrough_proof.py
```
