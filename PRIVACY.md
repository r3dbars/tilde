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
and are not saved as part of ordinary completion requests.

Tilde does not use Accessibility, Screen Recording, OCR, screenshots, the
clipboard, or synthetic key events for autocomplete.

When macOS Secure Event Input is active, Tilde clears any fallback context,
cancels pending work, and does not read, request, or display a suggestion. IMKit
does not expose a general field-sensitivity flag, so custom secret fields must
enable the macOS secure-input signal to receive this protection.

## Personal History

Tilde may retain writing locally when it provides direct user benefit. Personal
writing data remains on the user's device, is controlled by the user, and is
never transmitted for inference, analytics, or training.

Personal History is off by default. When enabled, the input method captures:

- printable text inserted through Tilde's IME path;
- suggestion words the user explicitly accepts;
- a timestamp, a random input-session identifier, and the current app's bundle
  identifier when it is safely available.

This is an insertion history, not a final copy of a document. It does not see
paste operations or edits made outside Tilde, and it can retain characters that
the user later deletes. It does not currently drive prediction, retrieval, or
model training.

Capture stops when Personal History is disabled, when macOS Secure Event Input
is active, when the host app cannot be identified safely, or when the current
app is on the user's exclusion list. IMKit does not expose a general
field-sensitivity flag, so a custom secret field that fails to enable Secure
Event Input cannot be distinguished from an ordinary field.

The Tilde app, not the input method, owns the persistent store. The input method
keeps a small bounded batch in memory and sends it asynchronously over the same
authenticated local Unix socket used for completion. The app rechecks the
master switch and exclusions before writing. If the app remains unavailable,
the bounded queue drops its oldest events rather than blocking typing or
writing from the input-method process.

Records are stored at:

`~/Library/Application Support/Tilde/Personal History/history.v1.enc`

Each record is authenticated and encrypted with AES-GCM. The 256-bit key is a
non-synchronizing, device-only item in the macOS data-protection Keychain. The
directory is owner-only (`0700`) and the file is owner-only (`0600`). The file
header, approximate size, record lengths, and record count are not encrypted.
Local malware running as the user, a process compromise while Tilde is running,
macOS backups or snapshots, and privileged administrators remain meaningful
risks.

Tilde also stores settings and privacy-safe diagnostics such as event names,
timings, counts, lengths, app identifiers, and failure labels. This diagnostics
path does not contain typed text, prompts, model output, or accepted text.
There is no screenshot store, analytics SDK, crash-reporting SDK, cloud sync,
upload, or remote training path.

### Data left by older builds

Updating does not silently delete data a user previously chose to collect.
Personal History does not import or migrate the old learning, trace, or
evaluation stores, but they may still contain writing or screenshots at:

- `~/Library/Mobile Documents/com~apple~CloudDocs/Tilde-usage`
- `~/Library/Application Support/Tilde` and `~/Library/Logs/Tilde`
- `~/Library/Application Support/AutocompleteLab` and `~/Library/Logs/AutocompleteLab`
- `~/.cache/tilde-eval`

Review those locations before removing them. In particular, treat the iCloud
folder as user-owned source data, not as an application cache.

## Network behavior

Autocomplete does not need internet access. Distributed builds contain the
model and a self-contained `llama-server` helper inside the signed app. Tilde
does not download a model at runtime and does not send autocomplete requests to
a cloud service.

The release gate starts an isolated proof-mode app on a dedicated local port and
observes that app and its exact helper child's open sockets while sending a
fixed synthetic prompt directly to the helper. It may append privacy-safe
diagnostics, but it does not quit or change the daily driver. The proof reads
process-table metadata to identify the exact proof app and helper and avoid
other processes; it does not validate or observe sockets of the input method,
or install, launch, or terminate it. Any unexpected remote connection is a
release blocker. This is open-socket observation, not packet capture,
authenticated-socket proof, or a real-editor round trip.

## Control and removal

- Personal History can be turned on or off from Tilde's menu. Turning it off
  immediately stops new capture but does not delete existing history.
- The menu shows the Personal History storage location and approximate encrypted
  size, can exclude or re-include the current app, and can delete all Personal
  History after confirmation. Deletion also turns capture off, rotates the
  local history identifier so queued older events are rejected, and removes
  both the encrypted file and its Keychain key. It is not a promise of forensic
  erasure from backups, snapshots, storage wear-leveling, or previously copied
  files.
- Pause suggestions from Tilde's menu. Quitting stops the menu and model app,
  but the selected input method remains active.
- Switch to another input source when you do not want Tilde handling typing.
- Remove Tilde from System Settings → Keyboard → Input Sources.
- Turn off Tilde in System Settings → General → Login Items.
- To remove current local data, delete the Tilde app,
  `~/Library/Input Methods/InlineGhostIME.app`,
  `~/Library/Application Support/Tilde`, `~/Library/Logs/Tilde`,
  `~/Library/Preferences/bar.r3d.tilde.plist`, and
  `~/Library/Preferences/bar.r3d.inputmethod.InlineGhost.plist`. Review the
  older-version locations above separately.

The [threat model](docs/security/threat-model.md) describes the trust granted to
a macOS input method and the remaining local-process risks.
