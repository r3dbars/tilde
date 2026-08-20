# Tilde Privacy

Tilde is local-only by design.

## What Tilde reads

While Tilde is the active input method, IMKit gives it keystrokes and access to
the current text-input session. Tilde uses a bounded amount of text before the
cursor to ask its local model for a continuation. It inserts text only when you
accept a visible suggestion.

The input method sends that bounded context to the Tilde app through an
owner-only Unix socket on this Mac. The app passes it to the verified local
Gemma 4 E2B model in Tilde's external app-support storage and returns the
suggestion. Context and output are used in memory for that request and are not
saved as part of ordinary completion requests.

Tilde does not use Accessibility, screenshots as stored images, the
clipboard, or synthetic key events for autocomplete. It does use Screen
Recording and on-device OCR — as of 2026-08-16 this is required, not
optional: see "Screen Memory" below for what is captured, when, how it is
redacted, and why Tilde will not suggest anything at all without this
permission.

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
fixed Gemma 4 E2B model. Accepted Tilde suggestions are excluded from learning
and scoring.

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

## Screen Memory

Status: shipped and on by default for new installs (2026-08-16 owner
directive: Screen Memory is required, not opt-in — Tilde's suggestions
depend on it, so Screen Recording permission is required for Tilde to
suggest at all; see "Screen Recording permission is required" below). It
replaces the prior blanket ban on OCR and Screen Recording recorded in
`AGENTS.md`; the reversal and its reasoning are on the record there.

What is actually implemented today: full-display capture, on-device OCR, and
folding the redacted result into the prompt sent to Tilde's local model —
all memory-only. Persisting screen-derived text to disk, a dedicated storage
meter, and a model-based redaction layer (beyond the rules layer described
below) are a later phase of `docs/plans/screen-memory.md` and are not built
yet; nothing screen-derived is written to disk by Tilde today.

**The privacy boundary is the device, not the capture.** Because nothing
Screen Memory sees ever leaves the Mac, Tilde is designed to capture and
retain more than a cloud product safely could. On-device-only is
non-negotiable, but it is not proven the same way autocomplete is: the
release egress proof (`script/package_app.sh`) still only runs its original
autocomplete stimulus, so a packaged build's open sockets have never
actually been observed during a live capture, OCR, or redaction pass. That
packaged capture-and-redaction stimulus (enable the toggle, trigger a
synthetic capture and a redaction pass, observe open sockets throughout)
remains unbuilt. Screen Memory now ships and runs by default without it —
this is a known gap, not a design choice, and it should be closed before the
next release; until it is, Screen Memory's on-device-only claim rests on
code review and manual testing rather than a blocking, packaged proof.

