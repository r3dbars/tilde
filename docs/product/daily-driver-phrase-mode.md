# Daily Driver Phrase Mode

Last verified: 2026-06-12 from current docs and proof metadata.

This is the current living spec. The long running implementation history moved
to [Daily Driver Phrase Mode Saga](archive/daily-driver-phrase-mode-saga-2026-06-12.md).

## Goal

SteadyType should feel like a typing accelerator, not a cautious word
completer.

Daily-driver phrase mode means:

- predict 3-8 useful next words in normal writing fields,
- show the suggestion before the user thinks about waiting,
- let `Tab` accept the next word or safe chunk,
- keep full-accept limited to surfaces with explicit proof,
- stay quiet in sensitive, prompt, command, search, submit-like, wrong, or
  unsupported fields,
- explain why it stayed quiet when no suggestion appears.

The target is not literal sub-millisecond model inference. The target is an
instant-feeling loop: warm runtime, speculative requests, cached candidates,
fast cancellation, safe fallback phrases, and immediate accept.

## Current Product Stance

Last verified: 2026-06-12.

This remains an experiment until real writing-session dogfood proves people
reach for it and keep it on. The core loop should stay small and local-first.
Do not treat terminal hosts, prompt apps, chat apps, Mail, public browser pages,
Slack, Discord, Google Docs, Notion, or production browser apps as normal
writing support without exact current proof.

Normal writing-app focus is:

- TextEdit
- Notes title, body, and checklist fields
- Obsidian default, theme, pane, and long-note lanes
- Chrome local textarea and local contenteditable fixtures

Terminal-host lanes are parked as of 2026-06-12. Ghostty has useful proof-mode
evidence, but verified insertion is still red, so it is not supported.

## Shipped Behavior

Last verified: 2026-06-12 from this page's prior history plus
`docs/product/steadytype-product-scorecard.md`.

- Default phrase posture aims at 3-8 words.
- User-facing visible phrase cap is 8 words.
- App-owned model phrase length is 8 words / 20 generated tokens.
- Default tuning is Very Proactive.
- Phrase help starts after 2 words.
- Response speed defaults to Instant.
- Confidence defaults to Loose.
- Learned restraint defaults to Low.
- Medium-confidence phrase candidates can pass display scoring.
- Green writing contexts can prefer phrase continuations over word-tail
  completions when there is enough context.
- Old 3-word and 5-word stored defaults migrate to the current short-phrase
  length.
- Very-proactive writing surfaces can ask for phrase continuation at sentence
  boundaries; prompt surfaces stay quiet there.
- Fast typing bursts keep word completion and instant phrase fallback available
  while pausing heavier model continuations.
- Instant phrase source order is doc-local n-gram first, canned writing bridges
  second, and model refinement third. The doc-local corpus stays RAM-only per
  focused writing field, and traces store only source and match-shape metadata.
- Visible fallback phrases can survive soft model suppression when they are
  young, same-field, and not invalidated by typing.
- Risky suppression still hides the suggestion.
- Fresh user typing can replace an old visible suggestion.
- The status surface distinguishes word, phrase, or sentence suggestions and
  whether the source is instant fallback, fast word fallback, or model path.
- Quiet states explain common reasons such as no useful suggestion, no cursor
  position, repeated miss, stale text, model error, or learned restraint.

## Current Proof Scorecard

Last verified: 2026-06-12 from
`docs/product/steadytype-product-scorecard.md`,
`docs/product/proof-manifest.json`, and the archived saga.

| Area | Current read | Next proof |
| --- | --- | --- |
| Suggestion quality | 95/100 in the current product scorecard. Deterministic quality checks and disposable local-model audit are green, but this is still not enough real accepted-kept volume. | Run a real writing dogfood session, fill the Manual Trust Row, and review the report. |
| Placement reliability | Strict manual smoke is green for TextEdit, Notes title/body/checklist, Obsidian default/theme/pane/long-note, Chrome textarea, and Chrome contenteditable, with 2 verified accepts and strict visual trace evidence. | Keep prompt/chat/terminal/production-browser support blocked until exact current proof exists. |
| Typing speed | Subsecond repaired phrase results, TextEdit model-latency proof, cold TextEdit phrase proof, and instant fallback metadata are documented. | Prove the loop in a real fast-typing dogfood session, not just harness runs. |
| Wrong-field safety | Prompt no-submit and sensitive-field proof self-tests are in the default smoke path; dogfood gates fail on trust-killer trace signals. | Refresh live prompt no-submit and sensitive-field trace slices when support claims change. |
| Daily-driver feel | The report wrapper can enforce real-sized trace samples, 3+ word phrases, <=1ms instant fallback, source mix, no-show reasons, redacted typing-feel score, and manual trust review. | One full human writing session where the user says they reached for it and would keep it on tomorrow. |

