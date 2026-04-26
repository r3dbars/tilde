# Private Beta Plan

Goal: find out whether Autocomplete Lab helps real writing without breaking
trust.

Run this before inviting anyone:

```bash
./script/beta_readiness.sh
```

That creates:

- `dist/AutocompleteLab.zip`
- `dist/private-beta/README.md`
- `dist/private-beta/install-checklist.md`
- `dist/private-beta/feedback-log.md`
- `dist/private-beta/checksums.txt`

## Test Shape

- 3-5 people.
- One week.
- Start in TextEdit.
- Then Notes.
- Then Obsidian if they already use it.
- Chrome textarea is only a sanity check.

## What To Watch

- Did Tab feel predictable?
- Did word completion feel instant?
- Did suggestions appear in the right place?
- Did suggestions feel helpful or distracting?
- Did anything insert in a surprising place?
- Did the app ever appear in a private or unsupported field?

## Stop Conditions

Stop the beta if:

- insertion happens in the wrong app,
- a suggestion appears over sensitive text,
- Tab becomes unreliable,
- the local model falls back to mock output,
- the app needs manual model/server setup.

## After Each Session

Record one row in:

```text
dist/private-beta/feedback-log.md
```

Then run the trace eval panel or trace analyzer and fix the top repeated miss
before adding more testers.