**What is captured.** With Screen Memory enabled, Tilde takes a full-display
screenshot, runs on-device OCR (Vision framework) over it, and keeps only the
recognized text and its position on screen — never the image itself. State it
plainly: this includes text belonging to the other side of a conversation
(a Messages thread, a Slack DM, an email you're reading) whenever it is
visible on screen, not only text you typed. Tilde cannot tell your writing
apart from someone else's in a screenshot; if a person or a channel should
never be captured, exclude the app that shows it.

**When it is captured.** Capture is event-driven, not continuous: on a
focused-window change, and on a typing pause of two seconds or more while a
completion session is active, with a hard cap of one capture per five
seconds. Tilde captures nothing while the master toggle is off, while the
screen is locked, or while macOS Secure Event Input is active. The toggle
defaults to ON for new installs as of 2026-08-16 (an existing install's
explicit choice to turn it off persists across updates). Because capture is
full-display, exclusion cannot check only the frontmost app: Tilde skips the
capture entirely if *any* visible window — frontmost or behind it — belongs
to an app on the exclusion list shared with Personal History, so an excluded
app (a password manager, a chat client) stays protected even when some
other, non-excluded app is focused on top of it. Tilde makes a best-effort
attempt to skip known private-browsing windows; browsers vary in whether
this is reliably detectable, so private windows are a best-effort exclusion,
not a guarantee — use app exclusion for certainty.

**Screen Recording permission is required.** Screen prediction is Tilde's
core differentiator, so as of 2026-08-16 Tilde will not answer a completion
request with a suggestion at all unless Screen Memory is turned on AND
macOS has granted Screen Recording access — turning the toggle off, or
macOS withholding or revoking the permission, silences every suggestion,
not just screen context. On first launch, if the permission is missing,
Tilde shows a plain-language explanation of what is captured and why, with
one button that triggers the system permission prompt and one that opens
System Settings → Privacy & Security → Screen Recording directly. Tilde does
not crash, hang, or become otherwise unusable without the permission: the
menu bar stays present and shows a persistent, honest status line (for
example, "Screen Memory: needs Screen Recording access — Tilde is not
suggesting") with the same one-click path to fix it. This is a deliberate
product trade-off, not an oversight — it accepts that a denied permission
makes Tilde feel silent in exchange for never shipping a suggestion made
without the screen context the product is built around.

**Redaction, today.** Before any screen-derived text is folded into a
completion prompt, a structured-secret rules pass scrubs card numbers,
IBANs, SSNs, API-key shapes, JWTs, PEM blocks, email addresses, and phone
numbers, replacing each with a `⟨redacted:type⟩` token. This is the rules
layer only; the model-based layer described in `docs/plans/screen-memory.md`
(catching freeform secrets the rules cannot recognize structurally) is not
built yet. Raw screen text never appears in logs, diagnostics, or any
report.

**What never persists.** Nothing screen-derived is written to disk today —
captured and OCR'd screen text lives only in memory for the current
completion request and is discarded once used or replaced by a fresher
capture. When Screen Memory's persistence phase ships (tracked in
`docs/plans/screen-memory.md`), the covenant requires redaction to run
before any storage and fail closed — a redactor error must drop the capture
rather than store it raw, never the reverse — and password managers and
password fields (Secure Event Input) will remain excluded regardless of
user settings, the same as the memory-only path today.

**Where it lives.** Nowhere yet: there is no on-disk store for screen text.
When Screen Memory's persistence phase ships, the covenant requires it to
use its own event type in the same encrypted, append-only Personal History
store described above, at the same path, under the same AES-GCM key in the
user's login Keychain, with the same owner-only file permissions, subject to
its own rolling retention budget (256 MB by default, oldest-first pruning)
separate from Personal History's own budget.

**How screen text is used.** Screen-derived text is classified into a scene
(replying, referencing something on screen, or plain composing) and folded
directly into the prompt sent to Tilde's local model for the current
suggestion only. It is not stored and does not train anything today. Screen
text does not leave the device and is not used for analytics. When Screen
Memory's persistence phase ships, a separate conversation-context table
populated from stored screen events is planned to inform future
suggestions; the covenant requires that table to stay wholly separate from
the table that models how *you* write — only text you actually typed will
ever train that one — and any future fine-tuning of the fixed Gemma 4 E2B model will
remain an explicit, separate user action.

**Controls and deletion.** Screen Memory ships ON by default for new
installs (an existing install's explicit choice to turn it off persists
across updates). The menu shows a Screen Memory toggle, the same per-app
exclusion list Personal History uses, and a live status line stating
exactly why capture or suggestions are paused whenever they are, with a
one-click path to grant Screen Recording access or open System Settings.
There is no separate storage meter or delete-all specific to Screen Memory
yet, because nothing screen-derived persists to disk yet (see above) —
there is nothing to meter or delete. When persistence ships, the covenant
requires deleting Personal History to delete Screen Memory's events with
it — same store, same encrypted file, same Keychain key — and destroying
that key is what makes the deletion irreversible, with the same caveats
about backups, snapshots, and wear-leveling that apply to Personal History
today.

## Network behavior

Autocomplete does not use the internet after setup. The signed app contains
the `llama-server` helper but deliberately does not contain the 3.2 GB model.
During first-run setup, Tilde's separate asset phase downloads exactly one
fixed model file, `gemma-4-E2B.Q4_K_M.gguf`, from this immutable Hugging Face
revision URL:

`https://huggingface.co/mradermacher/gemma-4-E2B-GGUF/resolve/3762686d74ff8db6c98f8d3c389f56fbdf994d5a/gemma-4-E2B.Q4_K_M.gguf`

The download is resumable and is accepted only when the final file is exactly
3,427,861,984 bytes with SHA-256
`389c868898bffed97fd178646f88562cafecc6f60983a636bac53b131fd068a2`; an
interrupted or mismatched file is not used by the runtime. The request contains
no typed text, screen text, prompt, history, suggestion, or other user-derived
content. The model host can still see ordinary transport metadata such as the
client IP address, request time, and fixed asset URL.

After verification, model startup and all autocomplete, Screen Memory, and
Personal History work are local. Tilde does not send autocomplete requests to a
cloud service, and it has no remote inference fallback.

The release gate takes a preseeded copy of the pinned model as an explicitly
named proof-only input and places it in isolated external storage; it never
puts that file in `Tilde.app`. It then starts the exact packaged app and helper
on a dedicated local port and observes their open sockets while sending a fixed
synthetic prompt directly to the helper. This is the post-download steady-state
lane: any unexpected non-loopback connection is a release blocker. The proof
reads process-table metadata to identify the exact proof app and helper and
avoid other processes; it does not validate or observe sockets of the input
method, or install, launch, or terminate it. This is open-socket observation,
not packet capture, download-phase proof, authenticated-socket proof, or a
real-editor round trip.

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
