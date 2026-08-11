# Tilde Privacy

Tilde is local-only by design.

## What Tilde reads

While Tilde is the active input method, IMKit gives it keystrokes and access to
the current text-input session. Tilde uses a bounded amount of text before the
cursor to ask its local model for a continuation. It inserts text only when you
accept a visible suggestion.

The input method sends that bounded context to the Tilde app through an
owner-only Unix socket on this Mac. The app passes it to its bundled model and
returns the suggestion. Context and output are used in memory for that request
and are not saved.

Tilde does not use Accessibility, Screen Recording, OCR, screenshots, the
clipboard, or synthetic key events for autocomplete.

## What is stored

Tilde stores only settings and privacy-safe diagnostics such as event names,
timings, counts, lengths, app identifiers, and failure labels. Diagnostics do
not contain typed text, prompts, model output, or accepted text.

There is no writing history, raw trace, personal learning store, screenshot
store, analytics SDK, crash-reporting SDK, or cloud sync path.

### Data left by older builds

Updating does not silently delete data a user previously chose to collect.
Current Tilde does not read or migrate the old learning, trace, or evaluation
stores, but they may still contain writing or screenshots at:

- `~/Library/Mobile Documents/com~apple~CloudDocs/Tilde-usage`
- `~/Library/Application Support/Tilde` and `~/Library/Logs/Tilde`
- `~/Library/Application Support/AutocompleteLab` and `~/Library/Logs/AutocompleteLab`
- `~/.cache/tilde-eval`

Review those locations before removing them. In particular, treat the iCloud
folder as user-owned source data, not as an application cache.

## Network behavior

Autocomplete does not need the network. Distributed builds contain the model
and a static `llama-server` helper inside the signed app. Tilde does not
download a model at runtime and does not send autocomplete requests to a cloud
service.

The release gate observes the running app, input method, and exact helper
child's open sockets while sending a fixed synthetic prompt directly to that
helper. Any unexpected remote connection is a release blocker. This is
open-socket observation, not packet capture or a real-editor round trip.

## Control and removal

- Pause suggestions or quit Tilde from its menu.
- Switch to another input source when you do not want Tilde handling typing.
- Remove Tilde from System Settings → Keyboard → Input Sources.
- Delete the Tilde app, `~/Library/Input Methods/InlineGhostIME.app`,
  `~/Library/Application Support/Tilde`, and `~/Library/Logs/Tilde` for a full
  local removal. Review the older-version locations above separately.

The [threat model](docs/security/threat-model.md) describes the trust granted to
a macOS input method and the remaining local-process risks.
