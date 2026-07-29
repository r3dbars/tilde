# Session log — 2026-07-29

What shipped, what was decided, and what was found wrong. Companion to
`2026-07-29-matchmaker-verdict-and-memory-thesis.md`, which holds the
experiment write-up.

## Decisions the owner made

| Decision | Outcome |
|---|---|
| Brain unreachable ⇒ **quiet**, not the Apple fallback | Implemented `1721beeb`. Honest silence over a borrowed personality; the instant dictionary layer keeps working and the menu's health line is the outage signal. Deleted the last route by which a non-personal voice could reach the screen. |
| The product is **Tilde**, everywhere | `91de72dc` + `85df5ee7`. Every user-visible surface. Plumbing identity (bundle ids, data folders, socket) deliberately unchanged — see below. |
| **Mascot: no.** The glyph is the character | A helpful face near your typing is Clippy — the exact fear the product exists to calm. Personality lives in the stroke's gesture, never eyes. Recorded in `docs/brand/BRAND.md`. |
| **The menu bar is the whole app** | `677af9de`. Settings window deleted; ten rows, all real. |

## The plumbing-rename tradeoff (deliberate, not an oversight)

Bundle ids, `Application Support/SteadyType`, `SteadyType-usage`, the socket
path, process names and LaunchAgent labels still say SteadyType. They are how
macOS *knows* the app: TCC grants, `RuntimeSetting` persisted defaults, the
input-source registration, and the capture ferry's byte offsets are all keyed
to them. Renaming them is not a rename, it is becoming a different app and
re-onboarding from zero. Nothing user-visible says SteadyType. Documented in
the header of `script/tilde_deploy.sh`.

## Bugs found today (8), grouped by what caused them

**Two silent no-ops from writing to the wrong key.** The old Tilde window's
`tilde.suggestionsEnabled`, `tilde.soundsEnabled` and `tilde.learningEnabled`
existed *only in that file*; nothing read them, so flipping them did nothing.
Deleting the window exposed it. Then the replacement menu made the same class
of mistake: its Sounds toggle wrote `GhostSoundVolume`, but the keyboard's real
gate is `GhostSoundsEnabled`, checked before anything plays — and the fallback
sounds have hardcoded volumes, so muting by volume wouldn't have silenced them
at all.

> **Rule:** a toggle earns a row only if something reads its key. Keyboard
> settings must be written into the IME's suite (it reads them as its own
> `.standard`); app settings live in the app's domain. Cross-domain confusion
> is invisible at runtime.

**Two from trusting an API name instead of asking the system.** The rename
changed `CFBundleDisplayName`, but `TISCreateInputSourceList` reports the
picker name from `CFBundleName` — System Settings would still have said
"InlineGhostIME" while the new onboarding alert told the user to search
"Tilde". And there is no `tilde` SF Symbol: `NSImage(systemSymbolName:)`
returns nil, so the menu bar silently kept the old keyboard glyph. The mark is
now drawn.

> **Rule:** for anything macOS *displays*, ask macOS what it displays.

**Two in data handling that no test would catch.** The session map keyed by
timestamp alone, while real logs already held 11 cross-app one-second
collisions. And the journal organizer rebuilt day pages from whatever device
files were readable that run — so an offline Mac or an unmaterialised iCloud
file would have silently erased already-published entries. It now renders from
an accumulated content-hashed store, written atomically.

**One crash-forever.** The organizer caught `JSONDecodeError` but not
valid-JSON-that-isn't-an-object; a bare number from a truncated write raised
`AttributeError` and aborted the run. The source stream is append-only, so that
would have broken every future nightly run, not just one.

**One stale comment** promising an Apple fallback deleted the same morning.

Review method: 5 independent reviewers (menu-bar, IME, Python, build, plist),
every finding then handed to an adversarial verifier told to refute it —
**33 raised → 5 confirmed, 28 refuted** — plus 3 found by direct empirical
probing. Two dimensions came back clean.

> **The uncomfortable part:** all 8 lived in code that built cleanly and passed
> 77/77 tests the entire time. Green tests said nothing about a mute switch
> that doesn't mute or a nightly job that deletes your writing.

## Manners batch, graded (shipped 2026-07-27)

Before = Jul 24-26, after = Jul 28-29, personal Mac.

| measure | before | after |
|---|---|---|
| "going to the gym" ghost | 31/day | **0** |
| benched-ghost re-shows | 2,030/day | **86/day** |
| tiny 1-char ghosts | 837/day | **49/day** |
| accept rate | 4.8% | **7.5%** |

All three changes visibly working. **Caveat: the after-window is ~half a day of
real typing** — capture stops 2026-07-28 16:47Z (owner away, brain verified
healthy: socket answers in 109ms, input source still selected, no errors).
Re-grade after a full typing day.

## Kill audit (task #33) — the cleaner is going out of business

4,426 logged kills, Jul 26-28. Prediction graded: `lowValueSingleWordPhrase`
dominates — **right, 72%**. Echo family dominant — **wrong, ~5%**. Persona
filters near zero — close, ~5%.

The finding that outranks the ranking: kills per ghost shown went
**0.66 → 0.05 → ~0** across the manners batch. Suppression moved *upstream*
(confidence floor + mid-line guard prevent junk generations), so the cleaner's
caseload evaporated. The "are filters eating good guesses?" worry is moot at
current volumes. Recommendation: keep all ~15 — the rare-hit ones are cheap
safety nets — and re-audit after a full typing week.

## Open, in the order they gate things

1. **Who is the first outside user?** A name, not a segment. Everything
   downstream bends to it: v1 scope, the first ten minutes, whether the journal
   and matchmaker ship or stay a private edge. This is the real bottleneck —
   the engine is further along than the product story.
2. **Deploy + type-test.** `script/tilde_deploy.sh`, then ten minutes of
   typing. Nothing from today has touched hardware.
3. **#32** — daily `real_app_smoke.sh` schedule, still awaiting an OK.
4. **#31 second half** — periodic chain self-check. Unblocked now that "quiet"
   is the defined failure behaviour.
