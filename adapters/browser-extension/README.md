# Browser Extension Adapter

This is the right path for Safari, Chrome, Arc, Brave, and normal web text boxes.

The macOS Accessibility overlay cannot reliably become true inline ghost text in browser editors. A content script can see the DOM selection, measure the caret, render a ghost span/overlay, and insert accepted text without touching the pasteboard.

Current prototype:

- Tracks `input`, `textarea`, and simple `contenteditable` fields.
- Shows a quiet fixed-position ghost hint near the DOM caret.
- Accepts the next word with `Tab`.
- Dismisses with `Escape`.
- Asks the extension background for suggestions.
- Falls back to a local mock suggestion until native messaging is wired to the macOS app.

The prototype is intentionally limited to local proof pages: `localhost`,
`127.0.0.1`, and `[::1]`. Do not broaden it to production websites without a
site allowlist, field policy, and native-host revalidation.

Load this as an unpacked extension in Chrome/Arc/Brave for early testing.
