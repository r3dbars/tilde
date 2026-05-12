# SteadyType First Run

Use this in the first 10 minutes of a private beta session.

## What Will Happen

- Suggestions appear as a small floating suggestion next to the cursor in
  supported writing apps. They do not become document text until you accept
  them.
- `Tab` accepts one word.
- `Esc` dismisses the suggestion.
- Pause Suggestions stops suggestions everywhere.
- Pause Current App stops suggestions only in the frontmost app.

## Start In TextEdit

1. Open SteadyType Settings.
2. Confirm Accessibility is allowed.
3. Confirm the local model is ready. If it is missing or broken, use
   `Install Local Model` or `Repair Local Model` in Settings. Stop if in-app
   setup fails; do not run Ollama, Python, shell scripts, or a separate model
   server.
4. Click `Start TextEdit Practice`.
5. Type disposable text in the local TextEdit practice file.
6. Press `Tab` once when the next word is clearly useful.
7. Press `Esc` when a suggestion feels wrong.
8. Export only the redacted Privacy Bundle if feedback needs diagnostics.

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
- Chrome local text fields

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

## Stop Immediately

Stop the session if a suggestion appears in the wrong app, wrong field, wrong
spot, search, login, payment, address, URL, secure, or private field.

Also stop if `Tab` submits a prompt, inserts more than expected, duplicates
text, or makes the tester trust the text field less.
