# Quiet Unless Invited Beta Pass

This pass turns the IBus Typing Booster lesson into a SteadyType rule: stay
quiet by default, but let the user ask once when they actually want help.

## Shipped

- `Control-Backtick` requests one suggestion for the current focused field.
- `Control-Backtick` also routes through the active key-capture path when a
  suggestion is already visible, so it never turns into whole-suggestion accept.
- `Tab` still only accepts the next word when a suggestion is visible.
- Whole-suggestion accept stays on its separate configured shortcut.
- Manual summon bypasses cadence delay only; it still respects pause, app
  enablement, runtime readiness, secure-field suppression, browser/form blocks,
  prompt-app gates, sensitive-field gates, and insertion proof.
- Settings now has a Trust section that shows local mode, typed-text storage
  state, current app status, and the current reason SteadyType is quiet or
  active.

## Product Rule

Use summon for beta feedback like: "I expected help here." Do not use it to
force suggestions into passwords, sign-ins, URLs, search boxes, private notes,
prompt send boxes, or unsupported apps. Those should continue to fail closed.

## Proof

- Unit proof: shortcut copy, summon descriptor, and Trust-state copy.
- Manual proof: run TextEdit/Chrome disposable smoke and press
  `Control-Backtick` before waiting for cadence. A pass requires a
  `manual-summon` request trace, a visible suggestion, and unchanged `Tab`
  one-word acceptance.
- Privacy proof: raw typed text remains off unless raw trace or Personal Capture
  is explicitly enabled.

## Next Checks

- TextEdit: summon after a short fragment, then `Tab` once.
- Chrome local textarea/contenteditable: summon should work only in local proof
  fixtures.
- Notes/Obsidian: manual-gated only, disposable content only.
- Prompt apps: one-word no-submit proof only; full accept remains disabled.
