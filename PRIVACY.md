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
- a timestamp, a random contiguous-writing segment identifier, and the current
  app's bundle identifier when it is safely available.

This is an insertion history, not a final copy of a document. It does not see
paste operations or edits made outside Tilde, and it can retain characters that
the user later deletes. IMKit also has no stable field identifier: Tilde breaks
writing segments on known caret, app, editing, and composition changes, but a
same-app field switch at the same caret with no composition callback can join
one writing context in the shadow experiment. The app rebuilds two bounded,
memory-only personal next-word recipes from manually typed history. Replay
rebuilds learned contexts but is not scored. On fresh eligible word boundaries,
both recipes freeze a prediction from the same prior authored words, compare it
with the same next authored word, and learn only afterward. This paired shadow
experiment does not change visible suggestions, perform retrieval, or train the
bundled model. Accepted Tilde suggestions are excluded from learning and scoring.

Capture stops when Personal History is disabled, when macOS Secure Event Input
is active, when the host app cannot be identified safely, or when the current
app is on the user's exclusion list. IMKit does not expose a general
field-sensitivity flag, so a custom secret field that fails to enable Secure
Event Input cannot be distinguished from an ordinary field.

The Tilde app, not the input method, owns the persistent store. The input method
keeps a small bounded batch in memory and sends it asynchronously over the same
authenticated local Unix socket used for completion. The app rechecks the
master switch and exclusions before writing. If the bounded queue fills, it
drops the affected unsent writing segment rather than blocking typing or
writing from the input-method process.

Records are stored at:

`~/Library/Application Support/Tilde/Personal History/history.v1.enc`

Each record is authenticated and encrypted with AES-GCM. The 256-bit key is a
non-synchronizing item in the user's macOS login Keychain. The directory is
owner-only (`0700`) and the file is owner-only (`0600`). The file header,
approximate size, record lengths, and record count are not encrypted. The login
Keychain can migrate with a copied or restored user Keychain; this is not a
device-bound key. Local malware running as the user, a process compromise while
Tilde is running, macOS backups or snapshots, and privileged administrators
remain meaningful risks.

The stable filename contains `v1` for compatibility with existing installs. Its
same-length header is upgraded from format 1 to format 2 before the first new
batch append; format 2 stores each event batch and its optional aggregate
checkpoint as one authenticated record. Tilde continues to read legacy format-1
event records. Rolling back requires restoring the pre-upgrade history-file
backup as well as the older app.

While Tilde is running, the paired shadow necessarily holds derived word
contexts and transition counts in process memory. At launch it restores a
bounded aggregate checkpoint, then rebuilds both recipes from the most recent
complete events in a 4 MiB encrypted-history window without adding replayed
events to the score. It learns and scores only new allowed events while Tilde
keeps running. Because the tail can begin partway through a writing stream, the
predictor discards the first possibly truncated token before learning it. Replay
work and decrypted replay memory stay bounded as the encrypted corpus grows.
The derived model also has a fixed capacity, and the menu explicitly reports
when that capacity is reached.

The checkpoint is encrypted in the same app-owned history-log append as the
fresh batch it scores. It stores only lifetime aggregate totals plus at most 64
aggregate UTC-day buckets. Its
fields are the two fixed recipe identifiers, evaluation start time, a 3-by-3
silent/correct/wrong outcome table, disagreement count, and daily versions of
those same counts. A small envelope binds it to the exact local history
identifier, durable exclusion generation, and exact excluded-app set. It stores no words, contexts, candidate
text, per-case rows, session identifiers, or per-case app identifiers. Tilde
computes it before storage, writes the events and checkpoint together, then
publishes the in-memory result and acknowledges the batch. Writing that arrives
while startup replay is loading is stored and used for training but is not added
to the score. A corrupt, stale-generation, or mismatched checkpoint is rejected.

A corrupt store or missing Keychain key makes history replay and writes fail
closed when the problem is encountered. Appends authenticate the most recent
existing record before writing; launch replay authenticates records inside its
recent window. Older corruption outside that window may remain undetected.
Ordinary autocomplete continues, and deleting Personal History is the recovery
path.

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
  immediately stops new capture and shadow evaluation but does not delete
  existing history or its encrypted aggregate checkpoint. Re-enabling restores the
  aggregate and rebuilds learned contexts from retained, non-excluded history.
- The menu shows the Personal History storage location and approximate encrypted
  size, can exclude or re-include the current app, and can delete all Personal
  History after confirmation. Changing the exclusion set logically clears the
  aggregate checkpoint by rotating a durable experiment generation. Old
  aggregate checkpoints cannot revive if an exclusion set is later restored;
  retained event history is filtered under the current exclusions. Deletion also
  turns capture off, rotates the
  local history identifier so queued older events are rejected, and removes
  both the encrypted file and its Keychain key. It also clears the in-memory
  next-word predictor and aggregate shadow result. It is not a promise of
  forensic erasure from backups, snapshots, storage wear-leveling, or
  previously copied files.
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
