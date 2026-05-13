# SteadyType First Run

Use this in the first 10 minutes of a private beta session.

## What Will Happen

- Suggestions appear near the cursor in supported writing apps.
- `Tab` accepts one word.
- `Esc` dismisses the suggestion.
- Pause Suggestions stops suggestions everywhere.
- Disable Current App stops suggestions only in the frontmost app.

## Start In TextEdit

1. Open SteadyType Settings.
2. Confirm Accessibility is allowed.
3. Confirm the local model is ready.
4. Click `Start TextEdit Practice`.
5. Type disposable text in the local TextEdit practice file.
6. Press `Tab` once when the next word is clearly useful.
7. Press `Esc` when a suggestion feels wrong.
8. Export only the redacted Privacy Bundle if feedback needs diagnostics.

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

Use these for beta writing:

- TextEdit
- Notes
- Obsidian
- Chrome local text fields

Use these only as proof targets:

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

## Stop Immediately

Stop the session if a suggestion appears in the wrong app, wrong field, wrong
spot, search, login, payment, address, URL, secure, or private field.

Also stop if `Tab` submits a prompt, inserts more than expected, duplicates
text, or makes the tester trust the text field less.
