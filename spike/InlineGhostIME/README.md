# InlineGhostIME — the input-method spike (2026-07-22: BREAKTHROUGH)

A minimal macOS input method that renders inline autocomplete suggestions
**inside the focused app's own text** via IMKit marked text — no overlay window,
no caret geometry, no synthetic keystrokes. Validated end-to-end on macOS 26 in
TextEdit, Notes, Obsidian (Electron), Chrome, and Atlas.

The owner declared this the new architecture direction for SteadyType. The
AX + overlay stack is now legacy pending this path maturing.

## What it does

- Commits every printable keystroke immediately (`insertText`), then re-offers a
  suggestion as marked text after the caret — typing feels instant.
- Two prediction layers: an instant tiny predictor (document-vocabulary word
  completion + document bigrams + common next-words) upgraded asynchronously by
  Apple's on-device FoundationModels model (word boundaries only, ≤16 tokens,
  prewarmed session, generation counter drops stale results).
- Multi-word chains (up to 4 words): **Tab accepts one word and keeps the rest
  of the chain marked — no re-rolling. Shift-Tab accepts everything. Esc
  dismisses.** Backspace and shortcuts pass through untouched.
- Context comes from `IMKTextInput.attributedSubstring(from:)` (real document
  read) with a bounded keystroke buffer as fallback.

## Deployment facts (each cost us hours — do not rediscover)

1. **The bundle ID must contain `.inputmethod.`** (`bar.r3d.inputmethod.InlineGhost`).
   Without it, macOS never treats the bundle as an input method. Undocumented.
2. **Notarization is mandatory.** Gatekeeper (`spctl -a -t exec`) must say
   `accepted`; unnotarized IMEs are silently hidden from the System Settings
   picker with no log message. Ad-hoc signatures are rejected outright.
3. **Register with `TISRegisterInputSource`** (see `register.swift`);
   `lsregister` alone is insufficient. Registration is wiped when
   TextInputMenuAgent restarts — just re-run it. The very first appearance in
   the picker additionally required a full restart.
4. **Enabling requires user consent** in System Settings → Keyboard → Input
   Sources (programmatic `TISEnableInputSource` reports success but does not
   persist). macOS shows a "developer can access anything you type" warning.
5. **Styling is app-controlled.** Grey ghost text is impossible for third
   parties: custom attributes (`.foregroundColor`, `.underlineStyle: 0`,
   `.underlineColor: .clear`) are ignored and all four TSM hilite presets render
   identically — a composing underline. Accepted tradeoff.

## Build & install

```bash
./build_and_install.sh
```

One-time notarization setup (needs an app-specific password from
account.apple.com):

```bash
xcrun notarytool store-credentials ghost-notary --apple-id <apple-id> --team-id XG6WL66WUQ
```

Then: System Settings → Keyboard → Input Sources → Edit → `+` → search
"inline" → Add, and switch to it from the menu-bar input picker.

## Next (engineering, not research)

- Swap Apple's model for SteadyType's MLX model — app hosts the engine, IME is
  a thin local-IPC client with fallbacks.
- Papercuts: caret clicks, undo, autocorrect coexistence, dead keys/accents,
  key repeat, Tab's day job in forms/editors, IME crash recovery.
- Onboarding flow that walks users through adding + switching keyboards.
