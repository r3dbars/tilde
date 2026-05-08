# Private Beta Plan

Goal: learn whether Autocomplete Lab makes real writing easier without hurting
trust.

This is still an experiment. Do not treat it as a Transcripted feature or a
general release.

## Before Inviting Anyone

Run the full gate:

```bash
./script/beta_readiness.sh
```

That must create and verify:

- `dist/AutocompleteLab.zip`
- `dist/private-beta/README.md`
- `dist/private-beta/install-checklist.md`
- `dist/private-beta/feedback-log.md`
- `dist/private-beta/session-report.md`
- `dist/private-beta/privacy-status.md`
- `dist/private-beta/checksums.txt`

Also read:

- `docs/product/beta-readiness-checklist.md`
- `docs/product/compatibility-matrix.md`
- `docs/product/privacy-and-controls.md`

If the build needs a user-started model server, tester-side Python setup,
Ollama, llama.cpp, or mock fallback, do not invite testers.

The generated private-beta packet must also keep tester model setup inside the
app. If the model is missing or invalid, testers should use Settings
`Install Model` or `Repair Model`; if that in-app setup fails, stop the session
instead of giving testers shell commands.

The tester install path is inside Settings. If the model is missing, use
`Install Local Model`; if the folder is incomplete, use `Repair Local Model`.
Do not ask testers to run shell or Python commands.

## Test Shape

- 4 users.
- 10 days.
- Each user gets one day-zero onboarding call.
- Each user does at least 5 short writing sessions.
- Each session ends with a redacted local report export.
- Keep the main question simple: did the suggestion help, or did it get in the
  way?

Target coverage across the beta:

- TextEdit.
- Notes.
- Chrome local textareas.
- Obsidian or another CodeMirror editor.
- One Electron writing app, such as Codex dogfood if available.
- Mail compose as diagnostics-only until insertion is proven safe.

Do not count Mail as supported writing coverage. It stays blocked for insertion
until the compatibility gates say otherwise.

## Day Zero

Walk each tester through this in 15 minutes or less:

- Privacy promise: default traces are redacted and local; raw text and
  screenshots are debug-only opt-ins.
- Pause/disable controls: menu bar `Disable <App Name>`, Diagnostics `Pause
  Tracing`, and Diagnostics `Delete Traces`.
- Smoke check: open TextEdit, type a normal sentence, accept one word with
  `Tab`, dismiss with `Esc`, then export the redacted report.
- Stop rules: one wrong insertion, sensitive-field suggestion, unreliable
  `Tab`, mock fallback, failed in-app model setup, or tester-side shell/Python
  setup ends the beta.

## Daily 2-Minute Survey

Ask once per day:

- What app did you write in most?
- One magic moment?
- One annoying moment?
- Best app?
- Worst app?
- Did you pause or disable anything? Why?
- Did `Tab` ever surprise you?
- Did anything appear in search, login, payment, address, or other sensitive
  fields?

## Forced Edge Cases

Each tester should try these once during the beta:

- Type in a search field and confirm no suggestion appears.
- Type in a login or password field and confirm no suggestion appears.
- Type in a short form field and confirm no suggestion appears.
- Switch apps while a suggestion is visible.
- Press `Tab` for one-word accept.
- Press `Esc` to dismiss.
- Accept text, then delete it right away.
- Export a redacted local report after the session.

## Midweek Check-In

On day 5 or 6, do one 15-minute check-in:

- Review the daily survey answers.
- Open Diagnostics and export the redacted report.
- Check accepted-and-kept, p95 latency, insertion success, caret failures, app
  disables, and top failure reasons.
- Fix the highest trust issue before adding more beta time.

## Exit Interview

Ask at the end of day 10:

- Would you miss this if it disappeared?
- Where did it help most?
- Where did it feel annoying?
- Did it ever make you trust your text field less?
- Which app should stay on?
- Which app should stay off?
- What should be simpler before another beta?

## Stop Conditions

Stop the beta immediately if any of these happen:

- wrong insertion,
- duplicate insertion,
- focus steal,
- suggestion in a search, login, secure, payment, address, or private field,
- unreliable `Tab`,
- accepted text gets deleted within 2 seconds often enough to show annoyance,
- local runtime falls back to mock output,
- tester must manually start or manage a model server,
- model asset setup requires tester-side Python or shell steps.

## After Each Session

Record one lightweight row in:

```text
dist/private-beta/feedback-log.md
```

Then export the redacted report from Diagnostics. The manual note should only
capture:

- one magic moment,
- one annoying moment,
- best app,
- worst app,
- pause or disable reason.

Do not paste raw typed text, prompts, screenshots, document names, URLs,
recipients, subject lines, or trace excerpts into beta feedback. Use short
labels like `wrong app`, `late`, `too much`, or `good word finish`.

Run the trace checker before trusting the session:

```bash
./script/check_trace_eval.sh
./script/model_latency_report.py --default-model-proof
```

Fix the top repeated trust miss before inviting another tester.