Current scorecard link:
[SteadyType Product Scorecard](steadytype-product-scorecard.md).

Current proof manifest link:
[Proof Manifest](proof-manifest.json).

## Proof Claims That Are Current

Last verified: 2026-06-12.

- `./script/manual_smoke_status.sh --strict` is documented as passing on
  2026-05-28 at commit `1969992ddcf5`.
- Current or source-compatible strict visual rows exist for TextEdit, Notes
  title/body/checklist, Obsidian default/theme/pane/long-note, Chrome textarea,
  and Chrome contenteditable.
- Each of those beta-safe writing rows records 2 accepted insertions and strict
  visual trace evidence.
- The single current product scorecard is
  `docs/product/steadytype-product-scorecard.md`, not older scorecards.
- The proof manifest marks TextEdit, Notes, and Obsidian complete, Chrome
  partial/local-fixture-only, prompt apps proof-gated, Mail blocked, and Ghostty
  not supported for normal use.

## Experiments

Last verified: 2026-06-12.

These are useful but do not widen support by themselves:

- instant phrase fallback families for writing bridges, markdown note labels,
  reply starts, field-safety language, and daily-driver complaint language,
- accepted-and-kept learned restraint for instant phrases,
- proof-only Codex prompt lanes,
- terminal-host / Claude Code / Ghostty proof lanes,
- disposable local quality audits,
- current dogfood report tooling.

Ghostty is explicitly red for support: prompt-row placement and accept routing
have proof-mode evidence, but verified app-owned insertion still fails closed.

## Planned Work

Last verified: 2026-06-12.

1. Run the real daily-driver dogfood session in an ordinary writing app.
2. Fill the Manual Trust Row.
3. Run:

   ```sh
   ./script/daily_driver_dogfood_session.sh review --report <report-path>
   ```

4. Keep raw content opt-in only. Use redacted metadata by default.
5. Re-score this page and the product scorecard only from current proof.
6. Do not graduate new app surfaces without exact current proof for placement,
   insertion, no-submit/wrong-field safety, and user-visible quiet reasons.

## Manual Dogfood Requirement

Last verified: 2026-06-12 from
`script/daily_driver_dogfood_session.sh` references in nearby docs.

The app is not daily-driver proven until a human writing session passes both
automated and manual gates.

Required session shape:

- SteadyType confirmed running at start.
- At least 5 active minutes.
- At least 5 shown suggestions.
- At least 1 phrase suggestion.
- At least 1 instant phrase fallback with <=1ms recorded latency.
- At least 1 accepted suggestion.
- At least 1 accepted-and-kept signal.
- Accepted-kept / shown reach rate of at least 15%.
- Redacted typing-feel score of at least 85/100.
- No wrong-context suppression, failed/duplicate insertion, sensitive-field
  display, unsupported-app display, prompt-submit risk, unsafe full accept,
  detached placement, focus steal, Tab conflict, accepted-then-deleted signal,
  or prompt content violation.
- Manual trust row filled.
- User says they reached for the suggestion.
- Suggestion quality scored 4 or 5.
- User says they would keep it on tomorrow.

Start/status/finish flow:

```sh
./script/daily_driver_dogfood_session.sh status --app <bundle-id>
./script/daily_driver_dogfood_session.sh start --app <bundle-id> --label <label>
./script/daily_driver_dogfood_session.sh finish --app <bundle-id>
./script/daily_driver_dogfood_session.sh review --report <report-path>
```

## Support Boundaries

Last verified: 2026-06-12 from `docs/product/proof-manifest.json`.

Supported or user-toggle allowed with current proof:

- TextEdit
- Notes
- Obsidian, with renderer-accessibility caveats from the proof history
- Chrome local textarea/contenteditable fixtures only

Proof-only or blocked:

- Codex prompt composer: proof-only, one-word/full-accept no-submit lanes only.
- Claude Code / terminal hosts: proof-only or disabled.
- Ghostty: unsupported until verified one-word no-submit insertion exits green.
- ChatGPT / Atlas / browser prompt apps: disabled or proof-gated.
- Mail: blocked.
- Messages: proof mode only.
- Public browser pages and production browser apps: blocked until exact proof.

## Rules For Future Edits

Last verified: 2026-06-12.

- Keep this page current and short.
- Move saga detail to the archive page.
- Add a `Last verified` line for factual claims.
- Separate shipped behavior, experiments, planned work, and manual proof.
- Link to proof instead of pasting long proof logs.
- Treat stale proof as historical, not green.
- Keep "unknown" as unknown.
- Never turn a proof-only lane into support language without current live proof.
