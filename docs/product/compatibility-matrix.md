# Compatibility Matrix

Current beta-readiness stance for the lab build. This is not a promise that an
app is broadly supported. It is a local proof gate for a tiny beta.

## Support Gates

An app is `supported` only when the trace evaluator shows:

- at least 20 shown suggestions,
- at least 3 accepted-and-kept suggestions,
- accepted-and-kept shown rate at or above 15%,
- insertion verification at or above 98%,
- p95 first-visible latency at or below 750ms,
- zero caret failures,
- actionable suppression at or below 15%,
- annoyance score at or below 0.10.

An app is `caveated` when it has enough clean proof for a guarded beta:

- at least 10 shown suggestions,
- at least 1 accepted-and-kept suggestion,
- accepted-and-kept shown rate at or above 8%,
- insertion verification at or above 95%,
- p95 first-visible latency at or below 1000ms,
- caret failure rate at or below 5%,
- annoyance score at or below 0.20.

Any wrong insertion, duplicate insertion, focus steal, major `Tab` conflict,
sensitive-field suggestion, whole-anchor detached suggestion, app disable, high
caret failure, p95 above 1500ms, or annoyance above 0.35 blocks the app.

## Beta Matrix

| App | Beta stance | Render | Insert | Caveat |
| --- | --- | --- | --- | --- |
| TextEdit | reference target after gates pass | inline, mirror fallback | AX selected text, AX value fallback | Must stay clean on caret placement, one-word `Tab`, full accept, and accepted-and-kept. |
| Notes | caveated rich-text target | inline, mirror fallback | key events, AX selected text fallback | Rich-text insertion must be verified; do not graduate on AX success alone. |
| Chrome textareas | caveated local-textarea target | mirror | AX value replacement, key fallback | Local textarea proof only; browser-wide fields still need separate proof. |
| Obsidian / CodeMirror | caveated only with detached suggestions suppressed | mirror | AX then key events, key fallback | Never show suggestions from a whole-editor anchor when caret bounds are missing. |
| Electron writing app | experimental beta slot | app-specific | app-specific | Pick one real writing app, then require the same support gates before trusting it. |
| Codex | experimental dogfood target | synthetic inline caret, no detached fallback | key events, AX fallback | Useful for local dogfood traces, not a beta support claim. |
| Mail | blocked, diagnostics-only | disabled | disabled | Include only for field detection and privacy proof until a safe compose adapter exists. |
| Atlas | blocked, unsupported | disabled | disabled | Keep unsupported until focused AX element reliability is proven. |

## Commands

Run manual proof:

```bash
./script/manual_smoke_status.sh --require-all
```

Run app trace gates:

```bash
AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP="com.apple.TextEdit" \
AUTOCOMPLETE_LAB_TRACE_REQUIRE_SUPPORT_STATE="caveated" \
  ./script/check_trace_eval.sh
```

Use `supported` only when the app has enough samples for the stricter gate.
Use `caveated` for guarded beta use. Use `experimental` for dogfood only. Use
`blocked` when trust failed or the app is diagnostics-only.
