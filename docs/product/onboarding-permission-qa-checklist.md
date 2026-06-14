# Onboarding Permission QA Checklist

Use this before a private beta build. This is manual proof, not a code claim.

## First 10-Minute User Map

The first-run surface and TextEdit practice file must make this clear in plain
language:

- Suggestions appear as a small floating suggestion next to the cursor in
  supported writing apps.
- Suggestions do not enter the document until accepted.
- `Tab` accepts one word.
- `Shift-Tab` accepts the whole visible suggestion.
- `Esc` dismisses the suggestion without changing text.
- `Pause Suggestions` stops suggestions everywhere.
- `Pause Current App` stops suggestions only in the frontmost app.
- Typed text, prompts, model output, accepted text, screenshots, document
  names, URLs, recipients, and subject lines stay on this Mac by default.
- The write-test apps are TextEdit, Notes, Obsidian, and the included Chrome
  local practice pages.
- Mail, Atlas, Slack, Discord, Notion, search, login, payment, address, URL,
  secure, and private fields stay off until proof says otherwise.

## Clean Install

- [ ] Install the app with Accessibility off.
- [ ] Confirm the app opens its own Settings/onboarding surface before any macOS Accessibility prompt appears.
- [ ] Confirm the first screen explains the full first 10-minute user map above.
- [ ] Click `Allow Accessibility`.
- [ ] Confirm the app explains why System Settings is opening.
- [ ] Grant Accessibility, return to the app, and confirm the status updates without restart.
- [ ] Record clean-user proof below with the macOS user name, build commit, and
  whether the first system prompt appeared only after `Allow Accessibility`.

## Guided Practice

- [ ] Confirm Settings shows `Practice`.
- [ ] Confirm Practice shows Accessibility status, local model readiness, and TextEdit enablement.
- [ ] Confirm Practice names the proof points before leaving: Accessibility, local model, TextEdit, `Tab`, `Shift-Tab`, `Esc`, Pause, and Delete Local Logs.
- [ ] Click `Start TextEdit Practice`.
- [ ] Confirm the app opens a disposable local TextEdit practice file.
- [ ] Confirm the practice file repeats the safe first-run map in plain language.
- [ ] Confirm TextEdit is enabled for suggestions.
- [ ] Type disposable text in TextEdit.
- [ ] Confirm a suggestion appears near the cursor.
- [ ] Press `Tab` and confirm only the next word inserts.
- [ ] Press `Shift-Tab` and confirm the whole visible suggestion inserts.
- [ ] Type again, wait for another suggestion, press `Esc`, and confirm the suggestion dismisses without changing text.
- [ ] Click `Pause Suggestions` from Practice and confirm suggestions stop.
- [ ] Click `Delete Local Logs` from Practice and confirm local trace JSONL and screenshot files are gone.
- [ ] Record the walkthrough in the `Guided TextEdit Walkthrough Proof` table below.
- [ ] Keep evidence to command output, line ranges, counters, and hashes. Do not paste raw typed text.
- [ ] Use `./script/onboarding_walkthrough_evidence_helper.py --mode before-delete --require-ready` before deletion and `./script/onboarding_walkthrough_evidence_helper.py --mode after-delete --require-ready` after deletion to gather redacted line ranges. The before-delete helper must show model ready, TextEdit enabled, suggestions unpaused at practice start, and Tab/Shift-Tab/Esc/Pause evidence after the latest TextEdit practice-start line.
- [ ] Run `./script/check_onboarding_walkthrough_proof.py`.

## First Success

- [ ] Confirm suggestion-capable apps start off on a fresh install.
- [ ] Enable TextEdit only.
- [ ] Type disposable text in TextEdit.
- [ ] Confirm a suggestion appears near the cursor.
- [ ] Press `Tab` and confirm only the next word inserts.
- [ ] Press `Shift-Tab` and confirm the whole visible suggestion inserts.
- [ ] Press `Esc` and confirm the suggestion dismisses without changing text.

## Permission Recovery

- [ ] Deny or remove Accessibility.
- [ ] Confirm the app stays calm and says suggestions need Accessibility.
- [ ] Confirm no suggestion appears while Accessibility is denied.
- [ ] Confirm `Open Privacy Settings` returns the user to the right Settings area.
- [ ] Confirm Screen Recording is not requested during normal autocomplete setup.
- [ ] Relaunch with Accessibility still denied and confirm Settings opens without a suggestion appearing.
- [ ] Grant Accessibility again and confirm Practice can start without reinstalling the app.
- [ ] Record denial-recovery proof below with the build commit and log slice.

## Diagnostics

- [ ] Turn on screenshot proof only from an explicit diagnostics/proof action.
- [ ] Confirm Settings says Screen Recording is only for local placement screenshots.
- [ ] Confirm screenshot proof can be turned off.
- [ ] Confirm `Delete Local Logs` removes local traces and screenshot files.

## Model Setup

- [ ] Start without the local model installed.
- [ ] Confirm Settings says the model download uses Hugging Face once and suggestions run locally after install.
- [ ] Start the install with `Install Local Model` and confirm progress is visible.
- [ ] Confirm low disk space is caught before a network download starts, or record why the scenario could not be safely reproduced.
- [ ] Cancel the install and confirm the app returns to a recoverable state.
- [ ] Repair an incomplete model folder with `Repair Local Model` and confirm suggestions stay off until validation passes.

## Release Rule

Do not invite private beta testers until this checklist passes on a clean macOS user account.

Keep unchecked boxes and Pending proof rows visible until the run is complete.
Current known gaps:

- Accessibility denial/regrant proof is still pending.
- Fresh clean-user first-prompt proof is still pending.

## Guided TextEdit Walkthrough Proof

The row must prove one complete clean-user path: app-owned explanation, user-triggered Accessibility grant, app-owned local runtime readiness, disposable TextEdit practice, one-word `Tab`, whole-suggestion `Shift-Tab`, `Esc`, Pause, and trace deletion. It must not rely on Ollama, llama.cpp, Python, a separate server, or mock fallback.

Use [onboarding-walkthrough-proof.md](onboarding-walkthrough-proof.md) before editing this table. `./script/check_onboarding_walkthrough_proof.py --print-template` prints the exact row shape with the current commit proof, build verification command, evidence helper commands, and diagnostics/trace paths. The placeholder row below is not evidence; the gate should stay red until a real clean-user run adds a `pass` row with diagnostics or trace line references.

| Time UTC | Build proof | macOS user | Accessibility | Runtime | TextEdit practice | Tab | Shift-Tab | Esc | Pause | Delete traces | Result | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Pending | Pending | Clean tester account | Pending | Pending | Pending | Pending | Pending | Pending | Pending | Pending | Pending | Needs fresh guided TextEdit walkthrough proof. |

## Proof Log

| Date | Build commit | macOS user | Result | Evidence |
| --- | --- | --- | --- | --- |
| Pending | Pending | Clean tester account | Pending | Needs fresh clean-user run. |
| Pending | Pending | Permission denied account | Pending | Needs denial-recovery run. |
