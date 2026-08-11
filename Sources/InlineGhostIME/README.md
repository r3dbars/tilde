# InlineGhostIME

Tilde's keyboard is a small IMKit input method. It commits typed characters
immediately and shows suggestions only as marked text in the focused editor.
There is no overlay, candidate panel, Accessibility reader, OCR, or raw-text
learning.

## Keyboard behavior

- Plain `Tab` accepts the whole visible suggestion.
- `Escape` dismisses it.
- `Shift-Tab`, backtick, shortcuts, and navigation keys keep their normal app behavior.
- Typing the next matching grapheme consumes that visible prefix in place. A
  different grapheme hides the old suggestion, inserts normally, and schedules
  a fresh suggestion.
- A 3+ letter partial word gets one deferred `NSSpellChecker` suffix lookup.
- A word boundary gets one request to Tilde's app-owned local model. There is no
  Foundation Models fallback.

Suggestions are bound to the IMKit client, host bundle, context fingerprint,
and selection range. Late model output and stale Tab acceptance are dropped.
Document context is read only after the immediate key callback returns.

## Deployment facts

1. The bundle ID must contain `.inputmethod.`
   (`bar.r3d.inputmethod.InlineGhost`).
2. Notarization is required for the input method to appear in System Settings.
3. Register with `TISRegisterInputSource`; `lsregister` alone is insufficient.
4. Enabling the input method requires user consent in System Settings.
5. Editors control marked-text styling; most render a composing underline.

Build with `./script/build_ime.sh`. Then add Tilde under System Settings →
Keyboard → Input Sources and select it from the keyboard menu.
