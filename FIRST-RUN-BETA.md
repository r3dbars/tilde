# SteadyType First Run

Use this in the first 10 minutes of a private beta session.

## First Screen Must Say

- Suggestions appear as a small floating suggestion next to the cursor in
  supported writing apps. They do not become document text until you accept
  them.
- `Tab` accepts one word.
- `Esc` dismisses the suggestion.
- Pause Suggestions stops suggestions everywhere.
- Pause Current App stops suggestions only in the frontmost app.
- Typed text and model output stay on this Mac by default.

## Start In TextEdit

1. Open SteadyType Settings.
2. Confirm the first screen explains the map above before any macOS prompt.
3. Click `Allow Accessibility`, then grant Accessibility in System Settings.
4. Return to SteadyType and confirm Accessibility shows as allowed without
   restarting.
5. Confirm the local model is ready. If it is missing or broken, use
   `Install Local Model` or `Repair Local Model` in Settings. Stop if in-app
   setup fails; do not run Ollama, Python, shell scripts, or a separate model
   server.
6. Click `Start TextEdit Practice`.
7. Type disposable text in the local TextEdit practice file.
8. Confirm the floating suggestion appears next to the cursor.
9. Press `Tab` once when the next word is clearly useful.
10. Press `Esc` when a suggestion feels wrong.
11. Export only the redacted Privacy Bundle if feedback needs diagnostics.

After a tester walkthrough, record the row in
`docs/product/onboarding-permission-qa-checklist.md` and run
`./script/check_onboarding_walkthrough_proof.py`. The row must prove the app
owned the runtime; testers should not start Ollama, llama.cpp, Python, or a
separate model server.

## What Stays Local

Typed text, prompts, model output, accepted text, screenshots, document names,
URLs, recipients, and subject lines stay on this Mac by default.

Default diagnostics are local and redacted. They can include app bundle IDs,
field kind, timing, counters, failure labels, and text lengths.

## Supported Test Apps

Write-test only in these apps:

- TextEdit
- Notes
- Obsidian
- Chrome included local practice pages

Do not write-test these as normal beta apps. Use them only as proof targets:

- Codex
- Claude
- Claude Code terminal-host proof

These stay off until proof says otherwise:

- Mail
- Atlas
- Slack
- Discord
- Notion
- search, login, payment, address, URL, secure, and private fields

## Proof Still Pending

Do not describe first-run proof as complete yet.

- [ ] Fresh clean-user install: first macOS Accessibility prompt appears only
  after `Allow Accessibility`.
- [ ] Accessibility denial and regrant: app stays calm while denied, shows no
  suggestions while denied, and practice works again after regrant.

## Stop Immediately

Stop the session if a suggestion appears in the wrong app, wrong field, wrong
spot, search, login, payment, address, URL, secure, or private field.

Also stop if `Tab` submits a prompt, inserts more than expected, duplicates
text, or makes the tester trust the text field less.
