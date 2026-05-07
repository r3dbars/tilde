# Compatibility Matrix

Current beta-readiness stance for the lab build.

| App | Status | Render | Insert | Proof |
| --- | --- | --- | --- | --- |
| TextEdit | supported only after support gates pass | inline, mirror fallback | AX selected text, value fallback | needs 20 shown, 3 kept, 98% insert success, p95 <= 750ms, zero caret failures |
| Notes | caveated until rich-text insertion stays verified | inline, mirror fallback | key events, AX selected text fallback | needs verified key-event insertion and accepted-and-kept proof |
| Obsidian | caveated only when detached suggestions are suppressed | mirror | AX then key events, key fallback | detached CodeMirror suggestions must be suppressed, never shown from a whole-editor anchor |
| Chrome | caveated for local text fields | mirror | AX value replacement, key fallback | local textarea proof only until broader browser fields pass support gates |
| Codex | experimental dogfood target | synthetic inline caret, no detached fallback | key events, AX fallback | needs enough dogfood traces before caveated/supported |
| Mail | blocked, diagnostics only | disabled | disabled | keep blocked until a safe compose adapter exists |
| Atlas | blocked, unsupported | disabled | disabled | keep blocked until focused AX element reliability is proven |

Run:

```bash
./script/manual_smoke_status.sh --require-all
```

Run trace gates with:

```bash
AUTOCOMPLETE_LAB_TRACE_REQUIRE_APP="com.apple.TextEdit" \
AUTOCOMPLETE_LAB_TRACE_REQUIRE_SUPPORT_STATE="caveated" \
  ./script/check_trace_eval.sh
```

The support evaluator treats wrong insertion, duplicate insertion, focus steal,
major Tab conflict, sensitive-field display, whole-anchor detached display, app
disable, high caret failure, high p95 latency, or high annoyance as blocked.
